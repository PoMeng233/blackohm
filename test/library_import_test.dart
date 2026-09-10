import 'dart:io';

import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/data/game_repository.dart';
import 'package:blackohm/features/scanner/ingestion_service.dart';
import 'package:blackohm/features/scanner/library_scanner.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GameRepository repo;
  late IngestionService service;
  late Directory root;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = GameRepository(db);
    service = IngestionService(repo);
    root = await Directory.systemTemp.createTemp('blackohm_import_test_');
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('批量导入库中的每款游戏并采用目录名作为标题', () async {
    await _write(root, '宝石心学园/宝石心学园.exe');
    await _write(root, 'Shamrock/Shamrock.exe');
    await _write(root, 'DOLCE/DOLCE.exe');

    final layout = detectLibraryLayout(root.path);
    expect(layout.isLibrary, isTrue);

    final report = await service.importLibrary(layout);

    expect(report.added, hasLength(3));
    final games = await repo.watchAll().first;
    expect(games, hasLength(3));
    expect(
      games.map((g) => g.title).toSet(),
      containsAll(<String>{'宝石心学园', 'Shamrock', 'DOLCE'}),
    );
  });

  test('已在库中的游戏整款跳过，不重复建卡', () async {
    await _write(root, 'GameA/GameA.exe');
    await _write(root, 'GameB/GameB.exe');
    await _write(root, 'GameC/GameC.exe');

    // 先单独入库 GameB，模拟库中已存在。
    await service.ingestDroppedPaths([
      '${root.path}${Platform.pathSeparator}GameB',
    ]);

    final layout = detectLibraryLayout(root.path);
    final report = await service.importLibrary(layout);

    expect(report.skippedExisting, contains('GameB'));
    expect(report.added, hasLength(2));
    expect(await repo.watchAll().first, hasLength(3));
  });

  test('多候选时自动采用评分最高的主程序并记录待复核', () async {
    await _write(root, 'GameA/GameA.exe', bytes: 1024);
    await _write(root, 'GameA/engine_setup.exe', bytes: 8 * 1024 * 1024);
    await _write(root, 'GameB/GameB.exe');

    final layout = detectLibraryLayout(root.path);
    final report = await service.importLibrary(layout);

    expect(report.added, hasLength(2));
    expect(report.autoChosenTitles, contains('GameA'));

    final games = await repo.watchAll().first;
    final gameA = games.firstWhere((g) => g.title == 'GameA');
    expect(gameA.exePath, endsWith('gamea.exe'));
  });

  test('批量导入的游戏归入当前浏览的文件夹', () async {
    await _write(root, 'GameA/GameA.exe');
    await _write(root, 'GameB/GameB.exe');

    final folder = await (db.select(
      db.gameFolders,
    )..where((f) => f.name.equals('在玩'))).getSingle();

    final layout = detectLibraryLayout(root.path);
    await service.importLibrary(layout, folderId: folder.id);

    final games = await repo.watchAll().first;
    expect(games, hasLength(2));
    expect(games.every((g) => g.folderId == folder.id), isTrue);
  });

  test('进度回调按处理数量递增至总数', () async {
    await _write(root, 'GameA/GameA.exe');
    await _write(root, 'GameB/GameB.exe');
    await _write(root, 'GameC/GameC.exe');

    final layout = detectLibraryLayout(root.path);
    final progress = <int>[];
    await service.importLibrary(
      layout,
      onProgress: (done, total) {
        expect(total, 3);
        progress.add(done);
      },
    );

    expect(progress, <int>[1, 2, 3]);
  });

  test('分块处理时超过一块的数量也能全部导入', () async {
    for (var i = 0; i < 10; i++) {
      await _write(root, 'Game$i/Game$i.exe');
    }

    final layout = detectLibraryLayout(root.path);
    final report = await service.importLibrary(layout);

    expect(report.added, hasLength(10));
    expect(await repo.watchAll().first, hasLength(10));
  });
}

Future<File> _write(Directory root, String relative, {int bytes = 1}) async {
  final separator = Platform.pathSeparator;
  final file = File(
    '${root.path}$separator${relative.split('/').join(separator)}',
  );
  await file.parent.create(recursive: true);
  return file.writeAsBytes(List<int>.filled(bytes, 0));
}
