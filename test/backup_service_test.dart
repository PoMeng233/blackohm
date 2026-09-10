import 'dart:io';

import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/features/data/backup_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late String pathA;
  late String pathB;
  late String backupPath;
  late AppDatabase dbA;
  late AppDatabase dbB;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('blackohm_backup_test_');
    pathA = '${root.path}${Platform.pathSeparator}a.db';
    pathB = '${root.path}${Platform.pathSeparator}b.db';
    backupPath = '${root.path}${Platform.pathSeparator}backup.db';
    dbA = AppDatabase.forTesting(NativeDatabase(File(pathA)));
    dbB = AppDatabase.forTesting(NativeDatabase(File(pathB)));
  });

  tearDown(() async {
    await dbA.close();
    await dbB.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('导出后可校验，且加载到空库时完整还原游戏与会话', () async {
    final folder = await (dbA.select(
      dbA.gameFolders,
    )..where((f) => f.name.equals('在玩'))).getSingle();
    final gameId = await _insertGame(
      dbA,
      title: '宝石心学园',
      exePath: r'g:\galgame\jewelry\jeweha.exe',
      totalPlaySeconds: 417,
      folderId: folder.id,
    );
    await _insertSession(dbA, gameId, durationSeconds: 257);

    final serviceA = BackupService(dbA, databaseFile: () async => pathA);
    await serviceA.exportTo(backupPath);

    final serviceB = BackupService(dbB, databaseFile: () async => pathB);
    expect(await serviceB.validateBackup(backupPath), isTrue);

    final result = await serviceB.loadFrom(
      backupPath,
      mode: BackupLoadMode.merge,
    );

    expect(result.importedGames, 1);
    expect(result.importedSessions, 1);

    final games = await dbB.select(dbB.games).get();
    expect(games, hasLength(1));
    expect(games.single.title, '宝石心学园');
    expect(games.single.exePath, r'g:\galgame\jewelry\jeweha.exe');
    expect(games.single.totalPlaySeconds, 417);
    // 文件夹按名称对齐到当前库的同名文件夹。
    expect(games.single.folderId, isNotNull);

    final sessions = await dbB.select(dbB.playSessions).get();
    expect(sessions, hasLength(1));
    expect(sessions.single.durationSeconds, 257);
    expect(sessions.single.gameId, games.single.id);
  });

  test('合并加载对已存在的游戏整款跳过且可重复执行', () async {
    await _insertGame(
      dbA,
      title: 'GameA',
      exePath: r'g:\games\a\a.exe',
      totalPlaySeconds: 100,
    );
    final serviceA = BackupService(dbA, databaseFile: () async => pathA);
    await serviceA.exportTo(backupPath);

    final serviceB = BackupService(dbB, databaseFile: () async => pathB);
    final first = await serviceB.loadFrom(
      backupPath,
      mode: BackupLoadMode.merge,
    );
    expect(first.importedGames, 1);

    final second = await serviceB.loadFrom(
      backupPath,
      mode: BackupLoadMode.merge,
    );
    expect(second.importedGames, 0);
    expect(second.skippedGames, 1);
    expect(await dbB.select(dbB.games).get(), hasLength(1));
  });

  test('覆盖加载会清空当前库并只保留备份内容', () async {
    await _insertGame(
      dbA,
      title: '来自备份',
      exePath: r'g:\games\backup\b.exe',
      totalPlaySeconds: 10,
    );
    final serviceA = BackupService(dbA, databaseFile: () async => pathA);
    await serviceA.exportTo(backupPath);

    // 当前库预置一款无关游戏，覆盖后应消失。
    await _insertGame(
      dbB,
      title: '本地旧游戏',
      exePath: r'g:\games\local\local.exe',
      totalPlaySeconds: 999,
    );

    final serviceB = BackupService(dbB, databaseFile: () async => pathB);
    final result = await serviceB.loadFrom(
      backupPath,
      mode: BackupLoadMode.overwrite,
    );

    expect(result.importedGames, 1);
    final games = await dbB.select(dbB.games).get();
    expect(games, hasLength(1));
    expect(games.single.title, '来自备份');
  });

  test('清空仅删除游戏与游玩记录，保留设置与文件夹', () async {
    final folder = await (dbB.select(
      dbB.gameFolders,
    )..where((f) => f.name.equals('在玩'))).getSingle();
    final gameId = await _insertGame(
      dbB,
      title: '要被清空的游戏',
      exePath: r'g:\games\x\x.exe',
    );
    await _insertSession(dbB, gameId, durationSeconds: 60);
    await dbB
        .into(dbB.appSettings)
        .insertOnConflictUpdate(
          const AppSettingsCompanion(
            key: Value('bangumiToken'),
            value: Value('token-value'),
          ),
        );

    final service = BackupService(dbB, databaseFile: () async => pathB);
    final removed = await service.clearGames();

    expect(removed, 1);
    expect(await dbB.select(dbB.games).get(), isEmpty);
    expect(await dbB.select(dbB.playSessions).get(), isEmpty);
    // 设置与文件夹分组保留。
    final settings = await dbB.select(dbB.appSettings).get();
    expect(settings.single.value, 'token-value');
    final folders = await dbB.select(dbB.gameFolders).get();
    expect(folders.any((f) => f.id == folder.id), isTrue);
  });

  test('非数据库文件校验失败', () async {
    final junk = File('${root.path}${Platform.pathSeparator}junk.db');
    await junk.writeAsString('这不是一个 sqlite 数据库');
    final service = BackupService(dbB, databaseFile: () async => pathB);
    expect(await service.validateBackup(junk.path), isFalse);
  });
}

Future<int> _insertGame(
  AppDatabase db, {
  required String title,
  required String exePath,
  int totalPlaySeconds = 0,
  int? folderId,
}) {
  return db
      .into(db.games)
      .insert(
        GamesCompanion.insert(
          title: title,
          exePath: exePath,
          dirPath: exePath.substring(0, exePath.lastIndexOf(r'\')),
          totalPlaySeconds: Value(totalPlaySeconds),
          folderId: Value(folderId),
        ),
      );
}

Future<int> _insertSession(
  AppDatabase db,
  int gameId, {
  required int durationSeconds,
}) {
  final start = DateTime(2026, 8, 24, 3, 24);
  return db
      .into(db.playSessions)
      .insert(
        PlaySessionsCompanion.insert(
          gameId: Value(gameId),
          startedAt: start,
          endedAt: Value(start.add(Duration(seconds: durationSeconds))),
          durationSeconds: Value(durationSeconds),
        ),
      );
}
