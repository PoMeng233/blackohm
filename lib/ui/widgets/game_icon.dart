/// 游戏图标：按 gameId 惰性加载 PNG 字节（列表查询不再携带 blob）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../theme.dart';

class GameIcon extends ConsumerWidget {
  const GameIcon({
    required this.gameId,
    required this.size,
    this.radius = 8,
    this.iconSize,
    this.boxed = true,
    this.fallbackIcon = Icons.videogame_asset,
    super.key,
  });

  final int gameId;
  final double size;
  final double radius;
  final double? iconSize;
  final bool boxed;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(gameIconProvider(gameId)).valueOrNull;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          cacheWidth: (size * 2).round(),
          cacheHeight: (size * 2).round(),
          fit: BoxFit.contain,
        ),
      );
    }
    if (!boxed) {
      return Icon(fallbackIcon, color: AppColors.textMuted, size: iconSize ?? size);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceActive,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        fallbackIcon,
        color: AppColors.textMuted,
        size: iconSize ?? size * 0.5,
      ),
    );
  }
}
