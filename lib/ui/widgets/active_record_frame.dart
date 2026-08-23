/// 仅为当前前台记录游戏绘制的轻量主题色环绕指示。
///
/// 性能设计：
///   * 保持 30fps 动画流畅度，但用 ValueNotifier 驱动 CustomPainter 重绘，
///     而不是每帧 setState 重建整个卡片子树（避免暂停/继续时的 CPU 峰值）；
///   * 圆角路径度量按尺寸缓存，跨帧复用，避免每帧 computeMetrics；
///   * 描边内缩半个线宽，使光效弧线与卡片 BoxDecoration 圆角精确贴合；
///   * 主窗口隐藏到托盘时自动暂停计时器，空闲零 CPU。
library;

import 'dart:async';
import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class ActiveRecordFrame extends ConsumerStatefulWidget {
  const ActiveRecordFrame({
    required this.active,
    required this.color,
    required this.child,
    this.radius = 10,
    super.key,
  });

  final bool active;
  final Color color;
  final Widget child;
  final double radius;

  @override
  ConsumerState<ActiveRecordFrame> createState() => _ActiveRecordFrameState();
}

class _ActiveRecordFrameState extends ConsumerState<ActiveRecordFrame> {
  static const _cycleMs = 2800;
  static const _tickMs = 33; // ~30fps，保持流畅

  Timer? _timer;
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    ref.listenManual(windowVisibleProvider, (_, _) => _syncTimer());
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant ActiveRecordFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _progress.dispose();
    super.dispose();
  }

  bool get _shouldRun => widget.active && ref.read(windowVisibleProvider);

  void _syncTimer() {
    if (_shouldRun) {
      // 只推进进度，不 setState：CustomPaint 通过 repaint 监听重绘，
      // 卡片子树不会每帧重建。
      _timer ??= Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
        var next = _progress.value + _tickMs / _cycleMs;
        if (next >= 1) next -= 1;
        _progress.value = next;
      });
      return;
    }
    _timer?.cancel();
    _timer = null;
    if (!widget.active && _progress.value != 0) _progress.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    // passthrough + Positioned.fill：光效层跟随子组件实际尺寸。
    // 不能用 StackFit.expand —— 列表视图行处于无界高度约束下，
    // expand 会把子组件强制拉伸到无限高导致整棵子树布局崩溃（灰屏）。
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ActiveRecordPainter(
                  progress: _progress,
                  color: widget.color,
                  radius: widget.radius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRecordPainter extends CustomPainter {
  _ActiveRecordPainter({
    required this.progress,
    required this.color,
    required this.radius,
  }) : super(repaint: progress);

  final ValueListenable<double> progress;
  final Color color;
  final double radius;

  /// 路径度量缓存：卡片尺寸在会话期内恒定，跨帧复用消除逐帧几何计算。
  static final Map<String, PathMetric> _metricCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.0;
    // 内缩半个线宽：描边整体落在组件边界内，外沿与卡片圆角边框重合。
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final key =
        '${size.width.round()}x${size.height.round()}'
        'r${radius.toStringAsFixed(1)}';
    var metric = _metricCache[key];
    if (metric == null) {
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
      metric = path.computeMetrics().first;
      if (_metricCache.length > 16) _metricCache.clear();
      _metricCache[key] = metric;
    }
    final length = metric.length;
    final start = progress.value * length;
    const segmentFraction = 0.18;
    final segmentLength = length * segmentFraction;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    void drawSegment(double from, double to) {
      canvas.drawPath(metric!.extractPath(from, to), paint);
    }

    if (start + segmentLength <= length) {
      drawSegment(start, start + segmentLength);
    } else {
      drawSegment(start, length);
      drawSegment(0, start + segmentLength - length);
    }
  }

  @override
  bool shouldRepaint(covariant _ActiveRecordPainter oldDelegate) =>
      oldDelegate.progress.value != progress.value ||
      oldDelegate.color != color ||
      oldDelegate.radius != radius;
}
