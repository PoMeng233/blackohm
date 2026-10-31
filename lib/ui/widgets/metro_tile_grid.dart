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
    super.key,
  });

  final MetroGridMetrics metrics;
  final List<MetroTileBand> bands;
  final Widget Function(BuildContext context, int index, MetroTileSize size)
  itemBuilder;
  final EdgeInsets padding;

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
          child: SizedBox(
            height: metrics.bandHeight(band.rowCount),
            child: Stack(
              children: [
                for (final tile in band.tiles)
                  Positioned(
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
