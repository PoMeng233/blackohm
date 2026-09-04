import 'dart:io';

import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/data/game_repository.dart';
import 'package:blackohm/features/scanner/directory_scanner.dart';
import 'package:blackohm/features/scanner/ingestion_service.dart';
import 'package:blackohm/features/scanner/pe_info.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scanForGameExes', () {
    late Directory root;

    setUp(() async {
      root = await _tempDir('blackohm_scanner_test_');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('递归扫描子目录中的游戏 exe，展示全部 exe 不做名字过滤', () async {
      await _write(root, 'launcher.exe');
      await _write(root, 'unins000.exe');
      await _write(root, 'config.exe');
      await _write(root, 'vcredist_x64.exe');
      await _write(root, 'data/readme.txt');
      await _write(root, 'game_bin/main_game.exe');

      final candidates = scanForGameExes(root.path);
      final names = candidates.map((c) => _basename(c.path)).toSet();

      // 选择权交给用户：安装器/配置工具也作为候选展示，不做黑名单排除。
      expect(
        names,
        containsAll(<String>{
          'launcher.exe',
          'main_game.exe',
          'unins000.exe',
          'config.exe',
          'vcredist_x64.exe',
        }),
      );
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
        resolveCandidateGroup(
          totalCandidates: 0,
          availableCandidates: 0,
          duplicateCandidates: 0,
        ),
        CandidateResolution.noCandidate,
      );
      expect(
        resolveCandidateGroup(
          totalCandidates: 1,
          availableCandidates: 1,
          duplicateCandidates: 0,
        ),
        CandidateResolution.autoAdd,
      );
      expect(
        resolveCandidateGroup(
          totalCandidates: 2,
          availableCandidates: 2,
          duplicateCandidates: 0,
        ),
        CandidateResolution.chooseMainExe,
      );
      expect(
        resolveCandidateGroup(
          totalCandidates: 1,
          availableCandidates: 0,
          duplicateCandidates: 1,
        ),
        CandidateResolution.duplicateOnly,
      );
      expect(
        resolveCandidateGroup(
          totalCandidates: 2,
          availableCandidates: 1,
          duplicateCandidates: 1,
        ),
        CandidateResolution.chooseMainExe,
      );
    });

    test('引擎样板名不参与筛选，所有 exe 都进入主程序选择窗口', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = GameRepository(db);
      final service = IngestionService(repo);
      final root = await _tempDir('blackohm_all_exes_test_');
      try {
        await _write(root, 'ExHIBIT.exe');
        await _write(root, 'acmp.exe');
        await _write(root, '中文汉化补丁.exe');

        final report = await service.ingestDroppedPaths([root.path]);

        expect(report.added, isEmpty);
        expect(report.pendingDecisions, hasLength(1));
        final names = report.pendingDecisions.single
            .map((candidate) => _basename(candidate.path))
            .toSet();
        expect(
          names,
          equals(<String>{'ExHIBIT.exe', 'acmp.exe', '中文汉化补丁.exe'}),
        );
        expect(await repo.watchAll().first, isEmpty);
      } finally {
        await db.close();
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('已入库主程序仍与设置和补丁 exe 一起进入选择窗口', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = GameRepository(db);
      final service = IngestionService(repo);
      final root = await _tempDir('blackohm_existing_exe_test_');
      try {
        final mainExe = await _write(root, 'Shamrock.exe');
        await _write(root, 'エンジン設定.exe');
        await _write(root, 'inst.exe');
        final initial = await service.ingestDroppedPaths([mainExe.path]);
        expect(initial.added, hasLength(1));

        final report = await service.ingestDroppedPaths([root.path]);

        expect(report.added, isEmpty);
        expect(report.pendingDecisions, hasLength(1));
        final candidates = report.pendingDecisions.single;
        expect(
          candidates.map((candidate) => _basename(candidate.path)).toSet(),
          equals(<String>{'Shamrock.exe', 'エンジン設定.exe', 'inst.exe'}),
        );
        final existingCandidate = candidates.singleWhere(
          (candidate) => _basename(candidate.path) == 'Shamrock.exe',
        );
        expect(existingCandidate.alreadyAdded, isTrue);
        expect(
          candidates
              .where((candidate) => _basename(candidate.path) != 'Shamrock.exe')
              .every((candidate) => !candidate.alreadyAdded),
          isTrue,
        );

        await service.addChosen(existingCandidate, report);
        expect(report.duplicatePaths, contains(existingCandidate.path));
        expect(await repo.watchAll().first, hasLength(1));
      } finally {
        await db.close();
        if (await root.exists()) await root.delete(recursive: true);
      }
    });
  });

  test('目录名为游戏标题时默认用目录名而非 acmp.exe 这类 exe 名', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = GameRepository(db);
    final service = IngestionService(repo);
    final root = await _tempDir('blackohm_title_test_');
    final gameDir = Directory(
      '${root.path}${Platform.pathSeparator}鍵を隠したカゴのトリ',
    );
    await gameDir.create();
    try {
      final exe = File('${gameDir.path}${Platform.pathSeparator}acmp.exe');
      await exe.writeAsBytes([0x4D, 0x5A]);
      final report = await service.ingestDroppedPaths([exe.path]);
      expect(report.added, ['鍵を隠したカゴのトリ']);
      final games = await repo.watchAll().first;
      expect(games.single.title, '鍵を隠したカゴのトリ');
    } finally {
      await db.close();
      await root.delete(recursive: true);
    }
  });

  test('ExHIBIT.exe 作为启动程序时标题仍默认用目录名', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = GameRepository(db);
    final service = IngestionService(repo);
    final root = await _tempDir('blackohm_exhibit_test_');
    final gameDir = Directory(
      '${root.path}${Platform.pathSeparator}鍵を隠したカゴのトリ',
    );
    await gameDir.create();
    try {
      final exe = File('${gameDir.path}${Platform.pathSeparator}ExHIBIT.exe');
      await exe.writeAsBytes([0x4D, 0x5A]);
      final report = await service.ingestDroppedPaths([exe.path]);
      expect(report.added, ['鍵を隠したカゴのトリ']);
      final games = await repo.watchAll().first;
      expect(games.single.title, '鍵を隠したカゴのトリ');
    } finally {
      await db.close();
      await root.delete(recursive: true);
    }
  });

  test('明显是引擎名字的标题会被识别为样板，回退到文件夹名', () {
    expect(isBoilerplateTitle('BGI - Main window'), isTrue);
    expect(isBoilerplateTitle('Ethornell'), isTrue);
    expect(isBoilerplateTitle('TVP(KIRIKIRI) 2 core'), isTrue);
    expect(isBoilerplateTitle('RPG Maker'), isTrue);
    expect(isBoilerplateTitle('愛娘という名の玩具'), isFalse);
    expect(isBoilerplateTitle('宝石心'), isFalse);
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
    final tempDir = await _tempDir('blackohm_ingest_folder_test_');
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

/// 创建临时目录并展开为最终路径。
///
/// 入库登记走 `resolveSymbolicLinks`（会展开 8.3 短路径段），而扫描对比只做
/// 字符串标准化；CI 的 TEMP 常是短路径形式（RUNNER~1），必须统一展开，
/// 否则 `alreadyAdded` 的路径匹配两端不一致。
Future<Directory> _tempDir(String prefix) async {
  final dir = await Directory.systemTemp.createTemp(prefix);
  return Directory(await dir.resolveSymbolicLinks());
}

Future<File> _write(Directory root, String relative, {int bytes = 1}) async {
  final separator = Platform.pathSeparator;
  final parts = relative.split('/');
  final file = File('${root.path}$separator${parts.join(separator)}');
  await file.parent.create(recursive: true);
  return file.writeAsBytes(List<int>.filled(bytes, 0));
}

String _basename(String path) => path.split(Platform.pathSeparator).last;
