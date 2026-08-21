/// 时长统计：30 天 / 当前季度 / 当前年度 + GitHub 风格活跃热图。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../features/tracking/session_merge.dart';
import '../../features/tracking/tracking_engine.dart';
import '../../providers.dart';
import '../theme.dart';

enum InsightsRange { month, quarter, year }

enum InsightsChart { heatmap, bars }

class InsightsPage extends ConsumerStatefulWidget {
  const InsightsPage({super.key});

  @override
  ConsumerState<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends ConsumerState<InsightsPage> {
  InsightsRange _range = InsightsRange.month;
  InsightsChart _chart = InsightsChart.heatmap;

  ({DateTime start, DateTime end}) _bounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_range) {
      InsightsRange.month => (
        start: today.subtract(const Duration(days: 29)),
        end: today.add(const Duration(days: 1)),
      ),
      InsightsRange.quarter => (
        start: DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1),
        end: today.add(const Duration(days: 1)),
      ),
      InsightsRange.year => (
        start: DateTime(now.year),
        end: today.add(const Duration(days: 1)),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _bounds();
    final games = ref.watch(gameListProvider).value ?? const <Game>[];
    final active =
        ref.watch(trackingStateProvider).value ??
        ref.watch(trackingEngineProvider).current;
    final sessions = ref
        .read(sessionRepoProvider)
        .watchInRange(bounds.start, bounds.end);

    return StreamBuilder<List<PlaySession>>(
      stream: sessions,
      builder: (context, snapshot) {
        final model = _InsightsModel.from(
          games: games,
          sessions: snapshot.data ?? const [],
          start: bounds.start,
          end: bounds.end,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          children: [
            Row(
              children: [
                const Icon(
                  Icons.query_stats_rounded,
                  color: AppColors.accent,
                  size: 26,
                ),
                const SizedBox(width: 10),
                const Text(
                  '游玩时长',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _ActivePill(active: active, game: model.gameFor(active.gameId)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '只统计游戏窗口真正处于前台的时间',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SegmentedButton<InsightsRange>(
              segments: const [
                ButtonSegment(
                  value: InsightsRange.month,
                  label: Text('近 30 天'),
                ),
                ButtonSegment(value: InsightsRange.quarter, label: Text('本季度')),
                ButtonSegment(value: InsightsRange.year, label: Text('本年度')),
              ],
              selected: {_range},
              onSelectionChanged: (value) =>
                  setState(() => _range = value.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                side: WidgetStatePropertyAll(
                  BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  _MetricCard(
                    '当前范围',
                    formatPlayDuration(model.rangeSeconds),
                    Icons.timelapse,
                    AppColors.accent,
                  ),
                  _MetricCard(
                    '今日游玩',
                    formatPlayDuration(model.todaySeconds),
                    Icons.today_rounded,
                    const Color(0xFF60A5FA),
                  ),
                  _MetricCard(
                    '库内总时长',
                    formatPlayDuration(model.lifetimeSeconds),
                    Icons.auto_stories_rounded,
                    AppColors.leBadge,
                  ),
                  _MetricCard(
                    '范围内会话',
                    '${model.sessionCount} 次',
                    Icons.layers_rounded,
                    const Color(0xFFF59E0B),
                  ),
                ];
                if (constraints.maxWidth < 850) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards
                        .map(
                          (card) => SizedBox(
                            width: (constraints.maxWidth - 12) / 2,
                            child: card,
                          ),
                        )
                        .toList(),
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<InsightsChart>(
              segments: const [
                ButtonSegment(
                  value: InsightsChart.heatmap,
                  icon: Icon(Icons.grid_on_rounded),
                  label: Text('热图'),
                ),
                ButtonSegment(
                  value: InsightsChart.bars,
                  icon: Icon(Icons.bar_chart_rounded),
                  label: Text('条状图'),
                ),
              ],
              selected: {_chart},
              onSelectionChanged: (value) =>
                  setState(() => _chart = value.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: _chart == InsightsChart.heatmap ? '前台游玩热图' : '每日游玩时长',
              subtitle: '${_rangeLabel(_range)} · 每格/每柱代表一个自然日',
              child: _chart == InsightsChart.heatmap
                  ? _ActivityHeatmap(
                      start: bounds.start,
                      end: bounds.end,
                      daily: model.daily,
                    )
                  : _DailyBarChart(
                      start: bounds.start,
                      end: bounds.end,
                      daily: model.daily,
                    ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final ranking = _SectionCard(
                  title: '范围内游戏排行',
                  subtitle: '按当前选择范围内的 Session 聚合',
                  child: _TopGames(games: model.topGames),
                );
                final recent = _SectionCard(
                  title: '最近 Session',
                  subtitle: '只展示当前范围内已完成记录',
                  child: _RecentSessions(
                    sessions: model.recent,
                    gameFor: model.gameFor,
                  ),
                );
                if (constraints.maxWidth < 860) {
                  return Column(
                    children: [ranking, const SizedBox(height: 18), recent],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ranking),
                    const SizedBox(width: 18),
                    Expanded(child: recent),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

String _rangeLabel(InsightsRange range) => switch (range) {
  InsightsRange.month => '最近 30 天',
  InsightsRange.quarter => '本季度',
  InsightsRange.year => '本年度',
};

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon, this.accent);
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withAlpha(34),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _ActivityHeatmap extends StatelessWidget {
  const _ActivityHeatmap({
    required this.start,
    required this.end,
    required this.daily,
  });
  final DateTime start;
  final DateTime end;
  final Map<DateTime, int> daily;

  @override
  Widget build(BuildContext context) {
    final gridStart = start.subtract(Duration(days: start.weekday % 7));
    final lastDay = end.subtract(const Duration(days: 1));
    final gridEnd = lastDay.add(Duration(days: 6 - (lastDay.weekday % 7)));
    final columns = (gridEnd.difference(gridStart).inDays + 1) ~/ 7;
    final maxSeconds = daily.values.fold<int>(0, math.max);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 28),
          for (var col = 0; col < columns; col++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                children: [
                  ...List.generate(7, (row) {
                    final date = gridStart.add(Duration(days: col * 7 + row));
                    final inRange = !date.isBefore(start) && date.isBefore(end);
                    final seconds = inRange
                        ? (daily[DateTime(date.year, date.month, date.day)] ??
                              0)
                        : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Tooltip(
                        message: inRange
                            ? '${_dateLabel(date)}\n${formatPlayDuration(seconds)}'
                            : '',
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: inRange
                                ? _heatColor(seconds, maxSeconds)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                            border: inRange
                                ? Border.all(
                                    color: AppColors.border.withAlpha(100),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Color _heatColor(int seconds, int maxSeconds) {
  if (seconds <= 0) return AppColors.surfaceActive;
  final ratio = maxSeconds <= 0 ? 0.0 : seconds / maxSeconds;
  if (ratio < .25) return const Color(0xFF166534);
  if (ratio < .5) return const Color(0xFF15803D);
  if (ratio < .75) return const Color(0xFF16A34A);
  return AppColors.accent;
}

String _dateLabel(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({
    required this.start,
    required this.end,
    required this.daily,
  });
  final DateTime start;
  final DateTime end;
  final Map<DateTime, int> daily;

  @override
  Widget build(BuildContext context) {
    final days = end.difference(start).inDays;
    final maxSeconds = daily.values.fold<int>(0, math.max);
    return SizedBox(
      height: 190,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(days, (index) {
            final date = start.add(Duration(days: index));
            final key = DateTime(date.year, date.month, date.day);
            final seconds = daily[key] ?? 0;
            final ratio = maxSeconds == 0 ? 0.0 : seconds / maxSeconds;
            return Tooltip(
              message: '${_dateLabel(date)}\\n${formatPlayDuration(seconds)}',
              child: Container(
                width: 22,
                margin: const EdgeInsets.only(right: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (seconds > 0)
                      Text(
                        formatPlayDuration(seconds),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      height: math.max(4.0, ratio * 125),
                      decoration: BoxDecoration(
                        color: _heatColor(seconds, maxSeconds),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${date.month}/${date.day}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _TopGames extends StatelessWidget {
  const _TopGames({required this.games});
  final List<_RangeGame> games;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) return const _EmptyState(message: '当前范围暂无游玩时长');
    final maxSeconds = games.first.seconds;
    return Column(
      children: [
        for (var i = 0; i < games.length; i++) ...[
          _RankRow(game: games[i], rank: i + 1, maxSeconds: maxSeconds),
          if (i != games.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RangeGame {
  const _RangeGame(this.game, this.seconds);
  final Game game;
  final int seconds;
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.game,
    required this.rank,
    required this.maxSeconds,
  });
  final _RangeGame game;
  final int rank;
  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    final ratio = maxSeconds == 0 ? 0.0 : game.seconds / maxSeconds;
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '#$rank',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ),
        if (game.game.iconPng != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              game.game.iconPng!,
              width: 26,
              height: 26,
              cacheWidth: 52,
              cacheHeight: 52,
            ),
          )
        else
          const Icon(
            Icons.videogame_asset,
            color: AppColors.textMuted,
            size: 24,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      game.game.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    formatPlayDuration(game.seconds),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: AppColors.surfaceActive,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentSessions extends StatelessWidget {
  const _RecentSessions({required this.sessions, required this.gameFor});
  final List<MergedPlaySession> sessions;
  final Game? Function(int? id) gameFor;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const _EmptyState(message: '当前范围暂无完成的 Session');
    }
    return Column(
      children: [
        for (var i = 0; i < sessions.length; i++) ...[
          _SessionRow(session: sessions[i], game: gameFor(sessions[i].gameId)),
          if (i != sessions.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AppColors.border),
            ),
        ],
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.game});
  final MergedPlaySession session;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    final t = session.startedAt;
    final date =
        '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Row(
      children: [
        if (game?.iconPng != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              game!.iconPng!,
              width: 26,
              height: 26,
              cacheWidth: 52,
              cacheHeight: 52,
            ),
          )
        else
          const Icon(
            Icons.schedule_rounded,
            size: 22,
            color: AppColors.textMuted,
          ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                game?.title ?? '已移除的游戏',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                date,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Text(
          formatPlayDuration(session.durationSeconds),
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ActivePill extends StatelessWidget {
  const _ActivePill({required this.active, required this.game});
  final TrackingPublicState active;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    if (!active.isActive) {
      return const Text(
        '后台守护中',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(24),
        border: Border.all(color: AppColors.accent.withAlpha(100)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '${game?.title ?? '游戏'} · ${formatStopwatch(active.elapsedMs)}',
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 100,
    child: Center(
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    ),
  );
}

class _InsightsModel {
  _InsightsModel({
    required this.rangeSeconds,
    required this.todaySeconds,
    required this.lifetimeSeconds,
    required this.sessionCount,
    required this.daily,
    required this.topGames,
    required this.recent,
    required this.gameFor,
  });

  factory _InsightsModel.from({
    required List<Game> games,
    required List<PlaySession> sessions,
    required DateTime start,
    required DateTime end,
  }) {
    final now = DateTime.now();
    final daily = <DateTime, int>{};
    final byGame = <int, int>{};
    var total = 0;
    for (final session in sessions) {
      if (session.durationSeconds <= 0 || session.gameId == null) continue;
      var cursor = session.startedAt.isAfter(start) ? session.startedAt : start;
      var sessionEnd = session.endedAt ?? now;
      final fallbackEnd = session.startedAt.add(
        Duration(seconds: session.durationSeconds),
      );
      if (!sessionEnd.isAfter(session.startedAt)) sessionEnd = fallbackEnd;
      final clippedEnd = sessionEnd.isBefore(end) ? sessionEnd : end;
      if (!clippedEnd.isAfter(cursor)) continue;
      while (cursor.isBefore(clippedEnd)) {
        final day = DateTime(cursor.year, cursor.month, cursor.day);
        final next = day.add(const Duration(days: 1));
        final chunkEnd = clippedEnd.isBefore(next) ? clippedEnd : next;
        final seconds = chunkEnd.difference(cursor).inSeconds;
        if (seconds > 0) {
          daily[day] = (daily[day] ?? 0) + seconds;
          byGame[session.gameId!] = (byGame[session.gameId!] ?? 0) + seconds;
          total += seconds;
        }
        cursor = chunkEnd;
      }
    }
    final mergedSessions = mergeSessions(sessions);
    final gameMap = {for (final game in games) game.id: game};
    final ranked =
        byGame.entries
            .where((entry) => gameMap.containsKey(entry.key))
            .map((entry) => _RangeGame(gameMap[entry.key]!, entry.value))
            .toList()
          ..sort((a, b) => b.seconds.compareTo(a.seconds));
    final today = DateTime(now.year, now.month, now.day);
    return _InsightsModel(
      rangeSeconds: total,
      todaySeconds: daily[today] ?? 0,
      lifetimeSeconds: games.fold(
        0,
        (sum, game) => sum + game.totalPlaySeconds,
      ),
      sessionCount: mergedSessions.length,
      daily: daily,
      topGames: ranked.take(5).toList(growable: false),
      recent: mergedSessions.reversed.take(5).toList(growable: false),
      gameFor: (id) => id == null ? null : gameMap[id],
    );
  }

  final int rangeSeconds;
  final int todaySeconds;
  final int lifetimeSeconds;
  final int sessionCount;
  final Map<DateTime, int> daily;
  final List<_RangeGame> topGames;
  final List<MergedPlaySession> recent;
  final Game? Function(int? id) gameFor;
}
