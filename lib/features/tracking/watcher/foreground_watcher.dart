/// 前台焦点 watcher isolate。
///
/// 独立于 Flutter UI isolate 长驻运行，组合了三层互补的捕获机制：
///
///  1) SetWinEventHook(EVENT_SYSTEM_FOREGROUND)（首选，事件驱动，零轮询）
///     前台窗口切换的瞬间由内核投递消息唤醒本线程；
///  2) 消息专用窗口（HWND_MESSAGE 父级）订阅系统级广播：
///       WM_WTSSESSION_CHANGE  — 锁屏/解锁（挂起计时）
///       WM_POWERBROADCAST     — 睡眠/唤醒（挂起计时并落盘）
///  3) 1s 心跳兜底校验（GetForegroundWindow + IsWindowVisible + IsIconic），
///     覆盖钩子漏报与窗口最小化等边角场景。
///
/// 空闲时线程阻塞在 MsgWaitForMultipleObjectsEx 内核等待上（0% CPU），
/// 仅被前台事件 / 电源会话消息 / 关机事件 / 250ms 保活超时唤醒。
///
/// 每次前台变化都在本 isolate 内完成
/// OpenProcess → QueryFullProcessImageNameW → GetLongPathNameW → 标准化，
/// 只把轻量快照发回主 isolate，保证 UI 线程零阻塞。
///
/// 性能设计（稳态 CPU ≈ 0%）：
///  * 心跳对“同窗口且可见性未变”走快速门控，仅做 IsWindowVisible/IsIconic
///    两次廉价调用，跳过全部跨进程查询——同窗口存活期内五项去重键
///   （hwnd/pid/imagePath/commandLine/visible）不可能变化，不会漏发快照；
///  * pid → (imagePath, commandLine) 结果缓存：窗口反复切换时免去重复的
///    OpenProcess + 镜像路径解析；缓存随快照失效（锁屏/解锁/睡眠/唤醒）
///    一并清空，杜绝进程退出后 PID 复用的脏读。
library;

import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../../../core/path_normalizer.dart';
import 'watcher_protocol.dart';
import 'win32_bindings.dart' as w;

class _WatcherConfig {
  const _WatcherConfig(this.replyTo);
  final SendPort replyTo;
}

/// pid → 进程镜像解析结果缓存条目（commandLine 仅临时目录壳进程非空）。
class _PathEntry {
  const _PathEntry(this.imagePath, this.commandLine);
  final String? imagePath;
  final String? commandLine;
}

/// 路径缓存上限：超过即整体清空（简单防膨胀；正常桌面会话远达不到）。
const int kPathCacheLimit = 32;

/// 心跳/事件共用的快速门控（纯函数，便于单测）：
/// 同一窗口且可见性未变时，快照五项去重键均不可能变化
/// （镜像路径在进程创建时固定、pid 隶属于 hwnd），可跳过完整解析。
bool shouldSkipFullParse({
  required int hwnd,
  required bool visible,
  required int lastHwnd,
  required bool lastVisible,
}) {
  return hwnd != 0 && hwnd == lastHwnd && visible == lastVisible;
}

/// 由主 isolate 调用：spawn watcher 并返回其 isolate 句柄。
Future<Isolate> spawnForegroundWatcher(SendPort replyTo) {
  return Isolate.spawn(
    _watcherMain,
    _WatcherConfig(replyTo),
    debugName: 'foreground-watcher',
  );
}

/// 主 isolate 调用：触发 watcher 优雅关机（内核 Event 跨 isolate 有效）。
void signalShutdown(int eventHandle) => w.setEvent(eventHandle);

