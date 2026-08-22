/// Drift 数据库定义（SQLite 3，经 sqlite3_flutter_libs 静态打包）。
///
/// 三张表：
///  * Games        — 游戏库（exe 绝对路径唯一键、图标 PNG、LE 配置、累计时长缓存）
///  * PlaySessions — 连续游玩会话（防抖合并后的完整段）
///  * Settings     — 轻量 KV（LEProc 路径、启动至托盘等）
///
/// 数据库连接运行在 drift 的后台 isolate（createInBackground），
/// 读写不占 UI 线程；配合计时引擎的"内存累加 + 60s 批量刷盘"策略，
/// 常态下对 SQLite 的写入压力约为每分钟 1 次。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// 游戏条目。`exePath` 存放标准化（小写/长路径/统一分隔符）后的镜像路径，
/// 与运行期 QueryFullProcessImageNameW 捕获值同构，直接哈希命中。
class Games extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 展示标题（默认取 PE FileDescription / ProductName / 目录名）。
  TextColumn get title => text().withLength(min: 1, max: 512)();

  /// 标准化 exe 绝对路径（唯一）。
  TextColumn get exePath => text().unique()();

  /// exe 所在目录（启动工作目录 / LE 参数用）。
  TextColumn get dirPath => text()();

  /// PE 提取的图标（PNG 字节，惰性生成，可为空）。
  BlobColumn get iconPng => blob().nullable()();

  /// 背景图的本地缓存路径；不把大图写入 SQLite。
  TextColumn get backgroundPath => text().nullable()();

  /// 详情弹窗专用的低分辨率模糊背景缓存路径。
  TextColumn get detailBackgroundPath => text().nullable()();

  /// 附加启动参数。
  TextColumn get launchArgs => text().withDefault(const Constant(''))();

  /// 是否经 Locale Emulator 代理启动。
  BoolColumn get useLocaleEmulator =>
      boolean().withDefault(const Constant(false))();

  /// LE Profile 名 / GUID（留空 = LEProc 默认行为）。
  TextColumn get leProfile => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get lastPlayedAt => dateTime().nullable()();

  /// 累计游玩秒数（会话提交时增量维护的冗余缓存，避免列表页聚合查询）。
  IntColumn get totalPlaySeconds => integer().withDefault(const Constant(0))();

  /// 收藏标记。
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();

  /// 所属自定义文件夹 ID（为空表示未归类/默认未放入文件夹）。
  IntColumn get folderId =>
      integer().nullable().references(GameFolders, #id)();
}

/// 游戏库自定义文件夹/分类表
class GameFolders extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 文件夹名称（如在玩、已玩过、待玩或自定义名称）
  TextColumn get name => text().withLength(min: 1, max: 128)();

  /// 排序序号
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 是否将该文件夹下的游戏计入游戏库普通排序时的累计时长 / 统计聚合
  /// 默认不计入时长排序（false），提供选项开启（true）
  BoolColumn get includeInTotalTime =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 连续游玩会话：一次"获得焦点 → 失焦超过 3s"的完整区间，
/// 中间小于 3s 的切出切回合并为同一行。
class PlaySessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 关联游戏（级联删除）。
  IntColumn get gameId => integer().nullable().references(Games, #id)();

  DateTimeColumn get startedAt => dateTime()();

  DateTimeColumn get endedAt => dateTime().nullable()();

  /// 已刷盘的持续秒数（内存累加，低频回写）。
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE CASCADE',
  ];
}

/// 轻量 KV 设置表。
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Games, PlaySessions, AppSettings, GameFolders])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaultFolders();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(games, games.backgroundPath);
      }
      if (from < 3) {
        await m.createTable(gameFolders);
        await m.addColumn(games, games.folderId);
        await _seedDefaultFolders();
      }
      if (from < 4) {
        await m.addColumn(games, games.detailBackgroundPath);
      }
    },
    beforeOpen: (details) async {
      // WAL 模式：写入低延迟；外键级联生效。
      await customStatement('PRAGMA journal_mode=WAL;');
      await customStatement('PRAGMA foreign_keys=ON;');
    },
  );

  Future<void> _seedDefaultFolders() async {
    final count = await (select(gameFolders)..limit(1)).get();
    if (count.isEmpty) {
      await batch((b) {
        b.insertAll(gameFolders, [
          GameFoldersCompanion.insert(
            name: '在玩',
            sortOrder: const Value(0),
            includeInTotalTime: const Value(false),
          ),
          GameFoldersCompanion.insert(
            name: '已玩过',
            sortOrder: const Value(1),
            includeInTotalTime: const Value(false),
          ),
          GameFoldersCompanion.insert(
            name: '待玩',
            sortOrder: const Value(2),
            includeInTotalTime: const Value(false),
          ),
        ]);
      });
    }
  }

  static LazyDatabase _open() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'blackohm.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
