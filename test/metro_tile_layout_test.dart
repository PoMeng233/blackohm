import 'package:blackohm/ui/widgets/metro_tile_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MetroGridMetrics', () {
    test('列数取偶数并限制在 4 到 10 列', () {
      expect(MetroGridMetrics.forWidth(0).columns, 4);
      expect(MetroGridMetrics.forWidth(688).columns, 4);
      expect(MetroGridMetrics.forWidth(968).columns, 6);
      expect(MetroGridMetrics.forWidth(1320).columns, 6);
      expect(MetroGridMetrics.forWidth(1808).columns, 10);
      expect(MetroGridMetrics.forWidth(2400).columns, 10);
      for (final width in [300.0, 688.0, 968.0, 1320.0, 1808.0, 2400.0]) {
        expect(MetroGridMetrics.forWidth(width).columns.isEven, isTrue);
      }
    });

    test('格宽填满内容区，跨格尺寸包含内部间距', () {
      const gap = 12.0;
      final metrics = MetroGridMetrics.forWidth(968);
      expect(metrics.columns, 6);
      expect(metrics.tileExtent, closeTo((968 - gap * 5) / 6, 0.001));
      expect(
        metrics.widthFor(MetroTileSize.wide),
        closeTo(metrics.tileExtent * 2 + gap, 0.001),
      );
      expect(
        metrics.heightFor(MetroTileSize.large),
        closeTo(metrics.tileExtent * 2 + gap, 0.001),
      );
      expect(
        metrics.widthFor(MetroTileSize.small),
        closeTo(metrics.tileExtent, 0.001),
      );
    });
  });

  group('assignMetroTileSizes', () {
    test('收藏且有封面的游戏优先成为大方砖', () {
      final sizes = assignMetroTileSizes(const [
        MetroTileSizeInput(hasCover: true, favorite: false),
        MetroTileSizeInput(hasCover: true, favorite: true),
        MetroTileSizeInput(hasCover: true, favorite: false),
        MetroTileSizeInput(hasCover: false, favorite: false),
        MetroTileSizeInput(hasCover: true, favorite: false),
        MetroTileSizeInput(hasCover: true, favorite: false),
      ]);
      expect(sizes[1], MetroTileSize.large);
      expect(sizes[0], isNot(MetroTileSize.large));
    });

    test('无封面游戏保持小砖，大砖数量受上限约束', () {
      final items = List.generate(
        20,
        (i) => MetroTileSizeInput(hasCover: i.isEven, favorite: i.isEven),
      );
      final sizes = assignMetroTileSizes(items);
      final largeCount = sizes.where((s) => s == MetroTileSize.large).length;
      expect(largeCount, (20 * 0.18).round());
      for (var i = 0; i < sizes.length; i++) {
        if (!items[i].hasCover) {
          expect(sizes[i], MetroTileSize.small);
        }
      }
    });

    test('空列表返回空结果', () {
      expect(assignMetroTileSizes(const []), isEmpty);
    });
  });

  group('packMetroBands', () {
    test('磁贴不重叠、不越界，且大砖完整落在同一 band', () {
      const columns = 5;
      const sizes = [
        MetroTileSize.large,
        MetroTileSize.wide,
        MetroTileSize.small,
        MetroTileSize.small,
        MetroTileSize.wide,
        MetroTileSize.small,
        MetroTileSize.large,
        MetroTileSize.small,
        MetroTileSize.wide,
        MetroTileSize.small,
        MetroTileSize.small,
        MetroTileSize.large,
      ];
      final bands = packMetroBands(sizes, columns);
      final seen = <int>{};
      for (final band in bands) {
        expect(band.rowCount, inInclusiveRange(1, 2));
        final occupied = List.generate(
          band.rowCount,
          (_) => List.filled(columns, false),
        );
        for (final tile in band.tiles) {
          expect(seen.add(tile.index), isTrue);
          final spanColumns = tile.size.columnSpan;
          final spanRows = tile.size.rowSpan;
          expect(tile.column + spanColumns, lessThanOrEqualTo(columns));
          expect(tile.row + spanRows, lessThanOrEqualTo(band.rowCount));
          for (var r = tile.row; r < tile.row + spanRows; r++) {
            for (var c = tile.column; c < tile.column + spanColumns; c++) {
              expect(occupied[r][c], isFalse, reason: '磁贴 $r,$c 重叠');
              occupied[r][c] = true;
            }
          }
        }
      }
      expect(seen.length, sizes.length);
      final placedIndexes =
          bands.expand((band) => band.tiles).map((tile) => tile.index).toList()
            ..sort();
      expect(placedIndexes, List.generate(sizes.length, (i) => i));
    });

    test('大砖放不下时只回填已占用的行，英雄砖另起 band', () {
      const columns = 6;
      final bands = packMetroBands(const [
        MetroTileSize.wide,
        MetroTileSize.wide,
        MetroTileSize.wide,
        MetroTileSize.large,
        MetroTileSize.large,
      ], columns);
      expect(bands, hasLength(2));
      expect(bands.first.rowCount, 1);
      expect(bands.first.tiles, hasLength(3));
      expect(bands.last.tiles.map((tile) => tile.index).toList(), [3, 4]);
    });

    test('已占用的行里留下空列时，用后续小砖回填', () {
      const columns = 4;
      final bands = packMetroBands(const [
        MetroTileSize.wide,
        MetroTileSize.wide,
        MetroTileSize.wide,
        MetroTileSize.large,
        MetroTileSize.small,
      ], columns);
      expect(bands, hasLength(2));
      final firstBand = bands.first;
      expect(firstBand.rowCount, 2);
      expect(
        firstBand.tiles.map((tile) => tile.index),
        containsAll([0, 1, 2, 4]),
      );
      expect(firstBand.tiles.any((tile) => tile.index == 3), isFalse);
      final filler = firstBand.tiles.firstWhere((tile) => tile.index == 4);
      expect(filler.row, 1);
      expect(filler.column, 2);
      expect(bands.last.tiles.single.index, 3);
    });

    test('单个小砖的 band 只占一行高度', () {
      final bands = packMetroBands(const [MetroTileSize.small], 4);
      expect(bands, hasLength(1));
      expect(bands.single.rowCount, 1);
    });
  });
}
