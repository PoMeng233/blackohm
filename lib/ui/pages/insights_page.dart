/// 时长可视化页面：总览、近 7 日趋势、游戏排行与最近 Session。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../features/tracking/tracking_engine.dart';
import '../../providers.dart';
import '../theme.dart';

class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(gameListProvider);
    final active =
        ref.watch(trackingStateProvider).value ??
        ref.watch(trackingEngineProvider).current;
    final sessions = ref.read(sessionRepoProvider).watchRecentAll(limit: 1000);

    return StreamBuilder<List<PlaySession>>(
      stream: sessions,
      builder: (context, snapshot) {
        final games = gamesAsync.value ?? const <Game>[];
        final model = _InsightsModel.from(games, snapshot.data ?? const []);
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
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 850;
                final cards = [
                  _MetricCard(
                    icon: Icons.today_rounded,
                    label: '今日游玩',
                    value: formatPlayDuration(model.todaySeconds),
                    accent: AppColors.accent,
                  ),
                  _MetricCard(
                    icon: Icons.date_range_rounded,
                    label: '近 7 天',
                    value: formatPlayDuration(model.weekSeconds),
                    accent: const Color(0xFF60A5FA),
                  ),
                  _MetricCard(
                    icon: Icons.auto_stories_rounded,
                    label: '库内总时长',
                    value: formatPlayDuration(model.totalSeconds),
                    accent: AppColors.leBadge,
                  ),
                  _MetricCard(
                    icon: Icons.layers_rounded,
                    label: '已记录会话',
                    value: '${model.sessionCount} 次',
                    accent: const Color(0xFFF59E0B),
                  ),
                ];
                if (compact) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards
                        .map(
                          (card) => SizedBox(
                            width: math.max(
                              200,
                              (constraints.maxWidth - 12) / 2,
                            ),
                            child: card,
                          ),
                        )
                        .toList(growable: false),
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
            const SizedBox(height: 22),
            _SectionCard(
              title: '近 7 日前台游玩趋势',
              subtitle: '时长按 Session 实际跨日边界切分',
              child: _SevenDayChart(days: model.days),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 860;
                final ranking = _SectionCard(
                  title: '游戏时长排行',
                  subtitle: '以库内累计前台时长排序',
                  child: _TopGames(games: model.topGames),
                );
                final recent = _SectionCard(
                  title: '最近 Session',
                  subtitle: '失焦超过 3 秒、锁屏或睡眠时结束',
                  child: _RecentSessions(
                    sessions: model.recentSessions,
                    gameFor: model.gameFor,
                  ),
                );
                if (narrow) {
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
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
  Widget build(BuildContext context) {
    return Container(
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
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SevenDayChart extends StatelessWidget {
  const _SevenDayChart({required this.days});

  final List<_DailyPlay> days;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = days.fold<int>(
      0,
      (max, day) => math.max(max, day.seconds),
    );
    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _Bar(day: day, maxSeconds: maxSeconds),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.day, required this.maxSeconds});

  final _DailyPlay day;
  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    final ratio = maxSeconds == 0 ? 0.0 : day.seconds / maxSeconds;
    final height = math.max(4.0, ratio * 118);
    final today = _sameDay(day.date, DateTime.now());
    return Tooltip(
      message: '${day.fullLabel}：${formatPlayDuration(day.seconds)}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            day.seconds == 0 ? '' : formatPlayDuration(day.seconds),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: today
                    ? const [AppColors.accent, Color(0xFF0B9B73)]
                    : const [Color(0xFF64748B), Color(0xFF334155)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            day.label,
            style: TextStyle(
              color: today ? AppColors.accent : AppColors.textSecondary,
              fontWeight: today ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopGames extends StatelessWidget {
  const _TopGames({required this.games});

  final List<Game> games;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return const _EmptyState(message: '尚无已累计的游玩时长');
    }
    final maxSeconds = games.first.totalPlaySeconds;
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

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.game,
    required this.rank,
    required this.maxSeconds,
  });

  final Game game;
  final int rank;
  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    final ratio = maxSeconds == 0 ? 0.0 : game.totalPlaySeconds / maxSeconds;
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '#$rank',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ),
        if (game.iconPng != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(game.iconPng!, width: 26, height: 26),
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
                      game.title,
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
                    formatPlayDuration(game.totalPlaySeconds),
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

  final List<PlaySession> sessions;
  final Game? Function(int? id) gameFor;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const _EmptyState(message: '尚无完成的游玩 Session');
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

  final PlaySession session;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    final started = session.startedAt;
    final time =
        '${started.month.toString().padLeft(2, '0')}-${started.day.toString().padLeft(2, '0')} '
        '${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}';
    return Row(
      children: [
        if (game?.iconPng != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(game!.iconPng!, width: 26, height: 26),
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
                time,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.fiber_manual_record,
            color: AppColors.accent,
            size: 10,
          ),
          const SizedBox(width: 5),
          Text(
            '${game?.title ?? '游戏'} · ${formatStopwatch(active.elapsedMs)}',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

class _DailyPlay {
  const _DailyPlay({required this.date, required this.seconds});

  final DateTime date;
  final int seconds;

  String get label =>
      const ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][date.weekday % 7];

  String get fullLabel =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _InsightsModel {
  _InsightsModel({
    required this.totalSeconds,
    required this.todaySeconds,
    required this.weekSeconds,
    required this.sessionCount,
    required this.days,
    required this.topGames,
    required this.recentSessions,
    required this.gameFor,
  });

  factory _InsightsModel.from(List<Game> games, List<PlaySession> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final daily = List<int>.filled(7, 0);

    for (final session in sessions) {
      if (session.durationSeconds <= 0) continue;
      var cursor = session.startedAt;
      var end =
          session.endedAt ??
          session.startedAt.add(Duration(seconds: session.durationSeconds));
      if (!end.isAfter(cursor)) {
        end = cursor.add(Duration(seconds: session.durationSeconds));
      }
      while (cursor.isBefore(end)) {
        final dayStart = DateTime(cursor.year, cursor.month, cursor.day);
        final nextDay = dayStart.add(const Duration(days: 1));
        final chunkEnd = end.isBefore(nextDay) ? end : nextDay;
        if (!dayStart.isBefore(start) &&
            dayStart.isBefore(today.add(const Duration(days: 1)))) {
          final index = dayStart.difference(start).inDays;
          if (index >= 0 && index < daily.length) {
            daily[index] += chunkEnd.difference(cursor).inSeconds;
          }
        }
        cursor = chunkEnd;
      }
    }

    final gameMap = {for (final game in games) game.id: game};
    final ranked = games.where((g) => g.totalPlaySeconds > 0).toList()
      ..sort((a, b) => b.totalPlaySeconds.compareTo(a.totalPlaySeconds));
    final recent = sessions.where((s) => s.durationSeconds > 0).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return _InsightsModel(
      totalSeconds: games.fold(0, (sum, game) => sum + game.totalPlaySeconds),
      todaySeconds: daily.last,
      weekSeconds: daily.fold(0, (sum, seconds) => sum + seconds),
      sessionCount: sessions.where((s) => s.durationSeconds > 0).length,
      days: List.generate(
        7,
        (i) => _DailyPlay(
          date: start.add(Duration(days: i)),
          seconds: daily[i],
        ),
      ),
      topGames: ranked.take(5).toList(growable: false),
      recentSessions: recent.take(5).toList(growable: false),
      gameFor: (id) => id == null ? null : gameMap[id],
    );
  }

  final int totalSeconds;
  final int todaySeconds;
  final int weekSeconds;
  final int sessionCount;
  final List<_DailyPlay> days;
  final List<Game> topGames;
  final List<PlaySession> recentSessions;
  final Game? Function(int? id) gameFor;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
