import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/data/session_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = SessionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('启动恢复开放 Session 并且重复执行不会重复补入卡片', () async {
    final gameId = await db
        .into(db.games)
        .insert(
          GamesCompanion.insert(
            title: '宝石心学园',
            exePath: r'g:\games\jewelry.exe',
            dirPath: r'g:\games',
            totalPlaySeconds: const Value(327),
          ),
        );
    final startedAt = DateTime(2026, 8, 24, 3, 24, 19);
    final progressId = await db
        .into(db.playSessions)
        .insert(
          PlaySessionsCompanion.insert(
            gameId: Value(gameId),
            startedAt: startedAt,
            durationSeconds: const Value(39),
          ),
        );
    final emptyId = await db
        .into(db.playSessions)
        .insert(
          PlaySessionsCompanion.insert(
            gameId: Value(gameId),
            startedAt: startedAt.add(const Duration(hours: 1)),
          ),
        );

    await repository.recoverOpenSessions();
    await repository.recoverOpenSessions();

    final game = await (db.select(
      db.games,
    )..where((g) => g.id.equals(gameId))).getSingle();
    final progress = await (db.select(
      db.playSessions,
    )..where((s) => s.id.equals(progressId))).getSingle();
    final empty = await (db.select(
      db.playSessions,
    )..where((s) => s.id.equals(emptyId))).getSingleOrNull();

    expect(game.totalPlaySeconds, 366);
    expect(progress.endedAt, startedAt.add(const Duration(seconds: 39)));
    expect(empty, isNull);
  });
}
