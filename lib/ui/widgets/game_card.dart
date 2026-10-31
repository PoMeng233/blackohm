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
    this.onResize,
    this.tileSize = MetroTileSize.small,
    super.key,
  });

  final Game game;
  final VoidCallback onLaunch;
  final VoidCallback onOpenDirectory;
  final VoidCallback onOpenDetail;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  /// 提交手动尺寸；传 null 表示恢复自动尺寸。
  final ValueChanged<MetroTileSize?>? onResize;
  final MetroTileSize tileSize;

  @override
  ConsumerState<GameCard> createState() => _GameCardState();
}

enum _ResizeEdge { right, bottom, corner }

class _GameCardState extends ConsumerState<GameCard> {
  bool _hovering = false;
  bool _focused = false;
  bool _pressed = false;
  MetroTileSize? _resizeStart;
  MetroTileSize? _resizeTarget;
  Offset _resizeDelta = Offset.zero;
  _ResizeEdge? _hoverEdge;
  final LayerLink _resizeLink = LayerLink();
  final OverlayPortalController _resizeOverlay = OverlayPortalController();

  @override
  void didUpdateWidget(covariant GameCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tileSize != oldWidget.tileSize) {
      _resizeStart = null;
      _resizeTarget = null;
      _resizeDelta = Offset.zero;
      if (_resizeOverlay.isShowing) {
        // show/hide 不允许在 build/布局阶段调用，延后到本帧结束。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _resizeOverlay.isShowing) _resizeOverlay.hide();
        });
      }
    }
  }

  void _beginResize() {
    setState(() {
      _resizeStart = widget.tileSize;
      _resizeTarget = null;
      _resizeDelta = Offset.zero;
    });
  }

  void _updateResize(DragUpdateDetails details, _ResizeEdge edge) {
    final start = _resizeStart;
    if (start == null) return;
    _resizeDelta += details.delta;
    final extent = context.size?.shortestSide ?? 180;
    final target = resolveResizeTarget(
      start: start,
      dx: edge == _ResizeEdge.bottom ? 0 : _resizeDelta.dx,
      dy: edge == _ResizeEdge.right ? 0 : _resizeDelta.dy,
      extent: extent,
    );
    if (target == _resizeTarget) return;
    setState(() => _resizeTarget = target);
    // 目标尺寸仍未跨格时不显示落位框，避免贴着原磁贴画一圈无用边框。
    final showGhost = target != start;
    if (showGhost != _resizeOverlay.isShowing) {
      showGhost ? _resizeOverlay.show() : _resizeOverlay.hide();
    }
  }

  void _endResize() {
    final target = _resizeTarget;
    final start = _resizeStart;
    if (_resizeOverlay.isShowing) _resizeOverlay.hide();
    setState(() {
      _resizeStart = null;
      _resizeDelta = Offset.zero;
      _resizeTarget = null;
    });
    if (target != null && start != null && target != start) {
      widget.onResize?.call(target);
    }
  }

  /// 由当前跨格尺寸反推单元格尺寸，得到目标尺寸在网格里的真实占位。
  double _spanExtent(double currentExtent, int startSpan, int targetSpan) {
    final cell =
        (currentExtent - (startSpan - 1) * MetroGridMetrics.gap) / startSpan;
    return targetSpan * cell + (targetSpan - 1) * MetroGridMetrics.gap;
  }

  String _sizeBadgeLabel(MetroTileSize size) => switch (size) {
    MetroTileSize.small => '小 1×1',
    MetroTileSize.wide => '宽 2×1',
    MetroTileSize.tall => '竖 1×2',
    MetroTileSize.large => '大 2×2',
  };

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
      MetroTileSize.tall => 14.0,
      MetroTileSize.large => 18.0,
    };
    final iconSize = switch (size) {
      MetroTileSize.small => 40.0,
      MetroTileSize.wide => 48.0,
      MetroTileSize.tall => 44.0,
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
      MetroTileSize.tall => const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15.5,
        fontWeight: FontWeight.w500,
        height: 1.25,
      ),
      MetroTileSize.large => const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w300,
        height: 1.15,
      ),
    };
    final titleMaxLines = switch (size) {
      MetroTileSize.small => 1,
      MetroTileSize.tall => 3,
      MetroTileSize.wide || MetroTileSize.large => 2,
    };
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final showRightEdge =
        _hoverEdge == _ResizeEdge.right ||
        _hoverEdge == _ResizeEdge.corner ||
        _resizeTarget != null;
    final showBottomEdge =
        _hoverEdge == _ResizeEdge.bottom ||
        _hoverEdge == _ResizeEdge.corner ||
        _resizeTarget != null;
    final hasImageLayer = hasBackground || hasBlurBackground;
    // 无封面磁贴铺强调色底，灰色元信息在绿底上对比度不足。
    final metaColor = hasImageLayer
        ? AppColors.textSecondary
        : Colors.white.withAlpha(200);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 解码尺寸跟随磁贴实际物理像素，避免为大图常驻过量位图缓存。
        final cacheWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * dpr).round().clamp(1, 1024)
            : 360;
        final cacheHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight * dpr).round().clamp(1, 1024)
            : 360;
        final resizeTarget = _resizeTarget;
        final resizeStart = _resizeStart;
        final ghostWidth = resizeTarget == null || resizeStart == null
            ? 0.0
            : _spanExtent(
                constraints.maxWidth,
                resizeStart.columnSpan,
                resizeTarget.columnSpan,
              );
        final ghostHeight = resizeTarget == null || resizeStart == null
            ? 0.0
            : _spanExtent(
                constraints.maxHeight,
                resizeStart.rowSpan,
                resizeTarget.rowSpan,
              );
        return OverlayPortal(
          controller: _resizeOverlay,
          // 落位框画在 Overlay 里，拉伸预览不会被相邻磁贴盖住。
          overlayChildBuilder: (overlayContext) => Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: _resizeLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topLeft,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutBack,
                  width: ghostWidth,
                  height: ghostHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(38),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                  child: resizeTarget == null
                      ? null
                      : _ResizeGhostLabel(label: _sizeBadgeLabel(resizeTarget)),
                ),
              ),
            ),
          ),
          child: Semantics(
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
                  onSecondaryTapUp: (details) =>
                      _showContextMenu(context, details),
                  child: AnimatedScale(
                    scale: _pressed ? 0.985 : 1,
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOutCubic,
                    child: CompositedTransformTarget(
                      link: _resizeLink,
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
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            if (hasBlurBackground)
                              Positioned.fill(
                                child: Opacity(
                                  opacity: widget.game.backgroundBlurAmount
                                      .clamp(0.0, 1.0),
                                  child: CoverFileImage(
                                    file: File(detailPath),
                                    cacheWidth: cacheWidth,
                                    cacheHeight: cacheHeight,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            if (!hasImageLayer)
                              Positioned(
                                right: -18,
                                bottom: -22,
                                child: Icon(
                                  Icons.videogame_asset_rounded,
                                  size: switch (size) {
                                    MetroTileSize.small => 112,
                                    MetroTileSize.wide => 112,
                                    MetroTileSize.tall => 144,
                                    MetroTileSize.large => 168,
                                  },
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
                                      colors: [
                                        Color(0x1A0D0F12),
                                        Color(0xF20D0F12),
                                      ],
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GameIcon(
                                        gameId: widget.game.id,
                                        size: iconSize,
                                        radius: 6,
                                        iconSize: iconSize * 0.55,
                                      ),
                                      const Spacer(),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
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
                                                top: widget.game.favorite
                                                    ? 5
                                                    : 0,
                                              ),
                                              child: _StopwatchPill(
                                                color: trackingColor,
                                                activeState: activeState,
                                                inputIdle: isInputIdle,
                                                compact:
                                                    size ==
                                                        MetroTileSize.small ||
                                                    size == MetroTileSize.tall,
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
                                          color:
                                              context.secondaryInteractiveColor,
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
                            if (widget.onResize != null) ...[
                              // 高光槽位固定存在，避免拖拽中插入/移除子节点导致
                              // 手势识别器被重建、丢失 pointer-up。
                              Positioned(
                                top: 8,
                                right: 0,
                                bottom: 12,
                                child: IgnorePointer(
                                  child: AnimatedOpacity(
                                    opacity: showRightEdge ? 1 : 0,
                                    duration: const Duration(milliseconds: 120),
                                    child: Container(
                                      width: 2,
                                      decoration: BoxDecoration(
                                        color: context.interactiveColor
                                            .withAlpha(190),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                right: 12,
                                bottom: 0,
                                child: IgnorePointer(
                                  child: AnimatedOpacity(
                                    opacity: showBottomEdge ? 1 : 0,
                                    duration: const Duration(milliseconds: 120),
                                    child: Container(
                                      height: 2,
                                      decoration: BoxDecoration(
                                        color: context.interactiveColor
                                            .withAlpha(190),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                bottom: 10,
                                width: 8,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeLeftRight,
                                  onEnter: (_) => setState(
                                    () => _hoverEdge = _ResizeEdge.right,
                                  ),
                                  onExit: (_) => setState(() {
                                    if (_hoverEdge == _ResizeEdge.right) {
                                      _hoverEdge = null;
                                    }
                                  }),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {},
                                    onPanStart: (_) => _beginResize(),
                                    onPanUpdate: (details) => _updateResize(
                                      details,
                                      _ResizeEdge.right,
                                    ),
                                    onPanEnd: (_) => _endResize(),
                                    onPanCancel: _endResize,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 10,
                                bottom: 0,
                                height: 8,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeUpDown,
                                  onEnter: (_) => setState(
                                    () => _hoverEdge = _ResizeEdge.bottom,
                                  ),
                                  onExit: (_) => setState(() {
                                    if (_hoverEdge == _ResizeEdge.bottom) {
                                      _hoverEdge = null;
                                    }
                                  }),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {},
                                    onPanStart: (_) => _beginResize(),
                                    onPanUpdate: (details) => _updateResize(
                                      details,
                                      _ResizeEdge.bottom,
                                    ),
                                    onPanEnd: (_) => _endResize(),
                                    onPanCancel: _endResize,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                width: 10,
                                height: 10,
                                child: MouseRegion(
                                  cursor:
                                      SystemMouseCursors.resizeUpLeftDownRight,
                                  onEnter: (_) => setState(
                                    () => _hoverEdge = _ResizeEdge.corner,
                                  ),
                                  onExit: (_) => setState(() {
                                    if (_hoverEdge == _ResizeEdge.corner) {
                                      _hoverEdge = null;
                                    }
                                  }),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {},
                                    onPanStart: (_) => _beginResize(),
                                    onPanUpdate: (details) => _updateResize(
                                      details,
                                      _ResizeEdge.corner,
                                    ),
                                    onPanEnd: (_) => _endResize(),
                                    onPanCancel: _endResize,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showContextMenu(BuildContext context, TapUpDetails details) {
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final offset = overlay.globalToLocal(details.globalPosition);
    final manualCode = widget.game.tileSize;
    final scheme = Theme.of(context).colorScheme;
    PopupMenuItem<String> sizeItem(int code, String label, IconData icon) {
      final selected = manualCode == code;
      return PopupMenuItem<String>(
        value: 'size:$code',
        height: 40,
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? scheme.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? scheme.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 16, color: scheme.primary),
          ],
        ),
      );
    }

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
        if (widget.onResize != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            enabled: false,
            height: 30,
            child: Text(
              '磁贴尺寸',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          sizeItem(0, '自动（随列数调整）', Icons.auto_awesome_rounded),
          sizeItem(1, '小 1×1', Icons.crop_square_rounded),
          sizeItem(2, '宽 2×1', Icons.crop_landscape_rounded),
          sizeItem(3, '竖 1×2', Icons.crop_portrait_rounded),
          sizeItem(4, '大 2×2', Icons.fullscreen_rounded),
        ],
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
        default:
          if (v != null && v.startsWith('size:')) {
            final code = int.tryParse(v.substring(5)) ?? 0;
            widget.onResize?.call(metroTileSizeFromCode(code));
          }
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

class _ResizeGhostLabel extends StatelessWidget {
  const _ResizeGhostLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(185),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
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
