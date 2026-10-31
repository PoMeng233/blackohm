# 多 EXE 跟踪与卡片合并设计

- 日期：2026-11-01
- 状态：待评审（尚未实现）
- 对应方向：每张卡跟踪多个 exe + 在卡片设置里合并卡片

## 1. 背景

汉化补丁、Locale Emulator 包装器、单文件壳（EVB）等场景下，补丁/壳进程会启动原版游戏 exe。当前模型一张卡只有一个 `Games.exePath`：

- `GameAttributor` 先按 `imagePath == exePath` 精确命中，失败后只对临时目录里的包装壳做命令行/标题启发式；
- 补丁启动原版 exe 时，会话可能归到补丁卡，或者根本记不上；
- 同一游戏被拆成两张卡时，时长与会话分散。

本设计引入“每张卡跟踪多个 exe（主程序 + 别名）”和“把另一张卡合并进来”。

## 2. 目标

1. 一张卡可跟踪多个 exe；运行任一被跟踪 exe 都计入该卡。
2. 卡片设置内可添加 / 移除别名 exe。
3. 卡片设置内可把另一张卡合并进来：目标卡保留标题、图标、背景、文件夹、启动配置与 Bangumi 元数据；只并入累计时长、游玩会话、启动次数；源卡删除，源卡主 exe 与其别名成为目标卡别名。
4. 别名参与全局去重、批量导入、备份/恢复与存活检测。
5. 别名索引只保存路径字符串，不引入常驻大内存结构。

## 3. 非目标

- 不做“扫描目录时自动把所有 exe 都加为别名”。
- 不把别名设为启动目标（启动仍走主 exe；后续可扩展“交换主程序”）。
- 不合并文件夹卡片。
- 不提供合并撤销 / 合并历史。
- 不按 exe 分别统计时长（所有时长仍归卡）。

## 4. 数据模型

新增表 `GameAliases`（`lib/core/database/app_database.dart`）：

```dart
class GameAliases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get gameId => integer().references(Games, #id)();
  TextColumn get exePath => text().unique()();
  TextColumn get dirPath => text()();
  TextColumn get label => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE CASCADE',
  ];
}
```

- 主 exe 仍存 `Games.exePath`，别名只存附加路径。
- 路径一律经 `normalizeExePath`（`lib/core/path_normalizer.dart`）后写入。
- **全局不变量**：任一规范化路径在 `games.exe_path` 与 `game_aliases.exe_path` 的并集中最多出现一次。SQLite 无法跨表建唯一约束，因此入库、添加别名、合并、恢复都走仓库层同一个路径占用检查。
- `game_aliases.game_id` 建索引，归因重建时按卡取别名。

## 5. 迁移

- `schemaVersion` 8 → 9。
- `onUpgrade` 增加 `if (from < 9) await _createTableIfMissing(m, gameAliases);`。
- 复用 `bba6ec5` 的思路：先查 `sqlite_master` 再建表，迁移被中断后重跑不会因“表已存在”失败。
- 不回填数据；老用户初始别名数为 0。
- `beforeOpen` 已开启外键，级联删除生效。

## 6. 归因与存活

`lib/features/tracking/game_attributor.dart`：

- `rebuild(games, aliases)`：`_exeIndex` 同时收录主路径与别名路径 → gameId。
- `resolve` 返回命中结果（gameId + 命中的 imagePath），不再只返回 gameId。
- 包装壳启发式条目也收录别名的 exe 主名 / 目录名，仍保持“唯一才收敛”的保守规则。
- `TrackingEngine._ActiveSession` 记录命中的 exe 文件名。
- `GraceWatchdog.arm` 接受文件名集合：精确命中别名时只传该 exe；包装壳命中时传该卡全部跟踪文件名，任一存在即 `running`。
- `lib/providers.dart` 新增 `aliasListProvider`；`trackingEngineProvider` 同时监听游戏与别名流，合并后 `rebuildIndex(games, aliases)`。

## 7. 合并事务

`GameRepository.mergeInto({required int targetId, required int sourceId})`，单事务：

