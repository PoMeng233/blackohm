/// 全局常量：防抖窗口、刷盘周期、扫描深度、Exe 黑名单等。
library;

/// 前台焦点切换防抖窗口：短于该时长的切出与切回合并为同一连续 Session。
const Duration kFocusGracePeriod = Duration(seconds: 3);

/// 活跃 Session 的刷盘周期（内存累加，低频批量提交 SQLite，避免频繁 I/O）。
const Duration kSessionFlushInterval = Duration(seconds: 60);

/// 兜底心跳周期：watcher isolate 在 MsgWait 超时唤醒时顺带校验前台窗口。
const Duration kWatcherHeartbeat = Duration(seconds: 1);

/// MsgWaitForMultipleObjectsEx 的阻塞超时（毫秒）。
/// 平时线程休眠在内核 wait 上（0% CPU），仅被消息唤醒。
const int kWatcherWaitMs = 250;

/// 目录递归扫描深度上限，避免误拖根目录导致全盘递归。
const int kScanMaxDepth = 3;

/// 目录内文件数硬上限（单层），超过则跳过该目录（防误拖系统目录）。
const int kScanMaxEntriesPerDir = 20000;

/// 常见非游戏可执行文件黑名单（不区分大小写）。
/// 覆盖卸载器、运行库安装器、崩溃报告器、配置/安装工具等。
final RegExp kExeBlacklist = RegExp(
  r'^(unins.*|dxwebsetup|dxsetup|vcredist.*|vc_redist.*|crashreport.*|'
  r'config|setting(s)?|setup|install.*|.*installer|uninst.*|'
  r'dotnetfx.*|ndp.*|oalinstall|directx.*|langupdate.*|update.*)\.exe$',
  caseSensitive: false,
);

/// Locale Emulator 默认启动参数模板。
/// 占位符：`{exe}` 目标程序绝对路径，`{profile}` LE Profile 名/GUID，`{args}` 附加参数。
/// LEProc 常见形式：
///   -run "{exe}"                 （按全局默认 Profile 运行）
///   -runas {profile} "{exe}"     （指定 Profile，如 Japan / zh-CN）
const String kDefaultLeArgsTemplate = '-run "{exe}"';
