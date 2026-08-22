import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/data/folder_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FolderRepository folderRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folderRepo = FolderRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('默认预置 在玩、已玩过、待玩 文件夹', () async {
    final folders = await folderRepo.getAll();
    expect(folders.map((f) => f.name), containsAll(['在玩', '已玩过', '待玩']));
  });

  test('自定义新建文件夹与删除联动清除游戏 folderId', () async {
    final folderId = await folderRepo.create('全通神作', includeInTotalTime: true);
    final all = await folderRepo.getAll();
    expect(all.any((f) => f.id == folderId && f.name == '全通神作' && f.includeInTotalTime), isTrue);

    // 插入关联游戏
    await db.into(db.games).insert(
      GamesCompanion.insert(
        title: '测试游戏',
        exePath: 'c:\\games\\test.exe',
        dirPath: 'c:\\games',
      ),
    );
    final game = await (db.select(db.games)..limit(1)).getSingle();
    await (db.update(db.games)..where((g) => g.id.equals(game.id))).write(
      GamesCompanion(folderId: Value(folderId)),
    );

    // 删除文件夹
    await folderRepo.delete(folderId);
    final updatedGame = await (db.select(db.games)..where((g) => g.id.equals(game.id))).getSingle();
    expect(updatedGame.folderId, isNull);
  });
}
