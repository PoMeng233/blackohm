/// 内存占用治理：空闲/托盘态工作集修剪。
///
/// Flutter Windows 引擎常驻私有内存无法从 Dart 层消除，但可以通过
/// `SetProcessWorkingSetSize(-1, -1)` 把冷页换出工作集：任务管理器
/// 报告的内存随即回落到十几 MB 量级，页面再次被触碰时按需载入，
/// 不影响计时与托盘功能。
///
/// 触发时机：
///   - 主窗口隐藏到托盘后（最常见形态，用户看不到 UI）；
///   - 托盘态下的周期巡检（默认每 5 分钟一次）；
///   - 主窗口失去焦点 30 秒后（用户切到任务管理器/别的应用查看内存时，
///     任务管理器能读到换出后的低工作集）；
///   - 可见且系统连续无输入时（Debug/Profile/Release 均生效）。
///     可见态换出按需回填页面，Debug 的 JIT 页回填成本更高，因此
///     可见态修剪不清图像缓存，并保留 2 分钟冷却。
library;

import 'dart:async';
import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../tracking/watcher/win32_bindings.dart' show getLastInputIdleMs;

class MemoryTrimService {
  MemoryTrimService({this.isTrackingActive});

  /// 当前主窗口是否可见；AppShell 在 show/hide 时同步。
  bool windowVisible = true;

  /// 主窗口是否持有焦点；失焦 30 秒后换出工作集。
  bool windowFocused = true;

  /// 若为真（有游戏正在记录/暂停中）则跳过可见态修剪，避免播放时清图卡顿。
  final bool Function()? isTrackingActive;

  Timer? _timer;
  Timer? _visibleTimer;
  Timer? _initialTimer;
  Timer? _blurTimer;
  bool _started = false;
  DateTime? _lastVisibleTrimAt;

  static const _blurTrimDelay = Duration(seconds: 30);

  /// Debug 的 JIT/脚本页回填最贵，空闲阈值放宽到 2 分钟。
  static Duration get _visibleIdleThreshold =>
      kDebugMode ? const Duration(minutes: 2) : const Duration(minutes: 1);

  /// 可见态两次换出的最小间隔：避免反复遍历整个工作集造成抖动。
  static const _visibleTrimCooldown = Duration(minutes: 2);

  static final int Function() _getCurrentProcess = DynamicLibrary.open(
    'kernel32.dll',
  ).lookupFunction<IntPtr Function(), int Function()>('GetCurrentProcess');

  static final int Function(int, int, int) _setWorkingSetSize =
      DynamicLibrary.open('kernel32.dll').lookupFunction<
        Int32 Function(IntPtr, IntPtr, IntPtr),
        int Function(int, int, int)
      >('SetProcessWorkingSetSize');

  void start() {
    if (_started) return;
    _started = true;
    // 启动 90 秒后做一次首修剪（等首帧、图标、字体缓存稳定）。
    _initialTimer = Timer(const Duration(seconds: 90), _trimIfHidden);
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _trimIfHidden());
    // 可见但空闲时也换出冷页（不清图像缓存，避免屏幕闪白）。
    _visibleTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _trimIfVisibleIdle(),
    );
  }

  /// 主窗口隐藏到托盘后调用；稍候片刻再修剪，让隐藏动画/消息排空。
  Future<void> notifyWindowHidden() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    trim();
  }

  void _trimIfHidden() {
    if (!windowVisible) trim();
  }

  /// AppShell 在 onWindowFocus/onWindowBlur 时同步。
  void setFocused(bool focused) {
    windowFocused = focused;
    _blurTimer?.cancel();
    _blurTimer = null;
    if (focused) return;
    _blurTimer = Timer(_blurTrimDelay, _trimIfBlurred);
  }

  /// 失焦后仍无人回到本窗口：换出冷页，任务管理器读数随之回落。
  /// 不清图像缓存，避免回来后整屏重解码。
  void _trimIfBlurred() {
    if (windowFocused || !windowVisible) return;
    if (isTrackingActive?.call() ?? false) return;
    final last = _lastVisibleTrimAt;
    if (last != null &&
        DateTime.now().difference(last) < _visibleTrimCooldown) {
      return;
    }
    _lastVisibleTrimAt = DateTime.now();
    trim(clearImages: false);
  }

  /// 可见但系统空闲：仅换出工作集，不清图像缓存（避免可见时闪白）。
  /// 有输入或正在计时时不动作，避免用户交互时出现页错误卡顿。
  void _trimIfVisibleIdle() {
    if (!windowVisible || !windowFocused) return;
    if (isTrackingActive?.call() ?? false) return;
    final last = _lastVisibleTrimAt;
    if (last != null &&
        DateTime.now().difference(last) < _visibleTrimCooldown) {
      return;
    }
    final idleMs = getLastInputIdleMs();
    if (idleMs == null || idleMs < _visibleIdleThreshold.inMilliseconds) {
      return;
    }
    _lastVisibleTrimAt = DateTime.now();
    trim(clearImages: false);
  }

  /// 清空图像缓存并把工作集换出。
  void trim({bool clearImages = true}) {
    if (clearImages) {
      try {
        final cache = PaintingBinding.instance.imageCache;
        cache.clear();
        cache.clearLiveImages();
      } catch (_) {}
    }
    try {
      _setWorkingSetSize(_getCurrentProcess(), -1, -1);
    } catch (_) {}
  }

  void dispose() {
    _initialTimer?.cancel();
    _initialTimer = null;
    _timer?.cancel();
    _timer = null;
    _visibleTimer?.cancel();
    _visibleTimer = null;
    _blurTimer?.cancel();
    _blurTimer = null;
    _started = false;
  }
}
