/// 全窗口拖拽捕获层：桌面拖入文件夹/exe 时展示高亮边框动效。
library;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

class DropOverlay extends StatefulWidget {
  const DropOverlay({required this.child, required this.onDropped, super.key});

  final Widget child;
  final ValueChanged<List<String>> onDropped;

  @override
  State<DropOverlay> createState() => _DropOverlayState();
}

class _DropOverlayState extends State<DropOverlay> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        final paths = details.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) widget.onDropped(paths);
      },
      child: Stack(
        children: [
          widget.child,
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.interactiveColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.interactiveColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceActive,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.interactiveColor),
                        boxShadow: [
                          BoxShadow(
                            color: context.interactiveColor.withAlpha(100),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.drive_folder_upload,
                            color: context.interactiveColor,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Text(
                            '释放以扫描并加入游戏库',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
