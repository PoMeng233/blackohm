/// Metro 磁贴墙的纯布局算法：列数、尺寸分配与两行编组装箱。
library;

import 'dart:math' as math;

enum MetroTileSize { small, wide, large }

extension MetroTileSizeSpans on MetroTileSize {
  int get columnSpan => this == MetroTileSize.small ? 1 : 2;

  int get rowSpan => this == MetroTileSize.large ? 2 : 1;
}

/// 单个磁贴参与尺寸分配的稳定信息，不包含实时游玩秒数。
class MetroTileSizeInput {
  const MetroTileSizeInput({required this.hasCover, required this.favorite});

  final bool hasCover;
  final bool favorite;
}

class MetroGridMetrics {
  const MetroGridMetrics({
    required this.contentWidth,
    required this.columns,
    required this.tileExtent,
  });

  static const double gap = 12;
  static const double targetTileExtent = 184;

  /// 列数取偶数：2 格宽的宽砖/大砖总能两两配对，
  /// 奇数列会让每行末尾常驻一格空白，磁贴墙显得松散。
  static const int minColumns = 4;
  static const int maxColumns = 10;

  final double contentWidth;
  final int columns;
  final double tileExtent;

  factory MetroGridMetrics.forWidth(double width) {
    final safeWidth = math.max(0.0, width);
    final raw = (safeWidth + gap) / (targetTileExtent + gap);
    final rounded = raw.round();
    final even = rounded.isEven
        ? rounded
        : (raw >= rounded ? rounded + 1 : rounded - 1);
    final columns = even.clamp(minColumns, maxColumns);
    final tileExtent = math.max(
      1.0,
      (safeWidth - gap * (columns - 1)) / columns,
    );
    return MetroGridMetrics(
      contentWidth: safeWidth,
      columns: columns,
      tileExtent: tileExtent,
    );
  }

  double widthFor(MetroTileSize size) =>
      size.columnSpan * tileExtent + (size.columnSpan - 1) * gap;

  double heightFor(MetroTileSize size) =>
      size.rowSpan * tileExtent + (size.rowSpan - 1) * gap;

  double bandHeight(int rowCount) =>
      rowCount * tileExtent + (rowCount - 1) * gap;

  double leftFor(int column) => column * (tileExtent + gap);

  double topFor(int row) => row * (tileExtent + gap);
}

/// 按排序后的顺序分配大小：收藏且有封面优先大方砖，其次有封面的宽砖。
///
/// 只依赖收藏与封面这类低变化字段，避免计时刷新引起磁贴反复变形。
List<MetroTileSize> assignMetroTileSizes(List<MetroTileSizeInput> items) {
  final sizes = List<MetroTileSize>.filled(items.length, MetroTileSize.small);
  if (items.isEmpty) return sizes;

  final largeLimit = math.max(1, (items.length * 0.18).round());
  final wideLimit = (items.length * 0.40).round();

  var largeCount = 0;
  for (var i = 0; i < items.length && largeCount < largeLimit; i++) {
    if (items[i].hasCover && items[i].favorite) {
      sizes[i] = MetroTileSize.large;
      largeCount++;
    }
  }
  for (var i = 0; i < items.length && largeCount < largeLimit; i++) {
    if (sizes[i] == MetroTileSize.small && items[i].hasCover) {
      sizes[i] = MetroTileSize.large;
      largeCount++;
    }
  }

  var wideCount = largeCount;
  for (var i = 0; i < items.length && wideCount < wideLimit; i++) {
    if (sizes[i] == MetroTileSize.small && items[i].hasCover) {
      sizes[i] = MetroTileSize.wide;
      wideCount++;
    }
  }
  return sizes;
}

class MetroTilePlacement {
  const MetroTilePlacement({
    required this.index,
    required this.column,
    required this.row,
    required this.size,
  });

  final int index;
  final int column;
  final int row;
  final MetroTileSize size;
}

class MetroTileBand {
  const MetroTileBand({required this.tiles, required this.rowCount});

  final List<MetroTilePlacement> tiles;

  /// 该 band 实际占用的行数，1 或 2。
  final int rowCount;
}

/// 将有序磁贴装进两行高的 band，band 内按行优先 first-fit。
///
/// 1×1 与 2×1 只占一行，2×2 占满两行；装不下时开启新 band，
/// 保证大磁贴不会被拆到两个 band 里，也便于 SliverList 懒构建。
///
/// 队首放不下但 band 仍有空隙时，会向后寻找能完整填入空隙的磁贴先行放置，
/// 否则一张大砖就会在行尾留下整列空白（n 张大砖后必然出现）。
List<MetroTileBand> packMetroBands(List<MetroTileSize> sizes, int columns) {
  final bandColumns = math.max(2, columns);
  final bands = <MetroTileBand>[];
  var placements = <MetroTilePlacement>[];
  var occupied = List.generate(2, (_) => List.filled(bandColumns, false));
  var rowCount = 0;
  final pending = <({int index, MetroTileSize size})>[
    for (var i = 0; i < sizes.length; i++) (index: i, size: sizes[i]),
  ];

  void flush() {
    if (placements.isEmpty) return;
    bands.add(
      MetroTileBand(
        tiles: List<MetroTilePlacement>.unmodifiable(placements),
        rowCount: rowCount,
      ),
    );
    placements = <MetroTilePlacement>[];
    occupied = List.generate(2, (_) => List.filled(bandColumns, false));
    rowCount = 0;
  }

  bool fits(int row, int column, MetroTileSize size) {
    for (var r = row; r < row + size.rowSpan; r++) {
      for (var c = column; c < column + size.columnSpan; c++) {
        if (r >= 2 || c >= bandColumns || occupied[r][c]) return false;
      }
    }
    return true;
  }

  (int, int)? findSpot(MetroTileSize size, {int maxRows = 2}) {
    for (var row = 0; row <= maxRows - size.rowSpan; row++) {
      for (var column = 0; column <= bandColumns - size.columnSpan; column++) {
        if (fits(row, column, size)) return (row, column);
      }
    }
    return null;
  }

  void place(int index, int row, int column, MetroTileSize size) {
    for (var r = row; r < row + size.rowSpan; r++) {
      for (var c = column; c < column + size.columnSpan; c++) {
        occupied[r][c] = true;
      }
    }
    placements.add(
      MetroTilePlacement(index: index, column: column, row: row, size: size),
    );
    rowCount = math.max(rowCount, row + size.rowSpan);
  }

  while (pending.isNotEmpty) {
    final head = pending.first;
    final spot = findSpot(head.size);
    if (spot != null) {
      place(head.index, spot.$1, spot.$2, head.size);
      pending.removeAt(0);
      continue;
    }
    var backfilled = false;
    for (var j = 1; j < pending.length; j++) {
      // 只回填 band 已占用的行：不再额外撑起新的一行，
      // 否则排在前面的“英雄”大砖会被后排小砖不断挤到下一屏。
      final candidate = findSpot(pending[j].size, maxRows: rowCount);
      if (candidate == null) continue;
      place(pending[j].index, candidate.$1, candidate.$2, pending[j].size);
      pending.removeAt(j);
      backfilled = true;
      break;
    }
    if (backfilled) continue;
    flush();
    // 空 band 至少容纳任意磁贴，队首必然能落在左上角。
    place(head.index, 0, 0, head.size);
    pending.removeAt(0);
  }
  flush();
  return bands;
}
