/// 文件夹磁贴：Metro 风格的分类入口，同时保留拖放目标能力。
library;

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../theme.dart';
import 'metro_tile_layout.dart';

class FolderCard extends StatefulWidget {
  const FolderCard({
    required this.folder,
    required this.gameCount,
    required this.totalPlaySeconds,
    required this.onOpen,
    required this.onMoveGame,
    required this.onShowMenu,
    this.tileSize = MetroTileSize.wide,
    super.key,
  });

  final GameFolder folder;
  final int gameCount;
  final int totalPlaySeconds;
  final VoidCallback onOpen;
  final ValueChanged<Game> onMoveGame;
  final GestureTapUpCallback onShowMenu;
  final MetroTileSize tileSize;

  @override
  State<FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<FolderCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isLarge = widget.tileSize == MetroTileSize.large;
    final isSmall = widget.tileSize == MetroTileSize.small;
    final iconSize = isLarge ? 44.0 : (isSmall ? 28.0 : 34.0);
    final padding = isLarge ? 18.0 : (isSmall ? 12.0 : 14.0);
    return DragTarget<Game>(
      onWillAcceptWithDetails: (details) =>
          details.data.folderId != widget.folder.id,
      onAcceptWithDetails: (details) => widget.onMoveGame(details.data),
      builder: (context, candidates, rejected) {
        final dragHover = candidates.isNotEmpty;
        return Semantics(
          button: true,
          label: '文件夹 ${widget.folder.name}，${widget.gameCount} 款游戏',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: GestureDetector(
              onTap: widget.onOpen,
              onSecondaryTapUp: widget.onShowMenu,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: dragHover
                      ? primary.withAlpha(30)
                      : (_hovering
                            ? AppColors.surfaceActive
                            : AppColors.surfaceHover),
                  borderRadius: BorderRadius.circular(8),
                  border: dragHover
                      ? Border.all(color: primary, width: 2)
                      : null,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -22,
                      bottom: -26,
                      child: Icon(
                        Icons.folder_rounded,
                        size: isLarge ? 168 : 128,
                        color: primary.withAlpha(dragHover ? 42 : 22),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                dragHover
                                    ? Icons.move_to_inbox_rounded
                                    : Icons.folder_rounded,
                                color: primary,
                                size: iconSize,
                              ),
                              const Spacer(),
                              if (dragHover)
                                Text(
                                  '移入',
                                  style: TextStyle(
                                    color: primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            widget.folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: isLarge ? 20 : 15,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${widget.gameCount} 款',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                formatCompactPlayDuration(
                                  widget.totalPlaySeconds,
                                ),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          if (!isSmall) ...[
                            const SizedBox(height: 4),
                            Text(
                              dragHover ? '松开以移入文件夹' : '右键管理 · 拖入游戏',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: dragHover
                                    ? primary
                                    : AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: dragHover ? FontWeight.w600 : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