1. 读取两张卡；不存在或相同则抛错，由 UI 提示。
2. `UPDATE play_sessions SET game_id = target WHERE game_id = source`。必须先于删除，避免级联清掉会话。
3. 源卡别名改挂目标卡；若与目标卡已有别名重复，删除重复行。
4. 插入 `source.exePath` 作为目标卡别名（`dirPath = source.dirPath`，`label = source.title`），冲突则忽略。
5. 目标卡：`total_play_seconds += source.total_play_seconds`；`launch_count += source.launch_count`；`last_played_at = max(两者, 空值安全)`。
6. 删除源卡（级联清掉残留别名 / 会话）。
7. 目标卡其余字段（标题、图标、背景、文件夹、启动参数、LE、Bangumi、tileSize、收藏）保持不变。

前置条件：若计时引擎存在活跃或暂停会话（源或目标），UI 先调用新增的 `TrackingEngine.settleActive()` 并等待落盘，再执行合并；这样源卡累计时长已包含当前会话。

## 8. UI

入口：游戏详情 / 卡片设置弹窗（`lib/ui/widgets/game_detail_dialog.dart`）新增“跟踪的 EXE”区块：

- 主程序一行，不可移除，显示路径。
- 别名列表：路径 + 来源标签（合并时写入源卡标题）+ 移除按钮。
- “添加跟踪 EXE”：文件选择器仅接受 `.exe`；规范化后校验全局唯一；若已被其他卡跟踪，提示“该 exe 已由《X》跟踪，可将其合并到此卡”，不插入。
- “合并其他游戏”：搜索列表（排除自身）→ 预览（将并入 X 时长、N 次启动、M 条会话、K 个 exe；源卡将被移除；目标卡外观与配置不变）→ 二次确认。
- 别名增删与合并立即生效并给 SnackBar 反馈；标题 / 路径 / 参数等字段仍走现有“未保存修改”保存条与关闭确认。
- 移除别名时若该 exe 正在计时，弹确认（移除后立即失去归因）。
- 视觉沿用 MD3 现有区块与操作条，不新增动画。

## 9. 入库与去重

`lib/features/scanner/ingestion_service.dart`：

- 现有 `existing` 集合从 `games.exePath` 扩展为“主路径 ∪ 全部别名路径”。
- 单款 / 批量导入、目录扫描遇到别名路径时按重复跳过，避免生成第二张卡。
- 批量导入报告可按现有“已存在”统计处理，文案可后续补“已作为别名跟踪”。

## 10. 备份 / 恢复 / 清空

`lib/features/data/backup_service.dart`：

- 导出：整库文件复制，自动包含新表，无需改逻辑。
- 合并导入：`existingExe` 同时包含主路径与别名；游戏导入成功后按 id 映射导入其别名；被整款跳过的游戏不导入别名；与当前主路径 / 别名冲突的别名行跳过。结果增加 `importedAliases` / `skippedAliases` 统计并在设置页汇总里展示。
- 覆盖导入：先清空 `game_aliases`（或依赖级联），先导游戏再导别名，满足外键顺序。
- 清空游戏：级联删除别名，保留设置与文件夹分组。
- 旧备份没有 `game_aliases` 表 → 视为 0 别名。

## 11. 测试计划

- 纯函数：别名精确命中；包装壳 + 别名主名收敛；多候选仍返回 null。
- 数据库（内存 Drift）：别名唯一约束、级联删除、v8→v9 迁移与中断重跑。
- 合并：会话迁移、时长 / 启动次数求和、`lastPlayedAt` 取最大、源卡删除、源 exe 与别名改挂、重复别名去重、空值边界。
- 入库：别名路径按重复跳过。
- 备份：无别名表的旧备份、合并时跳过别名冲突、覆盖恢复别名。
- 引擎：`settleActive` 先落盘再合并；别名会话进入 grace 后的存活判定。
- UI：别名区块增删、合并选择器搜索与确认、无其他卡时禁用、未保存修改与合并的交互。

## 12. 待确认

1. 别名增删是“立即生效”还是“随保存条一起提交”？（建议立即生效，避免半保存状态。）
2. 是否需要“把某个别名设为主程序 / 启动目标”？（建议本期不做。）
3. 合并后源卡的背景、图标、Bangumi 信息直接丢弃（按已定语义），确认？
4. 别名列表是否需要“打开所在目录”按钮，方便定位补丁 exe？
