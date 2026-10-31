/// Metro 磁贴：全幅封面/强调色块、尺寸相关排版、悬停操作与实时计时状态。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../features/background/background_service.dart';
import '../../features/tracking/tracking_engine.dart';
import '../../providers.dart';
import '../theme.dart';
import 'cover_file_image.dart';
import 'game_icon.dart';
import 'metro_tile_layout.dart';

class GameCard extends ConsumerStatefulWidget {
  const GameCard({
    required this.game,
    required this.onLaunch,
    required this.onOpenDirectory,
    required this.onOpenDetail,
    required this.onDelete,
    required this.onToggleFavorite,
    this.tileSize = MetroTileSize.small,
    super.key,
  });

  final Game game;
  final VoidCallback onLaunch;
  final VoidCallback onOpenDirectory;
  final VoidCallback onOpenDetail;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final MetroTileSize tileSize;

  @override
  ConsumerState<GameCard> createState() => _GameCardState();
}

class _GameCardState extends ConsumerState<GameCard> {
  bool _hovering = false;
  bool _focused = false;
  bool _pressed = false;

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
        isCurrentDetailBackground(detailPath) &&
        detailPath != null &&
        File(detailPath).existsSync();
    final size = widget.tileSize;
    final scheme = Theme.of(context).colorScheme;
    final showActions = _hovering || _focused;
    final padding = switch (size) {
      MetroTileSize.small => 12.0,
      MetroTileSize.wide => 14.0,
      MetroTileSize.large => 18.0,
    };
    final iconSize = switch (size) {
      MetroTileSize.small => 40.0,
      MetroTileSize.wide => 48.0,
      MetroTileSize.large => 64.0,
    };
    final titleStyle = switch (size) {
      MetroTileSize.small => const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      MetroTileSize.wide => const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
      MetroTileSize.large => const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w300,
        height: 1.15,
      ),
    };
    final titleMaxLines = size == MetroTileSize.small ? 1 : 2;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = ((size == MetroTileSize.large ? 460 : 360) * dpr)
        .round()
        .clamp(1, 960);
    final cacheHeight = ((size == MetroTileSize.large ? 460 : 360) * dpr)
        .round()
        .clamp(1, 960);
    final hasImageLayer = hasBackground || hasBlurBackground;
    // 无封面磁贴铺强调色底，灰色元信息在绿底上对比度不足。
    final metaColor = hasImageLayer
        ? AppColors.textSecondary
        : Colors.white.withAlpha(200);

    return Semantics(
      button: true,
      label:
          '${widget.game.title}，累计 ${formatPlayDuration(widget.game.totalPlaySeconds)}',
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) {
          if (value != _focused) setState(() => _focused = value);
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onOpenDetail();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            onTap: widget.onOpenDetail,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onSecondaryTapUp: (details) => _showContextMenu(context, details),
            child: AnimatedScale(
              scale: _pressed ? 0.985 : 1,
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOutCubic,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: hasImageLayer
                      ? AppColors.surface
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasBackground)
                      Positioned.fill(
                        child: CoverFileImage(
                          file: backgroundFile,
                          cacheWidth: cacheWidth,
                          cacheHeight: cacheHeight,
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
                          child: CoverFileImage(
                            file: File(detailPath),
                            cacheWidth: cacheWidth,
                            cacheHeight: cacheHeight,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    if (!hasImageLayer)
                      Positioned(
                        right: -18,
                        bottom: -22,
                        child: Icon(
                          Icons.videogame_asset_rounded,
                          size: size == MetroTileSize.large ? 168 : 112,
                          color: scheme.primary.withAlpha(22),
                        ),
                      ),
                    if (hasImageLayer)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0x330D0F12),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x1A0D0F12), Color(0xF20D0F12)],
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: showActions ? 1 : 0,
                        duration: const Duration(milliseconds: 120),
                        child: ColoredBox(
                          color: scheme.onSurface.withAlpha(18),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GameIcon(
                                gameId: widget.game.id,
                                size: iconSize,
                                radius: 6,
                                iconSize: iconSize * 0.55,
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (widget.game.favorite)
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Colors.amber,
                                      size: 17,
                                    ),
                                  if (isActive)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: widget.game.favorite ? 5 : 0,
                                      ),
                                      child: _StopwatchPill(
                                        color: trackingColor,
                                        activeState: activeState,
                                        inputIdle: isInputIdle,
                                        compact: size == MetroTileSize.small,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            widget.game.title,
                            maxLines: titleMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: metaColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  formatCompactPlayDuration(
                                    widget.game.totalPlaySeconds,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: metaColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (widget.game.useLocaleEmulator) ...[
                                const SizedBox(width: 6),
                                _MicroBadge(
                                  label: 'LE',
                                  color: context.secondaryInteractiveColor,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: padding - 4,
                      bottom: padding - 4,
                      child: AnimatedOpacity(
                        opacity: showActions ? 1 : 0,
                        duration: const Duration(milliseconds: 120),
                        child: IgnorePointer(
                          ignoring: !showActions,
                          child: _TileActions(
                            onLaunch: widget.onLaunch,
                            onOpenDirectory: widget.onOpenDirectory,
                          ),
                        ),
                      ),
                    ),
                    if (isActive)
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        child: _PulsingBar(color: trackingColor),
                      ),
                    if (_focused)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: scheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
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

class _StopwatchPill extends StatelessWidget {
  const _StopwatchPill({
    required this.color,
    required this.activeState,
    required this.inputIdle,
    required this.compact,
  });

  final Color color;
  final TrackingPublicState activeState;
  final bool inputIdle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            inputIdle
                ? (compact ? '暂停' : '无操作已暂停')
                : formatStopwatch(activeState.elapsedMs),
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _MicroBadge extends StatelessWidget {
  const _MicroBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TileActions extends StatelessWidget {
  const _TileActions({required this.onLaunch, required this.onOpenDirectory});

  final VoidCallback onLaunch;
  final VoidCallback onOpenDirectory;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(150),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TileAction(
            tooltip: '运行文件',
            icon: Icons.play_arrow_rounded,
            color: Theme.of(context).colorScheme.primary,
            onPressed: onLaunch,
          ),
          _TileAction(
            tooltip: '打开游戏目录',
            icon: Icons.folder_open_rounded,
            color: AppColors.textSecondary,
            onPressed: onOpenDirectory,
          ),
        ],
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  const _TileAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 16,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _PulsingBar extends StatefulWidget {
  const _PulsingBar({required this.color});

  final Color color;

  @override
  State<_PulsingBar> createState() => _PulsingBarState();
}

class _PulsingBarState extends State<_PulsingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.35,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SizedBox(height: 3, child: ColoredBox(color: widget.color)),
    );
  }
}
