/// 游戏卡片组件：支持封面/图标展示、前台活跃呼吸光效、实时秒表与右键菜单。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../features/tracking/tracking_engine.dart';
import '../../providers.dart';
import '../theme.dart';
import 'active_record_frame.dart';
import 'game_icon.dart';

class GameCard extends ConsumerStatefulWidget {
  const GameCard({
    required this.game,
    required this.onLaunch,
    required this.onOpenDirectory,
    required this.onOpenDetail,
    required this.onDelete,
    required this.onToggleFavorite,
    super.key,
  });

  final Game game;
  final VoidCallback onLaunch;
  final VoidCallback onOpenDirectory;
  final VoidCallback onOpenDetail;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  @override
  ConsumerState<GameCard> createState() => _GameCardState();
}

class _GameCardState extends ConsumerState<GameCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final activeState = ref.watch(
      trackingStateProvider.select((value) {
        final state = value.valueOrNull;
        return state != null && state.gameId == widget.game.id
            ? state
            : TrackingPublicState.idle;
      }),
    );
    final isActive = activeState.isActive;
    final isLive = activeState.phase == TrackingPhase.live;
    final isGrace = activeState.phase == TrackingPhase.grace;
    final isInputIdle = activeState.phase == TrackingPhase.inputIdle;
    final trackingColor = isGrace
        ? AppColors.error
        : (isInputIdle ? AppColors.textSecondary : context.interactiveColor);
    final backgroundPath = widget.game.backgroundPath;
    final backgroundFile = backgroundPath == null || backgroundPath.isEmpty
        ? null
        : File(backgroundPath);
    final hasBackground = backgroundFile != null && backgroundFile.existsSync();
    final detailPath = widget.game.detailBackgroundPath;
    final hasBlurBackground =
        widget.game.backgroundBlurAmount > 0 &&
        detailPath != null &&
        File(detailPath).existsSync();
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onOpenDetail,
        onSecondaryTapUp: (details) => _showContextMenu(context, details),
        child: ActiveRecordFrame(
          active: isLive,
          color: trackingColor,
          radius: 10,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _hovering ? AppColors.surfaceHover : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isGrace
                        ? AppColors.error
                        : (isActive
                              ? context.interactiveColor
                              : (widget.game.favorite
                                    ? const Color(0xFFFFC857)
                                    : (_hovering
                                          ? AppColors.border
                                          : Colors.transparent))),
                    width: isActive || isGrace || widget.game.favorite
                        ? 1.5
                        : 1,
                  ),
                  boxShadow: widget.game.favorite
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFC857).withAlpha(38),
                            blurRadius: 9,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasBackground)
                      Positioned.fill(
                        child: Image.file(
                          backgroundFile,
                          fit: BoxFit.cover,
                          cacheWidth: 360,
                          cacheHeight: 380,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    if (hasBlurBackground)
                      Positioned.fill(
                        child: Opacity(
                          opacity: widget.game.backgroundBlurAmount.clamp(
                            0.0,
                            1.0,
                          ),
                          child: Image.file(
                            File(detailPath),
                            fit: BoxFit.cover,
                            cacheWidth: 360,
                            cacheHeight: 380,
                            filterQuality: FilterQuality.low,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    if (hasBackground)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(90),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x330D0F12), Color(0xF20D0F12)],
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: GameIcon(
                                gameId: widget.game.id,
                                size: 64,
                                radius: 8,
                                iconSize: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.game.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (isActive) ...[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: trackingColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isInputIdle
                                      ? '无操作已暂停'
                                      : formatStopwatch(activeState.elapsedMs),
                                  style: TextStyle(
                                    color: trackingColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgDark.withAlpha(135),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.border.withAlpha(130),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.schedule,
                                        size: 12,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        formatCompactPlayDuration(
                                          widget.game.totalPlaySeconds,
                                        ),
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (widget.game.useLocaleEmulator)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.secondaryInteractiveColor
                                        .withAlpha(40),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'LE',
                                    style: TextStyle(
                                      color: context.secondaryInteractiveColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (widget.game.favorite)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 13,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: '运行文件',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.play_arrow_rounded,
                                  color: context.interactiveColor,
                                  size: 18,
                                ),
                                onPressed: widget.onLaunch,
                              ),
                              IconButton(
                                tooltip: '打开游戏目录',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.folder_open_rounded,
                                  color: AppColors.textSecondary,
                                  size: 17,
                                ),
                                onPressed: widget.onOpenDirectory,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, TapUpDetails details) {
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final offset = overlay.globalToLocal(details.globalPosition);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(offset.dx, offset.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      color: AppColors.surfaceActive,
      items: [
        PopupMenuItem(
          value: 'launch',
          child: Row(
            children: [
              Icon(Icons.play_arrow, color: context.interactiveColor, size: 18),
              const SizedBox(width: 8),
              Text(widget.game.useLocaleEmulator ? '经 LE 启动' : '直接启动'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'fav',
          child: Row(
            children: [
              Icon(
                widget.game.favorite ? Icons.star_border : Icons.star,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(widget.game.favorite ? '取消收藏' : '加入收藏'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'detail',
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18),
              SizedBox(width: 8),
              Text('游戏详情与历史'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: AppColors.error, size: 18),
              SizedBox(width: 8),
              Text('从库中移除', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    ).then((v) {
      switch (v) {
        case 'launch':
          widget.onLaunch();
        case 'fav':
          widget.onToggleFavorite();
        case 'detail':
          widget.onOpenDetail();
        case 'delete':
          widget.onDelete();
      }
    });
  }
}
