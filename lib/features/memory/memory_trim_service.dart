/// 内存占用治理：空闲/托盘态工作集修剪。
///
/// Flutter Windows 引擎常驻私有内存无法从 Dart 层消除，但可以通过
/// `SetProcessWorkingSetSize(-1, -1)` 把冷页换出工作集：任务管理器
/// 报告的内存随即回落到十几 MB 量级，页面再次被触碰时按需载入，
/// 不影响计时与托盘功能。
///
/// 触发时机：
///   - 主窗口隐藏到托盘后（最常见形态，用户看不到 UI）；
///   - 托盘态下的周期巡检（默认每 5 分钟一次）。
library;

import 'dart:async';
import 'dart:ffi';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MemoryTrimService {
  MemoryTrimService();

  /// 当前主窗口是否可见；AppShell 在 show/hide 时同步。
  bool windowVisible = true;

  Timer? _timer;
  bool _started = false;

  static final int Function() _getCurrentProcess = DynamicLibrary.open(
    'kernel32.dll',
  ).lookupFunction<IntPtr Function(), int Function()>('GetCurrentProcess');

  static final int Function(int, int, int) _setWorkingSetSize =
      DynamicLibrary.open('kernel32.dll').lookupFunction<
        Int32 Function(IntPtr, IntPtr, IntPtr),
        int Function(int, int, int)
      >('SetProcessWorkingSetSize');

  void start() {
    if (_started || kDebugMode) return; // Debug 下引擎基线无意义，跳过
    _started = true;
    // 启动 90 秒后做一次首修剪（等首帧、图标、字体缓存稳定）。
    Timer(const Duration(seconds: 90), _trimIfHidden);
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _trimIfHidden());
  }

  /// 主窗口隐藏到托盘后调用；稍候片刻再修剪，让隐藏动画/消息排空。
  Future<void> notifyWindowHidden() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    trim();
  }

  void _trimIfHidden() {
    if (!windowVisible) trim();
  }

  /// 清空图像缓存并把工作集换出。
  void trim() {
    try {
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      cache.clearLiveImages();
    } catch (_) {}
    try {
      _setWorkingSetSize(_getCurrentProcess(), -1, -1);
    } catch (_) {}
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}
