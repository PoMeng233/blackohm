/// 仅用于 UI 展示的会话合并。
///
/// 原始 PlaySessions 永远保留不改写；同一游戏相邻记录间隔不超过 30 分钟时，
/// 在历史列表、统计页和会话数量中视为一段连续游玩记录。
library;

import '../../core/database/app_database.dart';

class MergedPlaySession {
  const MergedPlaySession({
    required this.gameId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.sourceCount,
  });

  final int? gameId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final int sourceCount;
}

List<MergedPlaySession> mergeSessions(
  Iterable<PlaySession> sessions, {
  Duration maxGap = const Duration(minutes: 30),
}) {
  final sorted =
      sessions
          .where((session) => session.durationSeconds > 0)
          .toList(growable: false)
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final merged = <MergedPlaySession>[];

  for (final session in sorted) {
    final end = _sessionEnd(session);
    if (merged.isNotEmpty) {
      final previous = merged.last;
      final gap = session.startedAt.difference(previous.endedAt);
      if (previous.gameId == session.gameId &&
          !gap.isNegative &&
          gap <= maxGap) {
        merged[merged.length - 1] = MergedPlaySession(
          gameId: previous.gameId,
          startedAt: previous.startedAt,
          endedAt: end.isAfter(previous.endedAt) ? end : previous.endedAt,
          durationSeconds: previous.durationSeconds + session.durationSeconds,
          sourceCount: previous.sourceCount + 1,
        );
        continue;
      }
    }
    merged.add(
      MergedPlaySession(
        gameId: session.gameId,
        startedAt: session.startedAt,
        endedAt: end,
        durationSeconds: session.durationSeconds,
        sourceCount: 1,
      ),
    );
  }
  return merged;
}

/// 将真实累计秒数按 Session 的墙上时间跨度比例分配到自然日。
/// [durationSeconds] 是唯一的总量来源；起止时间只决定归属，不增加时长。
Map<DateTime, int> distributeSessionDurationByDay(
  PlaySession session, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final duration = session.durationSeconds;
  if (duration <= 0 || !rangeEnd.isAfter(rangeStart)) return const {};

  final startedAt = session.startedAt;
  final fallbackEnd = startedAt.add(Duration(seconds: duration));
  final endedAt = session.endedAt;
  final effectiveEnd = endedAt != null && endedAt.isAfter(startedAt)
      ? endedAt
      : fallbackEnd;
  final clippedStart = startedAt.isAfter(rangeStart) ? startedAt : rangeStart;
  final clippedEnd = effectiveEnd.isBefore(rangeEnd) ? effectiveEnd : rangeEnd;
  if (!clippedEnd.isAfter(clippedStart)) return const {};

  final totalMicros = effectiveEnd.difference(startedAt).inMicroseconds;
  if (totalMicros <= 0) return const {};
  final result = <DateTime, int>{};
  var cursor = clippedStart;
  var allocatedThrough =
      (duration * clippedStart.difference(startedAt).inMicroseconds) ~/
      totalMicros;

  while (cursor.isBefore(clippedEnd)) {
    final day = DateTime(cursor.year, cursor.month, cursor.day);
    final nextDay = day.add(const Duration(days: 1));
    final chunkEnd = clippedEnd.isBefore(nextDay) ? clippedEnd : nextDay;
    final cumulative =
        (duration * chunkEnd.difference(startedAt).inMicroseconds) ~/
        totalMicros;
    final seconds = cumulative - allocatedThrough;
    if (seconds > 0) result[day] = (result[day] ?? 0) + seconds;
    allocatedThrough = cumulative;
    cursor = chunkEnd;
  }
  return result;
}

DateTime _sessionEnd(PlaySession session) {
  final fallback = session.startedAt.add(
    Duration(seconds: session.durationSeconds),
  );
  final ended = session.endedAt;
  if (ended == null || !ended.isAfter(session.startedAt)) return fallback;
  return ended;
}
