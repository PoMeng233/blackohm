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
    expect(version.data['user_version'], 8);

    final columns = await db.customSelect('PRAGMA table_info(games)').get();
    expect(columns.map((row) => row.data['name']), contains('tile_size'));
  });
}
