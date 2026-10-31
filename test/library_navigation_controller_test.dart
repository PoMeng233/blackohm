import 'dart:async';

import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/data/folder_repository.dart';
import 'package:blackohm/data/settings_repository.dart';
import 'package:blackohm/features/library/library_navigation_controller.dart';
import 'package:blackohm/providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SettingsRepository settings;
  late FolderRepository folders;
  late List<GameFolder> seededFolders;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(db);
    folders = FolderRepository(db);
    seededFolders = await folders.getAll();
  });

  tearDown(() async {
    await db.close();
  });

  LibraryNavigationController controller({
    SettingsRepository? settingsOverride,
    FolderRepository? foldersOverride,
  }) {
    final result = LibraryNavigationController(
      settingsOverride ?? settings,
      foldersOverride ?? folders,
    );
    addTearDown(result.dispose);
    return result;
  }

  test('浏览选择使用明确的 all / uncategorized / folder 编码', () {
    expect(LibraryNavigationController.encode(null), 'all');
    expect(LibraryNavigationController.encode(-1), 'uncategorized');
    expect(LibraryNavigationController.encode(42), 'folder:42');
    expect(LibraryNavigationController.decode('all'), isNull);
    expect(LibraryNavigationController.decode('uncategorized'), -1);
    expect(LibraryNavigationController.decode('folder:42'), 42);
    for (final value in [
      '',
      '42',
      '-1',
      'folder:',
      'folder:0',
      'folder:-1',
      'folder:not-a-number',
      'unknown',
    ]) {
      expect(LibraryNavigationController.decode(value), isNull, reason: value);
    }
  });

  for (final saved in ['all', 'uncategorized', 'folder']) {
    test('启动恢复 $saved 选择，flush 后数据库保持一致', () async {
      final selection = switch (saved) {
        'all' => null,
        'uncategorized' => -1,
        _ => seededFolders.first.id,
      };
      final encoded = LibraryNavigationController.encode(selection);
      await settings.set(SettingsKeys.librarySelectedFolder, encoded);
      final navigation = controller();
      await navigation.loadFuture;

      expect(navigation.state, selection);
      await navigation.flush();
      expect(await settings.get(SettingsKeys.librarySelectedFolder), encoded);
    });
  }

  for (final saved in ['', 'invalid', 'folder:0', 'folder:999999']) {
    test('无效或已删除的保存选择 $saved 回退全部游戏并修复设置', () async {
      await settings.set(SettingsKeys.librarySelectedFolder, saved);
      final navigation = controller();
      await navigation.loadFuture;
      await navigation.flush();

      expect(navigation.state, isNull);
      expect(await settings.get(SettingsKeys.librarySelectedFolder), 'all');
    });
  }

  for (final failure in ['设置', '文件夹']) {
    test('启动$failure读取失败安全回退，仍建立监听且退出 flush 正常完成', () async {
      final fakeSettings = _ControlledSettingsRepository(
        db,
        saved: 'folder:${seededFolders.first.id}',
        readError: failure == '设置' ? StateError('settings read failed') : null,
      );
      final fakeFolders = _SnapshotFolderRepository(
        db,
        seededFolders,
        readError: failure == '文件夹' ? StateError('folders read failed') : null,
      );
      final navigation = controller(
        settingsOverride: fakeSettings,
        foldersOverride: fakeFolders,
      );

      await expectLater(navigation.loadFuture, completes);
      expect(navigation.state, isNull);
      expect(fakeFolders.watchStarted, isTrue);
      await expectLater(
        navigation.flush().timeout(const Duration(seconds: 5)),
        completes,
      );
      expect(fakeSettings.saved, 'all');

      final selected = seededFolders.last.id;
      navigation.select(selected);
      await navigation.flush();
      expect(navigation.state, selected);
      expect(fakeSettings.saved, 'folder:$selected');
    });

    test('启动$failure读取失败不覆盖加载期间用户选择，监听仍校验失效文件夹', () async {
      final readGate = Completer<void>();
      final fakeSettings = _ControlledSettingsRepository(
        db,
        saved: 'folder:${seededFolders.first.id}',
        readGate: readGate.future,
        readError: failure == '设置' ? StateError('settings read failed') : null,
      );
      final selected = seededFolders.last.id;
      final folderUpdates = StreamController<List<GameFolder>>();
      addTearDown(folderUpdates.close);
      final fakeFolders = _SnapshotFolderRepository(
        db,
        seededFolders,
        readError: failure == '文件夹' ? StateError('folders read failed') : null,
        updates: folderUpdates.stream,
      );
      final navigation = controller(
        settingsOverride: fakeSettings,
        foldersOverride: fakeFolders,
      );

      navigation.select(selected);
      readGate.complete();
      await expectLater(navigation.loadFuture, completes);
      expect(navigation.state, selected);
      expect(fakeFolders.watchStarted, isTrue);
      await navigation.flush();
      expect(fakeSettings.saved, 'folder:$selected');

      // 读取失败本身保留用户选择，随后监听发现文件夹不存在才回退。
      final reset = Completer<void>();
      final removeListener = navigation.addListener((selection) {
        if (selection == null && !reset.isCompleted) reset.complete();
      }, fireImmediately: false);
      addTearDown(removeListener);
      folderUpdates.add(
        seededFolders.where((folder) => folder.id != selected).toList(),
      );
      await reset.future.timeout(const Duration(seconds: 5));
      await navigation.flush();
      expect(navigation.state, isNull);
      expect(fakeSettings.saved, 'all');
    });
  }

  test('删除当前文件夹自动回退并持久化全部游戏', () async {
    final folderId = await folders.create('Temporary');
    await settings.set(SettingsKeys.librarySelectedFolder, 'folder:$folderId');
    final navigation = controller();
    await navigation.loadFuture;
    expect(navigation.state, folderId);
    final reset = Completer<void>();
    final removeListener = navigation.addListener((selection) {
      if (selection == null && !reset.isCompleted) reset.complete();
    }, fireImmediately: false);
    addTearDown(removeListener);

    await folders.delete(folderId);
    await reset.future.timeout(const Duration(seconds: 5));
    await navigation.flush();

    expect(navigation.state, isNull);
    expect(await settings.get(SettingsKeys.librarySelectedFolder), 'all');
  });

  test('重命名当前文件夹和删除其他文件夹不改变浏览选择', () async {
    final folderId = seededFolders.first.id;
    await settings.set(SettingsKeys.librarySelectedFolder, 'folder:$folderId');
    final navigation = controller();
    await navigation.loadFuture;
    await folders.update(
      folderId,
      const GameFoldersCompanion(name: Value('Renamed')),
    );
    await folders.delete(seededFolders.last.id);
    await folders.watchAll().first;
    await Future<void>.delayed(Duration.zero);
    await navigation.flush();

    expect(navigation.state, folderId);
    expect(
      await settings.get(SettingsKeys.librarySelectedFolder),
      'folder:$folderId',
    );
  });

  test('加载尚未完成时用户选择优先于旧设置', () async {
    final readGate = Completer<void>();
    final fakeSettings = _ControlledSettingsRepository(
      db,
      saved: 'folder:${seededFolders.first.id}',
      readGate: readGate.future,
    );
    final navigation = controller(
      settingsOverride: fakeSettings,
      foldersOverride: _SnapshotFolderRepository(db, seededFolders),
    );
    final selected = seededFolders.last.id;

    navigation.select(selected);
    expect(navigation.state, selected);
    readGate.complete();
    await navigation.loadFuture;
    await navigation.flush();

    expect(navigation.state, selected);
    expect(fakeSettings.saved, 'folder:$selected');
  });

  test('加载时切到全部游戏也不能被旧文件夹选择覆盖', () async {
    final readGate = Completer<void>();
    final fakeSettings = _ControlledSettingsRepository(
      db,
      saved: 'folder:${seededFolders.first.id}',
      readGate: readGate.future,
    );
    final navigation = controller(
      settingsOverride: fakeSettings,
      foldersOverride: _SnapshotFolderRepository(db, seededFolders),
    );

    navigation.select(null);
    readGate.complete();
    await navigation.loadFuture;
    await navigation.flush();

    expect(navigation.state, isNull);
    expect(fakeSettings.saved, 'all');
  });

  test('快速切换立即更新状态，但设置写入严格串行且最后选择胜出', () async {
    final writeGate = Completer<void>();
    final fakeSettings = _ControlledSettingsRepository(
      db,
      saved: 'all',
      firstWriteGate: writeGate.future,
    );
    final navigation = controller(
      settingsOverride: fakeSettings,
      foldersOverride: _SnapshotFolderRepository(db, seededFolders),
    );
    await navigation.loadFuture;
    final first = seededFolders.first.id;
    final last = seededFolders.last.id;

    navigation.select(first);
    navigation.select(-1);
    navigation.select(last);
    expect(navigation.state, last);
    await Future<void>.delayed(Duration.zero);
    expect(fakeSettings.startedWrites, ['folder:$first']);
    expect(fakeSettings.completedWrites, isEmpty);

    final flushed = navigation.flush();
    writeGate.complete();
    await flushed;

    expect(fakeSettings.completedWrites, [
      'folder:$first',
      'uncategorized',
      'folder:$last',
      'folder:$last',
    ]);
    expect(fakeSettings.saved, 'folder:$last');
  });

  test('单次 flush 等待期间新增的选择写入完成', () async {
    final writeGate = Completer<void>();
    final nextWriteGate = Completer<void>();
    final fakeSettings = _ControlledSettingsRepository(
      db,
      saved: 'all',
      firstWriteGate: writeGate.future,
      secondWriteGate: nextWriteGate.future,
    );
    final navigation = controller(
      settingsOverride: fakeSettings,
      foldersOverride: _SnapshotFolderRepository(db, seededFolders),
    );
    await navigation.loadFuture;

    var flushCompleted = false;
    final flushed = navigation.flush().then((_) {
      flushCompleted = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(fakeSettings.startedWrites, ['all']);

    final selected = seededFolders.last.id;
    navigation.select(selected);
    expect(navigation.state, selected);
    await Future<void>.delayed(Duration.zero);
    expect(fakeSettings.startedWrites, ['all']);
    expect(fakeSettings.completedWrites, isEmpty);

    writeGate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(fakeSettings.startedWrites, ['all', 'folder:$selected']);
    expect(fakeSettings.completedWrites, ['all']);
    expect(flushCompleted, isFalse);

    nextWriteGate.complete();
    await flushed.timeout(const Duration(seconds: 5));

    expect(flushCompleted, isTrue);
    expect(fakeSettings.completedWrites, ['all', 'folder:$selected']);
    expect(navigation.state, selected);
    expect(fakeSettings.saved, 'folder:$selected');
  });

  test('不存在的选择立即回退全部游戏', () async {
    final navigation = controller();
    await navigation.loadFuture;
    navigation.select(999999);
    expect(navigation.state, isNull);
    navigation.select(0);
    expect(navigation.state, isNull);
    navigation.select(-2);
    expect(navigation.state, isNull);
    await navigation.flush();
    expect(await settings.get(SettingsKeys.librarySelectedFolder), 'all');
  });

  ProviderContainer container() =>
      ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);

  test('重建 ProviderContainer 从同一设置仓库恢复上次浏览选择', () async {
    final first = container();
    final firstNavigation = first.read(libraryNavigationProvider.notifier);
    await firstNavigation.loadFuture;
    firstNavigation.select(seededFolders.first.id);
    await firstNavigation.flush();
    first.dispose();

    final second = container();
    addTearDown(second.dispose);
    await second.read(libraryNavigationProvider.notifier).loadFuture;

    expect(second.read(libraryNavigationProvider), seededFolders.first.id);
    expect(
      second.read(currentBrowsingFolderIdProvider),
      seededFolders.first.id,
    );
  });

  test('入库目标只在库页激活且浏览具体文件夹时提供，离页不丢失选择', () async {
    final scope = container();
    addTearDown(scope.dispose);
    final navigation = scope.read(libraryNavigationProvider.notifier);
    await navigation.loadFuture;
    expect(scope.read(libraryPageActiveProvider), isTrue);
    expect(scope.read(currentBrowsingFolderIdProvider), isNull);

    navigation.select(seededFolders.first.id);
    expect(scope.read(currentBrowsingFolderIdProvider), seededFolders.first.id);
    scope.read(libraryPageActiveProvider.notifier).state = false;
    expect(scope.read(currentBrowsingFolderIdProvider), isNull);
    expect(scope.read(libraryNavigationProvider), seededFolders.first.id);
    scope.read(libraryPageActiveProvider.notifier).state = true;
    expect(scope.read(currentBrowsingFolderIdProvider), seededFolders.first.id);

    navigation.select(-1);
    expect(scope.read(currentBrowsingFolderIdProvider), isNull);
    navigation.select(null);
    expect(scope.read(currentBrowsingFolderIdProvider), isNull);
    await navigation.flush();
  });
}

