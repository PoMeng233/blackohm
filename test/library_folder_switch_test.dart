import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/data/folder_repository.dart';
import 'package:blackohm/data/settings_repository.dart';
import 'package:blackohm/features/library/library_navigation_controller.dart';
import 'package:blackohm/features/tracking/tracking_engine.dart';
import 'package:blackohm/providers.dart';
import 'package:blackohm/ui/pages/library_page.dart';
import 'package:blackohm/ui/theme.dart';
import 'package:blackohm/ui/widgets/folder_card.dart';
import 'package:blackohm/ui/widgets/game_card.dart';
import 'package:blackohm/ui/widgets/metro_tile_grid.dart';
import 'package:blackohm/ui/widgets/metro_tile_layout.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Game> games;
  late List<GameFolder> folders;
  late _MemorySettingsRepository settings;
  late _SnapshotFolderRepository folderRepository;

  setUp(() async {
    // 只在 setup 阶段使用内存数据库构造快照；测试 UI 不再订阅 Drift watch，
    // 避免 widget teardown 与数据库关闭发生异步竞态。
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final seeded = await (db.select(
      db.gameFolders,
    )..where((f) => f.name.equals('在玩'))).getSingle();
    final folderId = seeded.id;
    await db
        .into(db.games)
        .insert(
          GamesCompanion.insert(
            title: 'Active Game',
            exePath: r'c:\games\active\game.exe',
            dirPath: r'c:\games\active',
            folderId: Value(folderId),
            totalPlaySeconds: const Value(3600),
          ),
        );
    await db
        .into(db.games)
        .insert(
          GamesCompanion.insert(
            title: 'Idle Game',
            exePath: r'c:\games\idle\game.exe',
            dirPath: r'c:\games\idle',
            totalPlaySeconds: const Value(60),
          ),
        );
    games = await db.select(db.games).get();
    folders = await db.select(db.gameFolders).get();
    settings = _MemorySettingsRepository(db);
    folderRepository = _SnapshotFolderRepository(db, folders);
    await db.close();
  });

  Future<ProviderContainer> pumpLibrary(
    WidgetTester tester, {
    ValueNotifier<bool>? libraryVisible,
    Size viewportSize = const Size(1080, 720),
  }) async {
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepoProvider.overrideWithValue(settings),
          folderRepoProvider.overrideWithValue(folderRepository),
          gameListProvider.overrideWith((ref) => Stream.value(games)),
          folderListProvider.overrideWith((ref) => Stream.value(folders)),
          gameIconProvider.overrideWith((ref, id) => Future.value(null)),
          trackingStateProvider.overrideWith(
            (ref) => Stream.value(
              const TrackingPublicState(
                gameId: 1,
                elapsedMs: 65000,
                phase: TrackingPhase.live,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: libraryVisible == null
                ? const SizedBox.expand(child: LibraryPage())
                : ValueListenableBuilder<bool>(
                    valueListenable: libraryVisible,
                    builder: (_, visible, _) => visible
                        ? const SizedBox.expand(child: LibraryPage())
                        : const Center(child: Text('Other page')),
                  ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(libraryNavigationProvider.notifier).loadFuture;
    await tester.pump();
    return container;
  }

  for (final saved in ['all', 'uncategorized', 'folder']) {
    testWidgets('库页恢复 $saved 选择并按对应文件夹过滤游戏', (tester) async {
      final folderId = folders.firstWhere((folder) => folder.name == '在玩').id;
      final selection = switch (saved) {
        'all' => null,
        'uncategorized' => -1,
        _ => folderId,
      };
      await settings.set(
        SettingsKeys.librarySelectedFolder,
        LibraryNavigationController.encode(selection),
      );
      final container = await pumpLibrary(tester);

      expect(container.read(libraryNavigationProvider), selection);
      expect(
        find.text('Active Game'),
        selection == -1 ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('Idle Game'),
        selection == folderId ? findsNothing : findsOneWidget,
      );
      expect(
        find.byType(FolderCard),
        selection == null ? findsWidgets : findsNothing,
      );
      expect(tester.takeException(), isNull);
      await container.read(libraryNavigationProvider.notifier).flush();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('离开库页后重新挂载仍显示上次选中的文件夹', (tester) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    final container = await pumpLibrary(tester, libraryVisible: visible);
    final folderId = folders.firstWhere((folder) => folder.name == '在玩').id;

    await tester.tap(find.text('在玩').first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Active Game'), findsOneWidget);
    expect(find.text('Idle Game'), findsNothing);

    // AppShell 负责标记当前页面；这里模拟它的页面切换并卸载库页。
    container.read(libraryPageActiveProvider.notifier).state = false;
    visible.value = false;
    await tester.pump();
    expect(find.byType(LibraryPage), findsNothing);
    expect(container.read(currentBrowsingFolderIdProvider), isNull);
    expect(container.read(libraryNavigationProvider), folderId);

    container.read(libraryPageActiveProvider.notifier).state = true;
    visible.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Active Game'), findsOneWidget);
    expect(find.text('Idle Game'), findsNothing);
    expect(container.read(currentBrowsingFolderIdProvider), folderId);
    expect(tester.takeException(), isNull);

    await container.read(libraryNavigationProvider.notifier).flush();
    expect(
      await settings.get(SettingsKeys.librarySelectedFolder),
      'folder:$folderId',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final pageWidth in [728.0, 1008.0, 1368.0]) {
    testWidgets('库页宽度 $pageWidth 下卡片高度一致且切换无布局异常', (tester) async {
      // 窗口宽度扣除 AppShell 的 72px 导航栏，包含最小 800px 窗口。
      final container = await pumpLibrary(
        tester,
        viewportSize: Size(pageWidth, 720),
      );
      expect(find.byType(MetroTileGrid), findsOneWidget);
      final metrics = MetroGridMetrics.forWidth(pageWidth - 40);
      expect(metrics.columns, inInclusiveRange(4, 10));
      expect(find.byType(FolderCard), findsWidgets);
      expect(find.byType(GameCard), findsNWidgets(games.length));
      final folderSize = tester.getSize(find.byType(FolderCard).first);
      expect(
        folderSize.width,
        closeTo(metrics.widthFor(MetroTileSize.wide), 0.001),
      );
      expect(folderSize.height, closeTo(metrics.tileExtent, 0.001));
      for (final element in find.byType(GameCard).evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.width, closeTo(metrics.tileExtent, 0.001));
        expect(size.height, closeTo(metrics.tileExtent, 0.001));
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('在玩').first);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(FolderCard), findsNothing);
      expect(find.byType(GameCard), findsOneWidget);
      expect(
        tester.getSize(find.byType(GameCard)).height,
        closeTo(metrics.tileExtent, 0.001),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Active Game'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await container.read(libraryNavigationProvider.notifier).flush();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('活跃计时中切换文件夹不抛异常（网格视图）', (tester) async {
    await pumpLibrary(tester);
    // 全部游戏视图显示所有游戏，文件夹只是额外的聚合入口。
    expect(find.text('Idle Game'), findsOneWidget);
    expect(find.text('Active Game'), findsOneWidget);

    await tester.tap(find.text('在玩').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Active Game'), findsOneWidget);
    expect(find.text('Idle Game'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('全部游戏'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('未分类'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // 回到含活跃卡片的视图，让呼吸光效定时器跑几帧。
    await tester.tap(find.text('在玩').first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('累计时长排序时切换文件夹不抛异常（列表视图）', (tester) async {
    await pumpLibrary(tester);
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('最近游玩'));
    await tester.pump();
    await tester.tap(find.text('累计时长').last);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('在玩').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Active Game'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('活跃计时中切换文件夹不抛异常（列表视图）', (tester) async {
    await pumpLibrary(tester);
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('在玩').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Active Game'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('全部游戏'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _SnapshotFolderRepository extends FolderRepository {
  _SnapshotFolderRepository(super.db, this.folders);

  final List<GameFolder> folders;

  @override
  Future<List<GameFolder>> getAll() async => folders;

  @override
  Stream<List<GameFolder>> watchAll() => Stream.value(folders);
}

class _MemorySettingsRepository extends SettingsRepository {
  _MemorySettingsRepository(super.db);

  final Map<String, String> values = {};

  @override
  Future<String> get(String key, {String defaultValue = ''}) async =>
      values[key] ?? defaultValue;

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }
}
