/// 全局常量：防抖窗口、刷盘周期、扫描深度、Exe 黑名单等。
library;

/// 失焦后的暂停提示窗口：卡片立即显示红色静态边框，期间不累加时间。
const Duration kFocusPausePeriod = Duration(minutes: 1);

/// 同一游戏的 Session 自动合并窗口。失焦超过 1 分钟仍保持暂停态，
/// 直到该窗口结束才提交；历史层也以此窗口合并相邻记录。
const Duration kFocusGracePeriod = Duration(minutes: 30);

/// 游戏仍在前台但连续未发生键盘/鼠标输入时，自动暂停计时的阈值。
const Duration kInputIdlePausePeriod = Duration(minutes: 30);

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

/// Locale Emulator 默认启动参数模板。
/// 占位符：`{exe}` 目标程序绝对路径，`{profile}` LE Profile 名/GUID，`{args}` 附加参数。
/// LEProc 常见形式：
///   -run "{exe}"                 （按全局默认 Profile 运行）
///   -runas {profile} "{exe}"     （指定 Profile，如 Japan / zh-CN）
const String kDefaultLeArgsTemplate = '-run "{exe}"';

/// GitHub Releases 页面（关于页"检查更新"跳转目标）。
const String kGitHubReleasesUrl =
    'https://github.com/PoMeng233/blackohm/releases/latest';
