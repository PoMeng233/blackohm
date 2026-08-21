/// 会话仓库层：PlaySessions 的创建、低频进度回写与提交。
///
/// 写入节奏（配合计时引擎）：
///  * 会话开始   → 1 次 INSERT（拿到 sessionId）
///  * 活跃期间   → 每 60s 1 次 UPDATE（内存累计值刷盘，崩溃最多丢 60s）
///  * 会话结束   → 1 次 UPDATE + Games.totalPlaySeconds 增量
library;

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';

class SessionRepository {
  SessionRepository(this._db);

  final AppDatabase _db;

  /// 开启一条新会话并返回其 id。
  Future<int> start(int gameId, DateTime startedAt) {
    return _db
        .into(_db.playSessions)
        .insert(PlaySessionsCompanion.insert(
            gameId: Value(gameId), startedAt: startedAt))
        .catchError((_) => 0);
  }

  /// 周期刷盘：只回写累计秒数，不动结束时间。
  Future<void> flushProgress(int sessionId, int durationSeconds) async {
    if (sessionId <= 0) return;
    await (_db.update(_db.playSessions)
          ..where((s) => s.id.equals(sessionId)))
        .write(PlaySessionsCompanion(durationSeconds: Value(durationSeconds)));
  }

  /// 提交会话：写入最终时长与结束时间，并增量维护游戏总时长。
  Future<void> commit(int sessionId, int gameId, int totalSeconds,
      DateTime endedAt) async {
    if (sessionId > 0) {
      await (_db.update(_db.playSessions)
            ..where((s) => s.id.equals(sessionId)))
          .write(PlaySessionsCompanion(
        durationSeconds: Value(totalSeconds),
        endedAt: Value(endedAt),
      ));
    }
    await (_db.update(_db.games)..where((g) => g.id.equals(gameId))).write(
        GamesCompanion.custom(
            totalPlaySeconds: _db.games.totalPlaySeconds + totalSeconds,
            lastPlayedAt: Value(endedAt)));
  }

  /// 删除空会话行（秒数不足 1s 的噪声会话）。
  Future<void> deleteSession(int sessionId) async {
    if (sessionId <= 0) return;
    await (_db.delete(_db.playSessions)
          ..where((s) => s.id.equals(sessionId)))
        .go();
  }

  /// 单游戏的会话历史（详情弹窗）。
  Stream<List<PlaySession>> watchForGame(int gameId) {
    final q = _db.select(_db.playSessions)
      ..where((s) => s.gameId.equals(gameId))
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
      ..limit(100);
    return q.watch();
  }

  /// 全库会话时间线（最近优先）。
  Stream<List<PlaySession>> watchRecentAll({int limit = 200}) {
    final q = _db.select(_db.playSessions)
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
      ..limit(limit);
    return q.watch();
  }
}
