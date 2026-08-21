# BlackOhm Architecture

本文档说明 BlackOhm 的运行时数据流、Windows Native 实现、数据库模型与性能边界。它对应的是当前 Windows-only Flutter Desktop 实现，而不是泛化的跨平台设计。

## 1. 分层与职责

```text
Flutter UI (main isolate)
  │ Riverpod providers / 页面组件
  │
  ├── GameRepository / SessionRepository / SettingsRepository
  │     └── Drift NativeDatabase.createInBackground (SQLite 3 / WAL)
  │
  ├── TrackingEngine
  │     ├── exePath → gameId 内存索引
  │     ├── 1 秒时基、3 秒焦点防抖、60 秒批量刷盘
  │     └── 活跃状态 Stream（只驱动活跃卡片秒表）
  │
  └── foreground-watcher isolate
        ├── SetWinEventHook(EVENT_SYSTEM_FOREGROUND)
        ├── 消息专用 HWND + WTS / suspend-resume 通知
        ├── MsgWaitForMultipleObjectsEx 内核阻塞消息泵
        └── QueryFullProcessImageNameW 真实镜像路径解析
```

UI 只消费 `TrackingPublicState` 和 Drift 的响应式流，**不执行递归目录枚举、PE 资源解析或高频 Win32 调用**。目录扫描和 PE 富化由一次性 `Isolate.run` 任务处理；焦点监听由长期 watcher isolate 处理。

## 2. 前台焦点监听

### 2.1 事件驱动主链路

watcher isolate 创建一个消息专用窗口，然后建立 `SetWinEventHook`：

```text
EVENT_SYSTEM_FOREGROUND
  → WinEventProc
  → GetForegroundWindow / HWND
  → GetWindowThreadProcessId
  → OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)
  → QueryFullProcessImageNameW
  → GetLongPathNameW（仅含 ~ 的 8.3 路径）
  → normalizeExePath（去设备前缀、统一反斜杠、小写）
  → ForegroundSnapshot via SendPort
  → TrackingEngine O(1) Map lookup
```

入口实现：`lib/features/tracking/watcher/foreground_watcher.dart`。最小 FFI surface：`lib/features/tracking/watcher/win32_bindings.dart`。

`WINEVENT_OUTOFCONTEXT` 令系统将事件投递到 watcher 线程的消息队列。该线程使用 `MsgWaitForMultipleObjectsEx` 等待消息；空闲时不做 Dart `Timer` busy loop，因此不会因轮询消耗 CPU。

### 2.2 心跳兜底

消息泵以 250 ms timeout 被唤醒。每四个 timeout（约 1 秒）执行一次：

```text
GetForegroundWindow → snapshot（仅 HWND 变化时发消息）
```

该心跳用于应对钩子投递异常、窗口可见性边角情况和后续恢复状态。它是一次轻量系统调用，而不是枚举进程或扫描窗口。

### 2.3 锁屏与睡眠

消息专用窗口注册：

- `WTSRegisterSessionNotification`：处理 `WM_WTSSESSION_CHANGE` 的 `WTS_SESSION_LOCK` / `WTS_SESSION_UNLOCK`。
- `RegisterSuspendResumeNotification`：处理 `WM_POWERBROADCAST` 的 `PBT_APMSUSPEND` / `PBT_APMRESUMEAUTOMATIC`。

锁屏和睡眠事件被转化为 `SystemLocked` / `SystemSuspend`。`TrackingEngine` 收到后直接提交当前会话，不经过 3 秒防抖，从而不计算不可交互时间。

### 2.4 权限边界

当前镜像路径查询使用 `PROCESS_QUERY_LIMITED_INFORMATION`。若游戏以管理员权限运行而 BlackOhm 未提权，Windows 可能拒绝 `OpenProcess`。watcher 会发送 `imagePath: null`，引擎将其视为失焦；要记录这种游戏，应以相同权限级别运行 BlackOhm。

## 3. 计时状态机

`TrackingEngine` 是唯一允许更新 Session 的组件。

