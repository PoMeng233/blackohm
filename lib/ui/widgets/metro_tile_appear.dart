/// 磁贴入场动画：淡入 + 轻微上移 + 微缩放。
///
/// 只在磁贴首次出现时播放一次，滚动复用不重播；
/// 使用隐式动画实现，settle 后不保留 ticker。
library;

import 'package:flutter/material.dart';

import '../motion.dart';

class MetroTileAppear extends StatelessWidget {
  const MetroTileAppear({
    required this.animate,
    this.delay = Duration.zero,
    required this.child,
    super.key,
  });

  final bool animate;
  final Duration delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate || MediaQuery.disableAnimationsOf(context)) return child;

    final total = AppMotion.appear + delay;
    final begin = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Interval(begin, 1, curve: AppMotion.curve),
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: Transform.scale(scale: 0.985 + 0.015 * value, child: child),
        ),
      ),
    );
  }
}
