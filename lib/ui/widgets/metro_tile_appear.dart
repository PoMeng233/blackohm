/// 磁贴入场动画：淡入 + 轻微上移 + 微缩放。
///
/// 整墙统一播放、不按序号错峰；动画结束后控制器静止，不保留持续 ticker。
library;

import 'package:flutter/material.dart';

import '../motion.dart';

/// 入场动画包裹层。
///
/// 控制器挂在 State 上：入场期间父级重建（流推送、主题变化）不会换掉
/// 子树、也不会打断动画——早先按构建期 Set 判定 `animate`，重建时包裹层
/// 直接被摘掉，磁贴会突然跳到全不透明，真实启动时表现为闪烁。
///
/// [animate] 只决定本次挂载是否播放；[scope] 变化（切换文件夹 / 搜索 /
/// 排序）时整墙统一重播一次，避免新视图直接砸到屏幕上。
class MetroTileAppear extends StatefulWidget {
  const MetroTileAppear({
    required this.animate,
    this.scope,
    required this.child,
    super.key,
  });

  final bool animate;

  /// 当前浏览范围的标识；变化即视为一次视图切换。
  final Object? scope;
  final Widget child;

  @override
  State<MetroTileAppear> createState() => _MetroTileAppearState();
}

class _MetroTileAppearState extends State<MetroTileAppear>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  CurvedAnimation? _progress;
  bool _reduceMotion = false;
  bool _resolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 减少动态只在挂载时读一次：之后即使开关被切换，也不补播。
    if (_resolved) return;
    _resolved = true;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.animate) _play();
  }

  @override
  void didUpdateWidget(covariant MetroTileAppear oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) _play();
  }

  void _play() {
    if (_reduceMotion) return;
    final controller = _controller ??= AnimationController(
      vsync: this,
      duration: AppMotion.appear,
    );
    _progress ??= CurvedAnimation(parent: controller, curve: AppMotion.curve);
    controller.forward(from: 0);
  }

  @override
  void dispose() {
    _progress?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (progress == null) return widget.child;
    return AnimatedBuilder(
      animation: progress,
      child: widget.child,
      builder: (context, child) {
        final value = progress.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: Transform.scale(scale: 0.985 + 0.015 * value, child: child),
          ),
        );
      },
    );
  }
}
