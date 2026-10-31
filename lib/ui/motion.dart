/// 全应用统一的动效曲线与时长。
///
/// 参考 PMblog 的动效语言：长缓出曲线 + 轻微位移，避免回弹，
/// 让磁贴墙的重排与悬停看起来像同一套物理规则。
library;

import 'package:flutter/animation.dart';

abstract final class AppMotion {
  /// 主曲线：起步快、收尾极缓（PMblog 的 cubic-bezier(0.22, 1, 0.36, 1)）。
  static const curve = Cubic(0.22, 1, 0.36, 1);

  /// 入场：淡入 + 上移 + 微缩放。
  static const appear = Duration(milliseconds: 600);

  /// 入场错峰：按序号递增，最多叠加 7 步。
  static const staggerStep = Duration(milliseconds: 40);
  static const staggerMax = 7;

  static Duration staggerFor(int index) =>
      staggerStep * (index % (staggerMax + 1));

  /// 悬停抬升、描边、操作条等即时反馈。
  static const hover = Duration(milliseconds: 220);

  /// 封面缓慢推近，悬停时才有感知。
  static const cover = Duration(milliseconds: 1400);

  /// 磁贴重排 / band 高度过渡。
  static const reflow = Duration(milliseconds: 420);

  /// 拉伸预览浮层。
  static const ghost = Duration(milliseconds: 200);

  /// 按下反馈。
  static const press = Duration(milliseconds: 120);

  /// 操作条滑入与淡出。
  static const actions = Duration(milliseconds: 200);
}