```text
                      匹配同游戏
  ┌──────────┐      ┌─────────────┐
  │   idle   │─────▶│ live / active│
  └──────────┘      └──────┬──────┘
       ▲                   │ 非游戏/不可见/不同窗口
       │ commit             ▼
       └──────────────┌─────────────┐
                      │ grace (3 sec)│  不累加
                      └──────┬──────┘
                    同游戏回归│  超时
                              └────────▶ commit → idle

任意状态 + 锁屏/睡眠 → immediate commit → idle
```

### 3.1 防抖语义

- **3 秒内切回同一已登记游戏**：恢复 `live`，保留同一条 `PlaySessions` 行；失焦期间不累计秒数。
- **超过 3 秒未回归**：提交会话，后续游戏前台时创建新会话。
- **切换到另一个登记游戏**：旧会话立即提交，然后创建新会话。
- **暂停统计**：保留焦点状态但冻结累加；UI 显示 grace 风格状态。

这种设计既避免 Alt+Tab 短暂抖动把一段游玩拆碎，也不把查攻略、聊天或最小化的时间误算为游玩时长。

### 3.2 刷盘策略

| 时机 | 数据库操作 |
| --- | --- |
| 获得游戏焦点 | `INSERT PlaySessions`，取得 session id |
| 持续前台每 60 秒 | `UPDATE durationSeconds` |
| 失焦超过 3 秒 | `UPDATE durationSeconds + endedAt`，并为 `Games.totalPlaySeconds` 做增量更新 |
| 锁屏、睡眠、程序关闭 | 同上，立即提交 |

好处：活跃游戏每分钟约一次 SQLite 写入；应用崩溃时最多遗失一个刷盘周期的未提交时间。数据库采用 WAL 并通过 `NativeDatabase.createInBackground` 运行在 Drift 后台连接上。

## 4. 数据模型

```text
Games
  id                  INTEGER PK
  title               TEXT
  exe_path            TEXT UNIQUE（标准化路径）
  dir_path            TEXT
  icon_png            BLOB nullable
  launch_args         TEXT
  use_locale_emulator BOOLEAN
  le_profile          TEXT
  created_at          DATETIME
  last_played_at      DATETIME nullable
  total_play_seconds  INTEGER（用于库页面的反规范化缓存）
  favorite            BOOLEAN

PlaySessions
  id                INTEGER PK
  game_id           INTEGER FK → Games.id
  started_at        DATETIME
  ended_at          DATETIME nullable
  duration_seconds  INTEGER

AppSettings
  key    TEXT PK
  value  TEXT
```

`exe_path` 必须始终来自 `normalizeExePath`。入库路径会尽可能通过 `File.resolveSymbolicLinks()` 解析；运行期路径通过 `GetLongPathNameW` 展开 8.3 形式。两侧均小写化与统一分隔符，保证 Map 匹配稳定。

## 5. 目录扫描与 PE 富化

### 5.1 受限扫描

`scanForGameExes` 使用 BFS：

- 默认最大深度：`3`
- 单目录最大条目数：`20,000`
- 总候选最大数量：`64`
- 过滤卸载器、DirectX/VC++ 运行库、崩溃报告器、配置工具和安装器。
- 额外跳过 `_CommonRedist`、`DirectX`、`vcredist`、`$Recycle.Bin` 等目录。

限制的目标不是减少正常游戏目录的覆盖率，而是阻止用户误拖入磁盘根目录时造成全盘递归和 UI 假死。

### 5.2 PE 资源解析

`pe_info.dart` 只读取目标 `.exe` 的二进制数据，在独立 Isolate 中处理：

```text
DOS MZ header → PE signature → COFF → Optional Header
  → resource data directory → RVA/file offset 映射
  → RT_VERSION (16) ：FileDescription / ProductName / FileVersion
  → RT_GROUP_ICON (14) → RT_ICON (3) → DIB (32/24/8/4 bpp)
  → RGBA → 内建 zlib + CRC32 PNG 编码器
```

解析失败会降级为目录名和默认图标，绝不会阻止游戏入库。