/// 判断进程镜像路径是否位于临时目录（EVB 等单文件壳的影子 stub 特征）。
bool isTempImagePath(String imagePath) {
  final p = imagePath.toLowerCase();
  return p.contains(r'\appdata\local\temp\') ||
      p.startsWith(r'c:\windows\temp\') ||
      p.contains(r'\temp\evb');
}

void _watcherMain(_WatcherConfig config) {
  final reply = config.replyTo;

  // ── 1. 关机信号内核对象（主 isolate SetEvent 即触发优雅退出）─────
  final shutdownEvent = w.createShutdownEvent();

  // ── 2. 消息专用窗口：接收锁屏/睡眠系统通知 ──────────────────────
  late final NativeCallable<w.WinEventProcNative> winEventCb;
  late final NativeCallable<w.WndProcNative> wndProcCb;

  var lastHwnd = -1;
  var lastVisible = false;
  var locked = false;
  var suspended = false;
  final pathCache = <int, _PathEntry>{};

  void invalidateSnapshot() {
    lastHwnd = -1;
    lastVisible = false;
    // 进程可能在失效窗口期内退出（PID 复用风险）→ 缓存一并作废。
    pathCache.clear();
  }

  void emitSnapshot(int hwnd) {
    if (hwnd == 0) {
      if (lastHwnd == 0) return; // 空前台已上报：去重
      invalidateSnapshot();
      lastHwnd = 0;
      reply.send(
        const ForegroundSnapshot(
          hwnd: 0,
          pid: 0,
          imagePath: null,
          commandLine: null,
          windowTitle: '',
          visible: false,
        ),
      );
      return;
    }
    // 廉价可见性检查先行：心跳稳态下同窗口同可见性，直接短路，
    // 避免每秒重复执行 OpenProcess + 镜像路径解析。
    final visible = w.isWindowVisible(hwnd) && !w.isIconic(hwnd);
    if (shouldSkipFullParse(
      hwnd: hwnd,
      visible: visible,
      lastHwnd: lastHwnd,
      lastVisible: lastVisible,
    )) {
      return;
    }
    final pid = w.pidForWindow(hwnd);
    String? imagePath;
    String? commandLine;
    if (pid != 0) {
      final cached = pathCache[pid];
      if (cached != null) {
        imagePath = cached.imagePath;
        commandLine = cached.commandLine;
      } else {
        final hProc = w.openProcessQuery(pid);
        if (hProc != 0) {
          final raw = w.queryProcessImagePath(hProc);
          if (raw != null) {
            imagePath = normalizeExePath(w.getLongPathName(raw));
            // 仅对位于临时目录的进程采集命令行：这是 EVB 等单文件壳
            // 把窗口宿主放到 %TEMP%\evbXXXX.tmp 的特征，用于补充归因。
            if (isTempImagePath(imagePath)) {
              commandLine = w.queryProcessCommandLine(hProc);
            }
          }
          w.closeHandle(hProc);
        }
        if (pathCache.length >= kPathCacheLimit) pathCache.clear();
        pathCache[pid] = _PathEntry(imagePath, commandLine);
      }
    }
    lastHwnd = hwnd;
    lastVisible = visible;
    reply.send(
      ForegroundSnapshot(
        hwnd: hwnd,
        pid: pid,
        imagePath: imagePath,
        commandLine: commandLine,
        windowTitle: w.windowText(hwnd),
        visible: visible,
      ),
    );
  }

  // ── 3. WinEvent 钩子回调（isolate-local：在泵消息时同线程同步回调）──
  winEventCb = NativeCallable<w.WinEventProcNative>.isolateLocal((
    int hook,
    int event,
    int hwnd,
    int idObject,
    int idChild,
    int eventThread,
    int eventTime,
  ) {
    const objidWindow = 0;
    if (idObject != objidWindow || hwnd == 0) return;
    if (locked || suspended) return;
    emitSnapshot(hwnd);
  });

  // ── 4. 窗口过程：转发锁屏/睡眠事件 ─────────────────────────────
  wndProcCb = NativeCallable<w.WndProcNative>.isolateLocal((
    int hwnd,
    int msg,
    int wParam,
    int lParam,
  ) {
    switch (msg) {
      case w.wmWtsSessionChange:
        if (wParam == w.wtsSessionLock) {
          locked = true;
          reply.send(const SystemLocked());
        } else if (wParam == w.wtsSessionUnlock) {
          locked = false;
          invalidateSnapshot();
          reply.send(const SystemUnlocked());
          emitSnapshot(w.getForegroundWindow());
        }
        return 0;
      case w.wmPowerBroadcast:
        if (wParam == w.pbtApmSuspend) {
          suspended = true;
          reply.send(const SystemSuspend());
        } else if (wParam == w.pbtApmResumeSuspend ||
            wParam == w.pbtApmResumeAutomatic) {
          suspended = false;
          invalidateSnapshot();
          reply.send(const SystemResumed());
          emitSnapshot(w.getForegroundWindow());
        }
        return 1;
      case w.wmClose:
        return 0;
      default:
        return w.defWindowProc(hwnd, msg, wParam, lParam);
    }
  }, exceptionalReturn: 0);

  final hInst = w.getModuleHandleNull();
  const className = 'BlackOhmWatcherWnd';
  final wc = calloc<w.WndClassExW>();
  var atom = 0, hwnd = 0, hook = 0, powerNotify = 0, wtsOk = false;

  try {
    atom = w.registerWatcherWindowClass(
      wc,
      className,
      hInst,
      wndProcCb.nativeFunction,
    );
    hwnd = w.createMessageOnlyWindow(className, hInst);
    wtsOk = hwnd != 0 && w.wtsRegisterSessionNotification(hwnd);
    powerNotify = hwnd != 0 ? w.registerSuspendResumeNotification(hwnd) : 0;
    hook = w.setWinEventHook(winEventCb.nativeFunction);

    // ── 5. 就绪握手，随后立即推送当前前台快照 ───────────────────
    reply.send(WatcherReady(shutdownEventHandle: shutdownEvent));
    emitSnapshot(w.getForegroundWindow());

    // ── 6. 主泵：内核阻塞等待，空闲 0% CPU ─────────────────────
    final msgBuf = calloc<w.Msg>();
    var ticks = 0;
    var running = true;
    while (running) {
      final wait = w.msgWaitForMultipleObjectsEx([shutdownEvent], 250);
      if (wait == w.waitObject0) break;
      if (wait == w.waitFailed) break;
      if (!w.pumpMessages(msgBuf)) break;
      // 心跳兜底：约每秒校验一次前台窗口真实状态
      if (++ticks >= 4) {
        ticks = 0;
        if (!locked && !suspended) emitSnapshot(w.getForegroundWindow());
      }
    }
    calloc.free(msgBuf);
    reply.send(const WatcherStopped());
  } finally {
    // ── 7. 清理：钩子 → 通知注册 → 窗口 → 类 → 内核对象 ────────
    if (hook != 0) w.unhookWinEvent(hook);
    if (powerNotify != 0) w.unregisterSuspendResumeNotification(powerNotify);
    if (wtsOk) w.wtsUnRegisterSessionNotification(hwnd);
    if (hwnd != 0) w.destroyWindow(hwnd);
    if (atom != 0) w.unregisterWindowClass(className, hInst);
    w.closeHandle(shutdownEvent);
    winEventCb.close();
    wndProcCb.close();
    calloc.free(wc);
  }
}
