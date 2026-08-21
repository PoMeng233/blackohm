import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/features/tracking/session_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('同一游戏 30 分钟内的相邻 Session 合并展示', () {
    final start = DateTime(2026, 1, 1, 10);
    final sessions = [
      PlaySession(
        id: 1,
        gameId: 7,
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 20)),
        durationSeconds: 1200,
      ),
      PlaySession(
        id: 2,
        gameId: 7,
        startedAt: start.add(const Duration(minutes: 35)),
        endedAt: start.add(const Duration(minutes: 50)),
        durationSeconds: 900,
      ),
      PlaySession(
        id: 3,
        gameId: 8,
        startedAt: start.add(const Duration(minutes: 55)),
        endedAt: start.add(const Duration(minutes: 60)),
        durationSeconds: 300,
      ),
    ];

    final result = mergeSessions(sessions);
    expect(result, hasLength(2));
    expect(result.first.gameId, 7);
    expect(result.first.durationSeconds, 2100);
    expect(result.first.sourceCount, 2);
    expect(result.last.gameId, 8);
  });

  test('超过 30 分钟或不同游戏不合并', () {
    final start = DateTime(2026, 1, 1, 10);
    final sessions = [
      PlaySession(
        id: 1,
        gameId: 1,
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 5)),
        durationSeconds: 300,
      ),
      PlaySession(
        id: 2,
        gameId: 1,
        startedAt: start.add(const Duration(minutes: 36)),
        endedAt: start.add(const Duration(minutes: 40)),
        durationSeconds: 240,
      ),
    ];
    expect(mergeSessions(sessions), hasLength(2));
  });
}