## 6. Locale Emulator

启动器总是以 `ProcessStartMode.detached` 启动游戏或 LEProc；计时器不持有、也不依赖这个子进程对象。

```text
BlackOhm → LEProc.exe → game.exe
                         │
Windows foreground HWND ─┴→ QueryFullProcessImageNameW(game.exe)
                            → normalized exe_path → Games row
```

因此 LE 派生、外部启动器派生、用户手动双击都走同一匹配路径。可配置模板支持不同 LEProc CLI 版本，例如：

```text
-run "{exe}"
-runas "{profile}" "{exe}" {args}
```

## 7. 高刷新率与低能耗策略

### 7.1 120 / 144 Hz 显示器

| 风险 | 当前策略 |
| --- | --- |
| 为每张卡片每秒重建 | 仅 `TrackingPublicState` 推送活跃秒表；卡片用 game id 判定活跃，库数据通过 Drift 流更新 |
| 动画触发昂贵重绘 | 前台卡片的呼吸阴影由单个 `AnimationController` 驱动；其它卡片不播放动画 |
| 网格滚动重绘 | 卡片外层使用 `RepaintBoundary`；图标是 SQLite BLOB，Flutter 图片解码缓存复用 |
| 频繁全局 setState | 搜索和视图切换局部发生在 `LibraryPage`；系统 watcher 不触碰 UI widget tree |

发布前建议用 DevTools 的 Performance Overlay 和 Raster Cache 指标，在 120/144 Hz 屏幕上滚动 500+ 条库记录，确认没有 shader compilation 或过度 rasterization 峰值。

### 7.2 低能耗后台状态

| 场景 | 低能耗措施 |
| --- | --- |
| 未发生窗口切换 | watcher 线程阻塞在 `MsgWaitForMultipleObjectsEx` |
| 无游戏活跃 | `TrackingEngine` 的 tick 立即返回；没有数据库写入 |
| 游戏持续活跃 | 仅 1 秒内存整数累加、60 秒一次 DB UPDATE |
| 窗口关闭 | 默认 hide-to-tray，Flutter 窗口不销毁，监控持续运行 |
| 扫描游戏目录 | 独立 Isolate，BFS 深度/数量上限，完成后 Isolate 回收 |
| 解析图标与版本信息 | 独立 Isolate 批处理，不占 UI 线程 |

### 7.3 建议的发布验收

用目标发布包而不是 Debug 模式测量：

1. **Idle**：窗口隐藏到托盘、没有游戏在前台，观察 5 分钟平均 CPU 与 Working Set。
2. **Active**：让单一游戏前台运行 10 分钟，检查每 60 秒一次数据库写入和累计时间。
3. **Focus**：交替切换游戏、浏览器、最小化、锁屏/唤醒，检查 Session 分割与时间不误算。
4. **Scan**：拖入含多个安装器、运行库、主程序的目录，验证黑名单和候选弹窗。
5. **LE**：通过 LEProc 和手动启动各测试一次，确认最终游戏 exe 均被命中。

性能目标必须以这种实测为准；Flutter 引擎版本、显卡驱动、系统字体缓存和安全软件均会影响内存/CPU 基线。

## 8. 安全与隐私

- 不上传游戏路径、标题、图标或时长。
- 进程查询只读取当前前台窗口所属 PID 的镜像路径，不枚举或修改其它进程。
- 所有状态存储在本地应用支持目录中的 `blackohm.db`。
- 启动程序路径只来自用户拖拽或编辑后的数据库记录；LEProc 也必须由用户在设置中选定。

## 9. 可演进方向

- 为 `Games` 增加封面路径与懒加载封面缓存。
- 增加可配置排除规则与扫描深度。
- 为玩过的游戏提供导入/导出 JSON（路径可选择脱敏）。
- 在运行期加一层 `GetWindowRect` / `IsWindow` 校验，覆盖极端 HWND 复用场景。
- 引入 Drift migration test 和基于 fake watcher event 的 TrackingEngine 状态机测试。
