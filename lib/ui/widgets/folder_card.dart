/// 文件夹卡片：游戏库“全部游戏”网格中的分类入口与拖放目标。
library;

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../theme.dart';

class FolderCard extends StatelessWidget {
  const FolderCard({
    required this.folder,
    required this.gameCount,
    required this.totalPlaySeconds,
    required this.onOpen,
    required this.onMoveGame,
    required this.onShowMenu,
    super.key,
  });

  final GameFolder folder;
  final int gameCount;
  final int totalPlaySeconds;
  final VoidCallback onOpen;
  final ValueChanged<Game> onMoveGame;
  final GestureTapUpCallback onShowMenu;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DragTarget<Game>(
      onWillAcceptWithDetails: (details) => details.data.folderId != folder.id,
      onAcceptWithDetails: (details) => onMoveGame(details.data),
      builder: (context, candidates, rejected) {
        final isHovered = candidates.isNotEmpty;
        return GestureDetector(
          onTap: onOpen,
          onSecondaryTapUp: onShowMenu,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isHovered ? primary.withAlpha(28) : AppColors.surfaceHover,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isHovered ? primary : AppColors.textMuted.withAlpha(150),
                width: isHovered ? 2 : 1,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -28,
                  top: -26,
                  child: Icon(
                    Icons.folder_rounded,
                    size: 150,
                    color: primary.withAlpha(isHovered ? 48 : 26),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 42,
                        decoration: BoxDecoration(
                          color: primary.withAlpha(isHovered ? 48 : 28),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isHovered
                              ? Icons.move_to_inbox_rounded
                              : Icons.folder_special_rounded,
                          color: primary,
                          size: 25,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.videogame_asset_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$gameCount 款游戏',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            formatPlayDuration(totalPlaySeconds),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (folder.includeInTotalTime)
                            Tooltip(
                              message: '参与主页累计时长排行',
                              child: Icon(
                                Icons.timer_outlined,
                                size: 15,
                                color: primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isHovered ? '松开以移入文件夹' : '右键管理 · 拖入游戏',
                        style: TextStyle(
                          color: isHovered ? primary : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: isHovered ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
