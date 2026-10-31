/// 游戏别名仓库：路径占用检查、别名增删与卡片合并。
library;

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/path_normalizer.dart';

class AliasRepository {
  AliasRepository(this._db);

  final AppDatabase _db;

  Stream<List<GameAlias>> watchAll() {
    final q = _db.select(_db.gameAliases)
      ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]);
    return q.watch();
  }

  Stream<List<GameAlias>> watchForGame(int gameId) {
    final q = _db.select(_db.gameAliases)
      ..where((a) => a.gameId.equals(gameId))
      ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]);
    return q.watch();
  }

  /// 路径归属的游戏 id：主 exe 优先，其次别名；未跟踪返回 null。
  ///
  /// 用 selectOnly 避免把 icon_png blob 读进内存。
  Future<int?> ownerGameIdOf(String exePath) async {
    final normalized = normalizeExePath(exePath);
    final primary =
        await (_db.selectOnly(_db.games)
              ..addColumns([_db.games.id])
              ..where(_db.games.exePath.equals(normalized))
              ..limit(1))
            .getSingleOrNull();
    if (primary != null) return primary.read(_db.games.id);

    final alias =
        await (_db.selectOnly(_db.gameAliases)
              ..addColumns([_db.gameAliases.gameId])
              ..where(_db.gameAliases.exePath.equals(normalized))
              ..limit(1))
            .getSingleOrNull();
    return alias?.read(_db.gameAliases.gameId);
  }

  /// 添加别名；路径已被任意游戏 / 别名占用时返回 0。
  Future<int> addAlias({
    required int gameId,
    required String exePath,
    required String dirPath,
    String? label,
  }) async {
    final normalized = normalizeExePath(exePath);
    if (await ownerGameIdOf(normalized) != null) return 0;
    return _db
        .into(_db.gameAliases)
        .insert(
          GameAliasesCompanion.insert(
            gameId: gameId,
            exePath: normalized,
            dirPath: dirPath,
            label: Value(label),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<bool> removeAlias(int aliasId) {
    return (_db.delete(
      _db.gameAliases,
    )..where((a) => a.id.equals(aliasId))).go().then((rows) => rows > 0);
  }

  /// 把 source 合并进 target：单事务，失败整体回滚。
  ///
  /// 目标卡保留标题、图标、背景、文件夹、启动配置与 Bangumi 信息；
  /// 只并入累计时长、会话、启动次数，并把源卡主 exe 与别名改挂到目标卡。
  Future<bool> mergeInto({required int targetId, required int sourceId}) async {
    if (targetId == sourceId) return false;
    return _db.transaction(() async {
      final target = await (_db.select(
        _db.games,
      )..where((g) => g.id.equals(targetId))).getSingleOrNull();
      final source = await (_db.select(
        _db.games,
      )..where((g) => g.id.equals(sourceId))).getSingleOrNull();
      if (target == null || source == null) return false;

      // 会话必须先迁移：源卡删除会级联清掉未迁移的会话。
      await (_db.update(_db.playSessions)
            ..where((s) => s.gameId.equals(sourceId)))
          .write(PlaySessionsCompanion(gameId: Value(targetId)));

      await (_db.update(_db.gameAliases)
            ..where((a) => a.gameId.equals(sourceId)))
          .write(GameAliasesCompanion(gameId: Value(targetId)));

      await _db
          .into(_db.gameAliases)
          .insert(
            GameAliasesCompanion.insert(
              gameId: targetId,
              exePath: source.exePath,
              dirPath: source.dirPath,
              label: Value(source.title),
            ),
            mode: InsertMode.insertOrIgnore,
          );

      final latest = _latest(target.lastPlayedAt, source.lastPlayedAt);
      await (_db.update(_db.games)..where((g) => g.id.equals(targetId))).write(
        GamesCompanion.custom(
          totalPlaySeconds:
              _db.games.totalPlaySeconds + Variable(source.totalPlaySeconds),
          launchCount: _db.games.launchCount + Variable(source.launchCount),
          lastPlayedAt: latest == null ? null : Variable<DateTime>(latest),
        ),
      );

      await (_db.delete(_db.games)..where((g) => g.id.equals(sourceId))).go();
      return true;
    });
  }

  static DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
