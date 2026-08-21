/// watcher isolate ↔ 主 isolate 的消息协议（纯 Dart，两侧共同依赖）。
library;

/// watcher → 主 isolate 的事件。
sealed class WatcherEvent {
  const WatcherEvent();
}

/// watcher 就绪握手：携带关机事件句柄。
/// 就绪后 watcher 会立即推送一条当前前台的 ForegroundSnapshot。
final class WatcherReady extends WatcherEvent {
  const WatcherReady({required this.shutdownEventHandle});

  /// 内核 Event 对象句柄（进程内全局有效）。主 isolate SetEvent 即请求优雅关机。
  final int shutdownEventHandle;
}

/// 前台窗口变化快照（事件驱动 + 心跳校验统一出口）。
/// [imagePath] 为 null 表示前台进程无法解析（提权/权限不足/系统进程）。
final class ForegroundSnapshot extends WatcherEvent {
  const ForegroundSnapshot({
    required this.hwnd,
    required this.pid,
    required this.imagePath,
    required this.windowTitle,
    required this.visible,
  });

  final int hwnd;
  final int pid;

  /// 已标准化（小写、长路径、统一反斜杠）的进程镜像绝对路径。
  final String? imagePath;
  final String windowTitle;
  final bool visible;
}

/// 系统锁屏（计时必须立即挂起，无防抖）。
final class SystemLocked extends WatcherEvent {
  const SystemLocked();
}

/// 系统解锁。
final class SystemUnlocked extends WatcherEvent {
  const SystemUnlocked();
}

/// 系统进入睡眠（计时必须立即挂起并落盘）。
final class SystemSuspend extends WatcherEvent {
  const SystemSuspend();
}

/// 系统从睡眠唤醒。
final class SystemResumed extends WatcherEvent {
  const SystemResumed();
}

/// watcher 已完成清理并即将退出。
final class WatcherStopped extends WatcherEvent {
  const WatcherStopped();
}
