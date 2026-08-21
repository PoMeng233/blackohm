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

DateTime _sessionEnd(PlaySession session) {
  final fallback = session.startedAt.add(
    Duration(seconds: session.durationSeconds),
  );
  final ended = session.endedAt;
  if (ended == null || !ended.isAfter(session.startedAt)) return fallback;
  return ended;
}
