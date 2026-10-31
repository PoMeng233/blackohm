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
        metrics.widthFor(MetroTileSize.tall),
        closeTo(metrics.tileExtent, 0.001),
      );
      expect(
        metrics.heightFor(MetroTileSize.tall),
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

  group('尺寸编码', () {
    test('四种尺寸与自动状态可无损往返', () {
      for (final size in MetroTileSize.values) {
        expect(metroTileSizeFromCode(metroTileSizeToCode(size)), size);
      }
      expect(metroTileSizeToCode(null), 0);
      expect(metroTileSizeFromCode(0), isNull);
      expect(metroTileSizeFromCode(99), isNull);
    });

    test('竖砖占一列两行，大砖占两列两行', () {
      expect(MetroTileSize.tall.columnSpan, 1);
      expect(MetroTileSize.tall.rowSpan, 2);
      expect(MetroTileSize.large.columnSpan, 2);
      expect(MetroTileSize.large.rowSpan, 2);
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
      ], columns: 6);
      expect(sizes[1], MetroTileSize.large);
      expect(sizes[0], isNot(MetroTileSize.large));
    });

    test('大砖数量随库大小增长但远低于 18% 比例', () {
      List<MetroTileSize> assign(int count, int columns) =>
          assignMetroTileSizes([
            for (var i = 0; i < count; i++)
              const MetroTileSizeInput(hasCover: true, favorite: true),
          ], columns: columns);

      expect(assign(10, 6).where((s) => s == MetroTileSize.large).length, 1);
      expect(assign(20, 6).where((s) => s == MetroTileSize.large).length, 2);
      expect(assign(100, 6).where((s) => s == MetroTileSize.large).length, 8);
      expect(assign(100, 10).where((s) => s == MetroTileSize.large).length, 5);
    });

    test('100 款游戏的大砖均匀分布在整个列表而不是挤在前几屏', () {
      final sizes = assignMetroTileSizes([
        for (var i = 0; i < 100; i++)
          const MetroTileSizeInput(hasCover: true, favorite: true),
      ], columns: 6);
      final largeIndexes = [
        for (var i = 0; i < sizes.length; i++)
          if (sizes[i] == MetroTileSize.large) i,
      ];
      expect(largeIndexes, [0, 12, 25, 37, 50, 62, 75, 87]);
    });

    test('无封面游戏保持小砖，宽砖配额约 40%', () {
      final items = List.generate(
        20,
        (i) => MetroTileSizeInput(hasCover: i.isEven, favorite: i.isEven),
      );
      final sizes = assignMetroTileSizes(items, columns: 6);
      expect(sizes.where((s) => s == MetroTileSize.large).length, 2);
      expect(sizes.where((s) => s == MetroTileSize.wide).length, 6);
      for (var i = 0; i < sizes.length; i++) {
        if (!items[i].hasCover) {
          expect(sizes[i], MetroTileSize.small);
        }
      }
    });

    test('手动尺寸直接采用，且不参与自动大砖配额', () {
      final sizes = assignMetroTileSizes([
        const MetroTileSizeInput(
          hasCover: true,
          favorite: true,
          manualSize: MetroTileSize.tall,
        ),
        const MetroTileSizeInput(hasCover: true, favorite: true),
        const MetroTileSizeInput(
          hasCover: false,
          favorite: false,
          manualSize: MetroTileSize.wide,
        ),
        const MetroTileSizeInput(hasCover: true, favorite: true),
      ], columns: 4);
      expect(sizes[0], MetroTileSize.tall);
      expect(sizes[2], MetroTileSize.wide);
      expect(sizes.where((s) => s == MetroTileSize.large).length, 1);
    });

    test('全部手动指定时不再自动分配', () {
      final sizes = assignMetroTileSizes(const [
        MetroTileSizeInput(
          hasCover: true,
          favorite: true,
          manualSize: MetroTileSize.small,
        ),
        MetroTileSizeInput(
          hasCover: true,
          favorite: true,
          manualSize: MetroTileSize.wide,
        ),
      ], columns: 6);
      expect(sizes, [MetroTileSize.small, MetroTileSize.wide]);
    });

    test('空列表返回空结果', () {
      expect(assignMetroTileSizes(const [], columns: 6), isEmpty);
    });
  });

  group('resolveResizeTarget', () {
    const extent = 150.0; // 阈值 max(28, 45) = 45

    test('横向、纵向可独立跨格，也可同时跨格', () {
      expect(
        resolveResizeTarget(
          start: MetroTileSize.small,
          dx: 50,
          dy: 0,
          extent: extent,
        ),
        MetroTileSize.wide,
      );
      expect(
        resolveResizeTarget(
          start: MetroTileSize.small,
          dx: 0,
          dy: 50,
          extent: extent,
        ),
        MetroTileSize.tall,
      );
      expect(
        resolveResizeTarget(
          start: MetroTileSize.small,
          dx: 50,
          dy: 50,
          extent: extent,
        ),
        MetroTileSize.large,
      );
    });

    test('向反方向拖动收缩，大砖可退回竖砖/宽砖/小砖', () {
      expect(
        resolveResizeTarget(
          start: MetroTileSize.large,
          dx: -50,
          dy: 0,
          extent: extent,
        ),
        MetroTileSize.tall,
      );
      expect(
        resolveResizeTarget(
          start: MetroTileSize.large,
          dx: 0,
          dy: -50,
          extent: extent,
        ),
        MetroTileSize.wide,
      );
      expect(
        resolveResizeTarget(
          start: MetroTileSize.large,
          dx: -50,
          dy: -50,
          extent: extent,
        ),
        MetroTileSize.small,
      );
    });

    test('未超过阈值时保持原尺寸', () {
      expect(
        resolveResizeTarget(
          start: MetroTileSize.small,
          dx: 40,
          dy: -40,
          extent: extent,
        ),
        MetroTileSize.small,
      );
    });
  });

  group('packMetroBands', () {
    test('磁贴不重叠、不越界，且高磁贴完整落在同一 band', () {
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

    test('每 band 默认最多一张大砖，其余大砖另起 band', () {
      final bands = packMetroBands(const [
        MetroTileSize.large,
        MetroTileSize.large,
      ], 6);
      expect(bands, hasLength(2));
      expect(bands.first.tiles.single.index, 0);
      expect(bands.last.tiles.single.index, 1);
    });

    test('10 列宽屏允许同一 band 放两张以内的大砖', () {
      final bands = packMetroBands(
        const [MetroTileSize.large, MetroTileSize.large],
        10,
        maxLargePerBand: 2,
      );
      expect(bands, hasLength(1));
      expect(bands.single.tiles, hasLength(2));
      expect(bands.single.rowCount, 2);
    });

    test('竖砖占两行，与小砖同 band 并排', () {
      final bands = packMetroBands(const [
        MetroTileSize.tall,
        MetroTileSize.small,
        MetroTileSize.small,
      ], 4);
      expect(bands, hasLength(1));
      final band = bands.single;
      expect(band.rowCount, 2);
      final tall = band.tiles.firstWhere((t) => t.index == 0);
      expect(tall.row, 0);
      expect(tall.column, 0);
      for (final tile in band.tiles.where((t) => t.index != 0)) {
        expect(tile.row, 0);
        expect(tile.row + tile.size.rowSpan, lessThanOrEqualTo(2));
      }
    });

    test('大砖放不下时只回填已占用的行，英雄砖另起 band', () {
      const columns = 6;
      final bands = packMetroBands(
        const [
          MetroTileSize.wide,
          MetroTileSize.wide,
          MetroTileSize.wide,
          MetroTileSize.large,
          MetroTileSize.large,
        ],
        columns,
        maxLargePerBand: 2,
      );
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

    test('空列表不产生 band', () {
      expect(packMetroBands(const [], 6), isEmpty);
    });
  });
}
