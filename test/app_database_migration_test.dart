import 'package:blackohm/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v7 库已有 tile_size 列时 v8 迁移不重复加列', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE games ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'tile_size INTEGER NOT NULL DEFAULT 0)',
          );
          raw.execute('PRAGMA user_version = 7');
        },
      ),
    );
    addTearDown(db.close);

    // 首次查询触发迁移；迁移中断过的库此前会在 ADD COLUMN 处抛 duplicate。
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data['user_version'], 9);

    final columns = await db.customSelect('PRAGMA table_info(games)').get();
    expect(columns.map((row) => row.data['name']), contains('tile_size'));
  });

  test('v8 库升级到 v9 时创建 game_aliases 表', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE games ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'tile_size INTEGER NOT NULL DEFAULT 0)',
          );
          raw.execute('PRAGMA user_version = 8');
        },
      ),
    );
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data['user_version'], 9);

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    expect(tables.map((row) => row.data['name']), contains('game_aliases'));
  });

  test('v9 迁移重跑时不会因表已存在而失败', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE game_aliases ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'game_id INTEGER NOT NULL, '
            'exe_path TEXT NOT NULL UNIQUE, '
            'dir_path TEXT NOT NULL, '
            'label TEXT, '
            'created_at INTEGER NOT NULL DEFAULT 0)',
          );
          raw.execute('PRAGMA user_version = 8');
        },
      ),
    );
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data['user_version'], 9);
  });

  test('删除游戏时级联删除其别名', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final gameId = await db
        .into(db.games)
        .insert(
          GamesCompanion.insert(
            title: 'G',
            exePath: r'c:\g\g.exe',
            dirPath: r'c:\g',
          ),
        );
    await db
        .into(db.gameAliases)
        .insert(
          GameAliasesCompanion.insert(
            gameId: gameId,
            exePath: r'c:\g\patch.exe',
            dirPath: r'c:\g',
          ),
        );

    await (db.delete(db.games)..where((g) => g.id.equals(gameId))).go();
    expect(await db.select(db.gameAliases).get(), isEmpty);
  });
}
