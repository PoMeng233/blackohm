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

  /// 详情背景模糊派生图覆盖原图的强度（0 = 清晰）。
  RealColumn get backgroundBlurAmount =>
      real().withDefault(const Constant(0.0))();

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
  IntColumn get folderId => integer().nullable().references(GameFolders, #id)();

  /// 从 BlackOhm 启动成功的次数（外部双击启动不计入）。
  IntColumn get launchCount => integer().withDefault(const Constant(0))();

  /// Bangumi 条目 ID（自动匹配成功时记录，避免重复拉取）。
  IntColumn get bangumiSubjectId => integer().nullable()();

  /// Bangumi 评分（0-10，详情页展示）。
  RealColumn get bangumiScore => real().nullable()();

  /// 用户手动指定的磁贴尺寸：0 = 自动，1 = 小，2 = 宽，3 = 竖，4 = 大。
  IntColumn get tileSize => integer().withDefault(const Constant(0))();
}

/// 游戏别名 exe：运行任一别名同样计入该卡。
///
/// 场景：汉化补丁、启动器、包装壳会启动原版 exe，一张卡需要跟踪多个路径。
/// 主 exe 仍存于 [Games.exePath]，本表只存附加路径。
class GameAliases extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 所属游戏（级联删除）。
  IntColumn get gameId => integer().references(Games, #id)();

  /// 标准化 exe 绝对路径（全局唯一）。
  TextColumn get exePath => text().unique()();

  /// exe 所在目录（展示与后续启动扩展用）。
  TextColumn get dirPath => text()();

  /// 来源标签（合并时写入源卡标题，手动添加时可为空）。
  TextColumn get label => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE CASCADE',
  ];
}

/// 游戏库自定义文件夹/分类表
class GameFolders extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 文件夹名称（如在玩、已玩过、待玩或自定义名称）
  TextColumn get name => text().withLength(min: 1, max: 128)();

  /// 排序序号
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 旧版兼容字段：不再参与 UI 或排序逻辑。
  BoolColumn get includeInTotalTime =>
      boolean().withDefault(const Constant(false))();

  /// 是否在“全部游戏”主页显示该文件夹卡片。
  BoolColumn get showOnHome => boolean().withDefault(const Constant(true))();

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

@DriftDatabase(
  tables: [Games, PlaySessions, AppSettings, GameFolders, GameAliases],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaultFolders();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _addColumnIfMissing(m, games, games.backgroundPath);
      }
      if (from < 3) {
        await m.createTable(gameFolders);
        await _addColumnIfMissing(m, games, games.folderId);
        await _seedDefaultFolders();
      }
      if (from < 4) {
        await _addColumnIfMissing(m, games, games.detailBackgroundPath);
      }
      if (from < 5) {
        await _addColumnIfMissing(m, gameFolders, gameFolders.showOnHome);
      }
      if (from < 6) {
        await _addColumnIfMissing(m, games, games.backgroundBlurAmount);
      }
      if (from < 7) {
        await _addColumnIfMissing(m, games, games.launchCount);
        await _addColumnIfMissing(m, games, games.bangumiSubjectId);
        await _addColumnIfMissing(m, games, games.bangumiScore);
      }
      if (from < 8) {
        await _addColumnIfMissing(m, games, games.tileSize);
      }
      if (from < 9) {
        await _createTableIfMissing(m, gameAliases);
      }
    },
    beforeOpen: (details) async {
      // WAL 模式：写入低延迟；外键级联生效。
      await customStatement('PRAGMA journal_mode=WAL;');
      await customStatement('PRAGMA foreign_keys=ON;');
    },
  );

  /// 迁移可能被进程中断（列已写入、版本号未更新），再次升级时
  /// ADD COLUMN 会撞上已存在的列并让整个库打不开。逐列探测后补齐。
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final info = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    if (info.any((row) => row.data['name'] == column.name)) return;
    await m.addColumn(table, column);
  }

  /// 迁移可能被中断（表已建、版本号未更新），重跑时 CREATE TABLE 会失败。
  /// 先查 sqlite_master，存在则跳过。
  Future<void> _createTableIfMissing(Migrator m, TableInfo table) async {
    final info = await customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE type='table' AND name='${table.actualTableName}'",
    ).get();
    if (info.isNotEmpty) return;
    await m.createTable(table);
  }

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
