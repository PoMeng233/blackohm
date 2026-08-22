import 'dart:io';

import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/data/game_repository.dart';
import 'package:blackohm/features/scanner/directory_scanner.dart';
import 'package:blackohm/features/scanner/ingestion_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scanForGameExes', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('blackohm_scanner_test_');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('递归扫描子目录中的游戏 exe，并过滤安装器与配置工具', () async {
      await _write(root, 'launcher.exe');
      await _write(root, 'unins000.exe');
      await _write(root, 'config.exe');
      await _write(root, 'vcredist_x64.exe');
      await _write(root, 'data/readme.txt');
      await _write(root, 'game_bin/main_game.exe');

      final candidates = scanForGameExes(root.path);
      final names = candidates.map((c) => _basename(c.path)).toSet();

      expect(names, containsAll(<String>{'launcher.exe', 'main_game.exe'}));
      expect(names, isNot(contains('unins000.exe')));
      expect(names, isNot(contains('config.exe')));
      expect(names, isNot(contains('vcredist_x64.exe')));
    });

    test('遵守扫描深度限制，避免意外全盘递归', () async {
      await _write(root, 'one_level/game.exe');
      await _write(root, 'one_level/two_level/deep_game.exe');

      final candidates = scanForGameExes(root.path, maxDepth: 1);
      final names = candidates.map((c) => _basename(c.path)).toSet();

      expect(names, contains('game.exe'));
      expect(names, isNot(contains('deep_game.exe')));
    });

    test('单独拖入 exe 会保留路径、目录、体积和修改时间', () async {
      final file = await _write(root, 'visual_novel.exe', bytes: 37);
      final candidate = fileToCandidate(file.path);

      expect(candidate.path, file.path);
      expect(candidate.dirPath, root.path);
      expect(candidate.sizeBytes, 37);
      expect(candidate.modified, isA<DateTime>());
    });
  });

  group('候选分流', () {
    test('0/1/2+ 个新候选分别走空、自动入库、主程序选择', () {
      expect(
        resolveCandidateGroup(availableCandidates: 0, duplicateCandidates: 0),
        CandidateResolution.noCandidate,
      );
      expect(
        resolveCandidateGroup(availableCandidates: 1, duplicateCandidates: 0),
        CandidateResolution.autoAdd,
      );
      expect(
        resolveCandidateGroup(availableCandidates: 2, duplicateCandidates: 0),
        CandidateResolution.chooseMainExe,
      );
      expect(
        resolveCandidateGroup(availableCandidates: 0, duplicateCandidates: 1),
        CandidateResolution.duplicateOnly,
      );
    });
  });

  test('IngestReport 的分流结果列表可安全写入', () {
    final report = IngestReport();
    report.added.add('测试游戏');
    report.duplicatePaths.add(r'C:\Games\existing.exe');
    report.noExePaths.add(r'C:\Empty');

    expect(report.added, ['测试游戏']);
    expect(report.duplicatePaths, hasLength(1));
    expect(report.noExePaths, hasLength(1));
  });

  test('入库服务支持将新游戏直接归属到指定 folderId', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = GameRepository(db);
    final service = IngestionService(repo);
    final folder = await (db.select(
      db.gameFolders,
    )..where((f) => f.name.equals('在玩'))).getSingle();
    final tempDir = await Directory.systemTemp.createTemp(
      'blackohm_ingest_folder_test_',
    );
    try {
      final exe = File(
        '${tempDir.path}${Platform.pathSeparator}sample_game.exe',
      );
      await exe.writeAsBytes([0x4D, 0x5A]);
      final report = await service.ingestDroppedPaths([
        exe.path,
      ], folderId: folder.id);
      expect(report.added, hasLength(1));
      final games = await repo.watchAll().first;
      expect(games.single.folderId, folder.id);
    } finally {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });
}

Future<File> _write(Directory root, String relative, {int bytes = 1}) async {
  final separator = Platform.pathSeparator;
  final parts = relative.split('/');
  final file = File('${root.path}$separator${parts.join(separator)}');
  await file.parent.create(recursive: true);
  return file.writeAsBytes(List<int>.filled(bytes, 0));
}

String _basename(String path) => path.split(Platform.pathSeparator).last;
