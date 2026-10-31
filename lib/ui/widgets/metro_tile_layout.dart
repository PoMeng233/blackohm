/// Metro 磁贴墙的纯布局算法：列数、尺寸分配与两行编组装箱。
library;

import 'dart:math' as math;

enum MetroTileSize { small, wide, tall, large }

extension MetroTileSizeSpans on MetroTileSize {
  int get columnSpan => switch (this) {
    MetroTileSize.small || MetroTileSize.tall => 1,
    MetroTileSize.wide || MetroTileSize.large => 2,
  };

  int get rowSpan => switch (this) {
    MetroTileSize.small || MetroTileSize.wide => 1,
    MetroTileSize.tall || MetroTileSize.large => 2,
  };
}

/// 持久化编码：0 = 自动，其余四态由用户手动指定。
MetroTileSize? metroTileSizeFromCode(int code) => switch (code) {
  1 => MetroTileSize.small,
  2 => MetroTileSize.wide,
  3 => MetroTileSize.tall,
  4 => MetroTileSize.large,
  _ => null,
};

int metroTileSizeToCode(MetroTileSize? size) => switch (size) {
  null => 0,
  MetroTileSize.small => 1,
  MetroTileSize.wide => 2,
  MetroTileSize.tall => 3,
  MetroTileSize.large => 4,
};

/// 单个磁贴参与尺寸分配的稳定信息，不包含实时游玩秒数。
class MetroTileSizeInput {
  const MetroTileSizeInput({
    required this.hasCover,
    required this.favorite,
    this.manualSize,
  });

  final bool hasCover;
  final bool favorite;

  /// 用户手动拉伸过的尺寸；为空时参与自动分配。
  final MetroTileSize? manualSize;
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
/// 大砖总量随库大小增长但被摊薄：约每 `2 × columns` 款游戏一张，
/// 再按列表分段均匀挑选，避免 100 款库里的大砖全挤在前几屏。
/// 手动拉伸过的磁贴直接采用其尺寸，不再参与自动配额。
///
/// 只依赖收藏、封面、手动尺寸这类低变化字段，避免计时刷新引起磁贴反复变形。
List<MetroTileSize> assignMetroTileSizes(
  List<MetroTileSizeInput> items, {
  required int columns,
}) {
  final sizes = [
    for (final item in items) item.manualSize ?? MetroTileSize.small,
  ];
  final autoIndices = [
    for (var i = 0; i < items.length; i++)
      if (items[i].manualSize == null) i,
  ];
  if (autoIndices.isEmpty) return sizes;

  final largeLimit = math.max(
    1,
    (autoIndices.length / (2 * math.max(1, columns))).round(),
  );
  for (var k = 0; k < largeLimit; k++) {
    final start = k * items.length ~/ largeLimit;
    final end = (k + 1) * items.length ~/ largeLimit;
    int? pick;
    for (var i = start; i < end; i++) {
      if (items[i].manualSize != null || !items[i].hasCover) continue;
      if (items[i].favorite) {
        pick = i;
        break;
      }
      pick ??= i;
    }
    if (pick != null) sizes[pick] = MetroTileSize.large;
  }

  var wideCount = 0;
  for (final i in autoIndices) {
    if (sizes[i] == MetroTileSize.large) wideCount++;
  }
  final wideLimit = math.max(wideCount, (autoIndices.length * 0.40).round());
  for (final i in autoIndices) {
    if (wideCount >= wideLimit) break;
    if (sizes[i] == MetroTileSize.small && items[i].hasCover) {
      sizes[i] = MetroTileSize.wide;
      wideCount++;
    }
  }
  return sizes;
}

/// 根据拖动位移把磁贴吸附到四种尺寸之一。
///
/// 阈值按半格略低取值：横向超过约 30% 格宽才跨列，避免轻抖就变形；
/// 纵横向可同时生效（例如小砖向右下拖直接变成大砖）。
MetroTileSize resolveResizeTarget({
  required MetroTileSize start,
  required double dx,
  required double dy,
  required double extent,
}) {
  final threshold = math.max(28.0, extent * 0.3);
  var columns = start.columnSpan;
  var rows = start.rowSpan;
  if (dx > threshold) {
    columns = 2;
  } else if (dx < -threshold) {
    columns = 1;
  }
  if (dy > threshold) {
    rows = 2;
  } else if (dy < -threshold) {
    rows = 1;
  }
  if (columns == 2 && rows == 2) return MetroTileSize.large;
  if (columns == 2) return MetroTileSize.wide;
  if (rows == 2) return MetroTileSize.tall;
  return MetroTileSize.small;
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
/// 1×1 与 2×1 只占一行，2×2 / 1×2 占满两行；装不下时开启新 band，
/// 保证高磁贴不会被拆到两个 band 里，也便于 SliverList 懒构建。
///
/// 每个 band 最多放 [maxLargePerBand] 张大砖，避免两三张大砖吃掉整屏；
/// 队首放不下但 band 仍有空隙时，会向后寻找能完整填入空隙的磁贴先行放置，
/// 否则一张大砖就会在行尾留下整列空白（n 张大砖后必然出现）。
List<MetroTileBand> packMetroBands(
  List<MetroTileSize> sizes,
  int columns, {
  int maxLargePerBand = 1,
}) {
  final bandColumns = math.max(2, columns);
  final largeCap = math.max(1, maxLargePerBand);
  final bands = <MetroTileBand>[];
  var placements = <MetroTilePlacement>[];
  var occupied = List.generate(2, (_) => List.filled(bandColumns, false));
  var rowCount = 0;
  var largeInBand = 0;
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
    largeInBand = 0;
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
    if (size == MetroTileSize.large && largeInBand >= largeCap) return null;
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
    if (size == MetroTileSize.large) largeInBand++;
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