class _SnapshotFolderRepository extends FolderRepository {
  _SnapshotFolderRepository(
    super.db,
    this.folders, {
    this.readError,
    this.updates,
  });

  final List<GameFolder> folders;
  final Object? readError;
  final Stream<List<GameFolder>>? updates;
  bool watchStarted = false;

  @override
  Future<List<GameFolder>> getAll() async {
    final error = readError;
    if (error != null) throw error;
    return folders;
  }

  @override
  Stream<List<GameFolder>> watchAll() {
    watchStarted = true;
    return updates ?? Stream.value(folders);
  }
}

class _ControlledSettingsRepository extends SettingsRepository {
  _ControlledSettingsRepository(
    super.db, {
    required this.saved,
    this.readGate,
    this.readError,
    this.firstWriteGate,
    this.secondWriteGate,
  });

  String saved;
  final Future<void>? readGate;
  final Object? readError;
  final Future<void>? firstWriteGate;
  final Future<void>? secondWriteGate;
  final List<String> startedWrites = [];
  final List<String> completedWrites = [];

  @override
  Future<String> get(String key, {String defaultValue = ''}) async {
    expect(key, SettingsKeys.librarySelectedFolder);
    final initial = saved;
    await readGate;
    final error = readError;
    if (error != null) throw error;
    return initial;
  }

  @override
  Future<void> set(String key, String value) async {
    expect(key, SettingsKeys.librarySelectedFolder);
    startedWrites.add(value);
    if (startedWrites.length == 1) await firstWriteGate;
    if (startedWrites.length == 2) await secondWriteGate;
    saved = value;
    completedWrites.add(value);
  }
}
