/// 按两行 band 懒构建的 Metro 磁贴墙。
library;

import 'package:flutter/material.dart';

import 'metro_tile_layout.dart';

class MetroTileGrid extends StatelessWidget {
  const MetroTileGrid({
    required this.metrics,
    required this.bands,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    this.animationDuration = const Duration(milliseconds: 200),
    super.key,
  });

  final MetroGridMetrics metrics;
  final List<MetroTileBand> bands;
  final Widget Function(BuildContext context, int index, MetroTileSize size)
  itemBuilder;
  final EdgeInsets padding;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: bands.length,
      itemBuilder: (context, bandIndex) {
        final band = bands[bandIndex];
        return Padding(
          padding: EdgeInsets.only(
            bottom: bandIndex == bands.length - 1 ? 0 : MetroGridMetrics.gap,
          ),
          // band 高度随尺寸变化过渡，避免整行突然跳动。
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: metrics.bandHeight(band.rowCount)),
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            builder: (context, height, child) =>
                SizedBox(height: height, child: child),
            // 拉伸预览允许溢出 band，裁剪交给 ListView 视口。
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final tile in band.tiles)
                  AnimatedPositioned(
                    key: ValueKey<int>(tile.index),
                    duration: animationDuration,
                    curve: Curves.easeOutBack,
                    left: metrics.leftFor(tile.column),
                    top: metrics.topFor(tile.row),
                    width: metrics.widthFor(tile.size),
                    height: metrics.heightFor(tile.size),
                    child: itemBuilder(context, tile.index, tile.size),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
