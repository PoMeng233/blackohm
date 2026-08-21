/// 游戏库仓库层：Games 表全部 CRUD 与响应式查询。
library;

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';

class GameRepository {
  GameRepository(this._db);

  final AppDatabase _db;

  /// 全库列表（标题排序），驱动库页面网格/列表双视图。
  Stream<List<Game>> watchAll() {
    final q = _db.select(_db.games)
      ..orderBy([(g) => OrderingTerm(expression: g.title)]);
    return q.watch();
  }

  /// 收藏优先。
  Stream<List<Game>> watchFavoritesFirst() {
    final q = _db.select(_db.games)
      ..orderBy([
        (g) => OrderingTerm.desc(g.favorite),
        (g) => OrderingTerm(expression: g.title),
      ]);
    return q.watch();
  }

  /// 最近游玩（托盘快速启动用）。
  Stream<List<Game>> watchRecent({int limit = 5}) {
    final q = _db.select(_db.games)
      ..where((g) => g.lastPlayedAt.isNotNull())
      ..orderBy([(g) => OrderingTerm.desc(g.lastPlayedAt)])
      ..limit(limit);
    return q.watch();
  }

  Stream<Game?> watchById(int id) {
    final q = _db.select(_db.games)..where((g) => g.id.equals(id));
    return q.watchSingleOrNull();
  }

  Future<Game?> findByExePath(String normalizedExePath) {
    final q = _db.select(_db.games)
      ..where((g) => g.exePath.equals(normalizedExePath));
    return q.getSingleOrNull();
  }

  Future<int> insert(GamesCompanion entry) =>
      _db.into(_db.games).insert(entry, mode: InsertMode.insertOrIgnore);

  Future<bool> update(int id, GamesCompanion patch) => (_db.update(
    _db.games,
  )..where((g) => g.id.equals(id))).write(patch).then((rows) => rows > 0);

  Future<int> delete(int id) =>
      (_db.delete(_db.games)..where((g) => g.id.equals(id))).go();

  /// 焦点引擎命中后的轻量维护：启动时间戳 + 总时长增量（会话提交时调用）。
  Future<void> addPlayedSeconds(int gameId, int seconds) {
    final q = _db.update(_db.games)..where((g) => g.id.equals(gameId));
    return q.write(
      GamesCompanion.custom(
        totalPlaySeconds: _db.games.totalPlaySeconds + Variable(seconds),
        lastPlayedAt: Variable(DateTime.now()),
      ),
    );
  }
}
