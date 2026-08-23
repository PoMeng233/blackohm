/// 游戏库仓库层：Games 表全部 CRUD 与响应式查询。
library;

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';

class GameRepository {
  GameRepository(this._db);

  final AppDatabase _db;

  /// 全库列表（标题排序），驱动库页面网格/列表双视图。
  ///
  /// iconPng blob 不随列表下发（内存治理：100+ 游戏的图标字节
  /// 不常驻 RAM），UI 经 [loadIcon] 按需加载。
  Stream<List<Game>> watchAll() {
    final q = _db.select(_db.games)
      ..orderBy([(g) => OrderingTerm(expression: g.title)]);
    return q.watch().map(_stripIcons);
  }

  /// 收藏优先。
  Stream<List<Game>> watchFavoritesFirst() {
    final q = _db.select(_db.games)
      ..orderBy([
        (g) => OrderingTerm.desc(g.favorite),
        (g) => OrderingTerm(expression: g.title),
      ]);
    return q.watch().map(_stripIcons);
  }

  /// 最近游玩（托盘快速启动用）。
  Stream<List<Game>> watchRecent({int limit = 5}) {
    final q = _db.select(_db.games)
      ..where((g) => g.lastPlayedAt.isNotNull())
      ..orderBy([(g) => OrderingTerm.desc(g.lastPlayedAt)])
      ..limit(limit);
    return q.watch().map(_stripIcons);
  }

  /// 单个游戏图标字节（按需加载，供卡片/详情/统计页使用）。
  Future<Uint8List?> loadIcon(int id) {
    final q = _db.selectOnly(_db.games)
      ..addColumns([_db.games.iconPng])
      ..where(_db.games.id.equals(id));
    return q.map((row) => row.read(_db.games.iconPng)).getSingleOrNull();
  }

  static List<Game> _stripIcons(List<Game> rows) => [
    for (final g in rows) g.copyWith(iconPng: const Value(null)),
  ];

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

  /// 从 BlackOhm 成功启动一次（count 冗余缓存，详情页展示）。
  Future<void> incrementLaunchCount(int gameId) {
    final q = _db.update(_db.games)..where((g) => g.id.equals(gameId));
    return q.write(
      GamesCompanion.custom(launchCount: _db.games.launchCount + Variable(1)),
    );
  }

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
