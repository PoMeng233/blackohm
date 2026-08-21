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

/// 由主 isolate 调用：spawn watcher 并返回其 isolate 句柄。
Future<Isolate> spawnForegroundWatcher(SendPort replyTo) {
  return Isolate.spawn(_watcherMain, _WatcherConfig(replyTo),
      debugName: 'foreground-watcher');
}

void _watcherMain(_WatcherConfig config) {
  final reply = config.replyTo;

  // ── 1. 关机信号内核对象（主 isolate SetEvent 即触发优雅退出）─────
  final shutdownEvent = w.createShutdownEvent();

  // ── 2. 消息专用窗口：接收锁屏/睡眠系统通知 ──────────────────────
  late final NativeCallable<w.WinEventProcDart> winEventCb;
  late final NativeCallable<LRESULT Function(HWND, DWORD, WPARAM, LPARAM)>
      wndProcCb;

  var lastHwnd = -1;
  var locked = false;
  var suspended = false;

  void emitSnapshot(int hwnd) {
    if (hwnd == lastHwnd) return;
    lastHwnd = hwnd;
    if (hwnd == 0) {
      reply.send(const ForegroundSnapshot(
          hwnd: 0, pid: 0, imagePath: null, windowTitle: '', visible: false));
      return;
    }
    final pid = w.pidForWindow(hwnd);
    String? imagePath;
    if (pid != 0) {
      final hProc = w.openProcessQuery(pid);
      if (hProc != 0) {
        final raw = w.queryProcessImagePath(hProc);
        w.closeHandle(hProc);
        // 短路径展开 + 标准化后匹配；提权进程拿不到路径则维持 null。
        if (raw != null) imagePath = normalizeExePath(w.getLongPathName(raw));
      }
    }
    reply.send(ForegroundSnapshot(
      hwnd: hwnd,
      pid: pid,
      imagePath: imagePath,
      windowTitle: w.windowText(hwnd),
      visible: w.isWindowVisible(hwnd) && !w.isIconic(hwnd),
    ));
  }

  // ── 3. WinEvent 钩子回调（isolate-local：在泵消息时同线程同步回调）──
  winEventCb =
      NativeCallable<w.WinEventProcDart>.isolateLocal((hook, event, hwnd,
          idObject, idChild, eventThread, eventTime) {
        const objidWindow = 0; // OBJID_WINDOW
        if (idObject != objidWindow || hwnd == 0) return;
        if (locked || suspended) return; // 锁屏/睡眠期间忽略前台噪声
        emitSnapshot(hwnd);
      });

  // ── 4. 窗口过程：转发锁屏/睡眠事件 ─────────────────────────────
  wndProcCb = NativeCallable<LRESULT Function(HWND, DWORD, WPARAM, LPARAM)>
      .isolateLocal((hwnd, msg, wParam, lParam) {
    switch (msg) {
      case w.WM_WTSSESSION_CHANGE:
        if (wParam == w.WTS_SESSION_LOCK) {
          locked = true;
          reply.send(const SystemLocked());
        } else if (wParam == w.WTS_SESSION_UNLOCK) {
          locked = false;
          reply.send(const SystemUnlocked());
        }
        return 0;
      case w.WM_POWERBROADCAST:
        if (wParam == w.PBT_APMSUSPEND) {
          suspended = true;
          reply.send(const SystemSuspend());
        } else if (wParam == w.PBT_APMRESUMEAUTOMATIC) {
          suspended = false;
          reply.send(const SystemResumed());
        }
        return 1; // TRUE 表示已处理电源广播
      case w.WM_CLOSE:
        return 0; // 忽略外部关闭请求，仅受关机事件控制
      default:
        return w.defWindowProc(hwnd, msg, wParam, lParam);
    }
  }));

  final hInst = w.getModuleHandleNull();
  const className = 'BlackOhmWatcherWnd';
  final wc = calloc<WndClassExW>();
  var atom = 0, hwnd = 0, hook = 0, powerNotify = 0, wtsOk = false;

  try {
    atom = w.registerWatcherWindowClass(wc, className, hInst, wndProcCb.nativeFunction);
    hwnd = w.createMessageOnlyWindow(className, hInst);
    wtsOk = hwnd != 0 && w.wtsRegisterSessionNotification(hwnd);
    powerNotify = hwnd != 0 ? w.registerSuspendResumeNotification(hwnd) : 0;
    hook = w.setWinEventHook(winEventCb.nativeFunction);

    // ── 5. 就绪握手，随后立即推送当前前台快照 ───────────────────
    reply.send(WatcherReady(shutdownEventHandle: shutdownEvent));
    emitSnapshot(w.getForegroundWindow());

    // ── 6. 主泵：内核阻塞等待，空闲 0% CPU ─────────────────────
    final msgBuf = calloc<Msg>();
    var ticks = 0;
    var running = true;
    while (running) {
      final wait = w.msgWaitForMultipleObjectsEx([shutdownEvent], w2ms());
      if (wait == w.WAIT_OBJECT_0) break; // 关机信号
      if (wait == w.WAIT_FAILED) break;
      // 分发消息（WinEvent 回调 / WndProc 在此同步执行）
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

/// 250ms 保活超时（与 kWatcherHeartbeat 解耦的常量，避免 core 依赖倒挂）。
int w2ms() => 250;
