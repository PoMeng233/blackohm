import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/data/alias_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AliasRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AliasRepository(db);
  });

  tearDown(() => db.close());

  test('主路径与别名路径都能找到所属游戏', () async {
    final gameId = await _insertGame(
      db,
      title: '宝石心',
      exePath: r'g:\galgame\jewelry\jeweha.exe',
    );
    await repo.addAlias(
      gameId: gameId,
      exePath: r'g:\galgame\jewelry\patch\patch.exe',
      dirPath: r'g:\galgame\jewelry\patch',
    );

    expect(await repo.ownerGameIdOf(r'G:\Galgame\Jewelry\Jeweha.exe'), gameId);
    expect(
      await repo.ownerGameIdOf(r'g:\galgame\jewelry\patch\patch.exe'),
      gameId,
    );
    expect(await repo.ownerGameIdOf(r'g:\other\x.exe'), isNull);
  });

  test('已被占用的路径不能再添加别名', () async {
    final a = await _insertGame(db, title: 'A', exePath: r'g:\a\a.exe');
    final b = await _insertGame(db, title: 'B', exePath: r'g:\b\b.exe');

    expect(
      await repo.addAlias(gameId: a, exePath: r'g:\b\b.exe', dirPath: r'g:\b'),
      0,
    );
    final aliasId = await repo.addAlias(
      gameId: a,
      exePath: r'g:\a\patch.exe',
      dirPath: r'g:\a',
    );
    expect(aliasId, greaterThan(0));
    expect(
      await repo.addAlias(
        gameId: b,
        exePath: r'g:\a\patch.exe',
        dirPath: r'g:\a',
      ),
      0,
    );
  });

  test('合并卡片：迁移会话与别名，累计时长和启动次数，删除源卡', () async {
    final targetId = await _insertGame(
      db,
      title: '目标',
      exePath: r'g:\t\t.exe',
      totalPlaySeconds: 100,
      launchCount: 2,
      lastPlayedAt: DateTime(2026, 1, 1),
    );
    final sourceId = await _insertGame(
      db,
      title: '源',
      exePath: r'g:\s\s.exe',
      totalPlaySeconds: 50,
      launchCount: 3,
      lastPlayedAt: DateTime(2026, 2, 1),
    );
    await db
        .into(db.gameAliases)
        .insert(
          GameAliasesCompanion.insert(
            gameId: sourceId,
            exePath: r'g:\s\patch.exe',
            dirPath: r'g:\s',
            label: const Value('补丁'),
          ),
        );
    await db
        .into(db.playSessions)
        .insert(
          PlaySessionsCompanion.insert(
            gameId: Value(sourceId),
            startedAt: DateTime(2026, 1, 2),
            endedAt: Value(DateTime(2026, 1, 2, 1)),
            durationSeconds: const Value(50),
          ),
        );

    expect(
      await repo.mergeInto(targetId: targetId, sourceId: sourceId),
      isTrue,
    );

    final target = await (db.select(
      db.games,
    )..where((g) => g.id.equals(targetId))).getSingle();
    expect(target.totalPlaySeconds, 150);
    expect(target.launchCount, 5);
    expect(target.lastPlayedAt, DateTime(2026, 2, 1));

    expect(
      await (db.select(
        db.games,
      )..where((g) => g.id.equals(sourceId))).getSingleOrNull(),
      isNull,
    );

    final aliases = await db.select(db.gameAliases).get();
    expect(aliases.map((a) => a.exePath).toSet(), {
      r'g:\s\patch.exe',
      r'g:\s\s.exe',
    });
    expect(aliases.every((a) => a.gameId == targetId), isTrue);
    expect(aliases.firstWhere((a) => a.exePath == r'g:\s\s.exe').label, '源');

    final session = await db.select(db.playSessions).getSingle();
    expect(session.gameId, targetId);
  });

  test('不能把卡片合并到自己', () async {
    final id = await _insertGame(db, title: 'A', exePath: r'g:\a\a.exe');
    expect(await repo.mergeInto(targetId: id, sourceId: id), isFalse);
  });
}

Future<int> _insertGame(
  AppDatabase db, {
  required String title,
  required String exePath,
  int totalPlaySeconds = 0,
  int launchCount = 0,
  DateTime? lastPlayedAt,
}) {
  return db
      .into(db.games)
      .insert(
        GamesCompanion.insert(
          title: title,
          exePath: exePath,
          dirPath: exePath.substring(0, exePath.lastIndexOf(r'\')),
          totalPlaySeconds: Value(totalPlaySeconds),
          launchCount: Value(launchCount),
          lastPlayedAt: Value(lastPlayedAt),
        ),
      );
}
