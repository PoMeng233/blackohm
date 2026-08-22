/// 文件夹仓库层：GameFolders 表全部 CRUD 与响应式查询。
library;

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';

class FolderRepository {
  FolderRepository(this._db);

  final AppDatabase _db;

  Stream<List<GameFolder>> watchAll() {
    final q = _db.select(_db.gameFolders)
      ..orderBy([(f) => OrderingTerm(expression: f.sortOrder)]);
    return q.watch();
  }

  Future<List<GameFolder>> getAll() {
    final q = _db.select(_db.gameFolders)
      ..orderBy([(f) => OrderingTerm(expression: f.sortOrder)]);
    return q.get();
  }

  Future<int> create(String name, {bool includeInTotalTime = false}) {
    return _db.into(_db.gameFolders).insert(
      GameFoldersCompanion.insert(
        name: name.trim(),
        includeInTotalTime: Value(includeInTotalTime),
      ),
    );
  }

  Future<bool> update(int id, GameFoldersCompanion patch) => (_db.update(
    _db.gameFolders,
  )..where((f) => f.id.equals(id))).write(patch).then((rows) => rows > 0);

  Future<int> delete(int id) async {
    // 移除被删除文件夹下的所有关联
    await (_db.update(_db.games)..where((g) => g.folderId.equals(id))).write(
      const GamesCompanion(folderId: Value(null)),
    );
    return (_db.delete(_db.gameFolders)..where((f) => f.id.equals(id))).go();
  }
}
