import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// 为无边框窗口提供透明的四边和四角缩放热区。
///
/// 不给内容增加 padding 或改变约束；最大化时将 [enabled] 设为 false，
/// 即可移除边缘命中层，同时保留内容状态。
class WindowResizeFrame extends StatelessWidget {
  const WindowResizeFrame({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  static const double resizeEdgeSize = 6;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (enabled)
          Positioned.fill(
            child: DragToResizeArea(
              resizeEdgeSize: resizeEdgeSize,
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
}
