/// 拖入/新增游戏后的 Bangumi 轻量富化。
///
/// 设计目标：网络与文件 IO 全在 fire-and-forget 后台任务里，绝不让入库阻塞；
/// 对已匹配成功的游戏（bangumiSubjectId 非空）与本次会话已尝试过的游戏做幂等跳过；
/// 仅在候选唯一或标题精确一致时才自动写回，避免替用户乱选作品。
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import '../../data/game_repository.dart';
import '../background/background_service.dart';
import '../background/bangumi_title_matcher.dart';
import '../scanner/pe_info.dart';

class BangumiEnrichmentCoordinator {
  BangumiEnrichmentCoordinator({
    required this.games,
    BackgroundCacheService? cache,
    BangumiImageSearchService? search,
  }) : cache = cache ?? BackgroundCacheService(),
       search = search ?? BangumiImageSearchService();

  final GameRepository games;
  final BackgroundCacheService cache;
  final BangumiImageSearchService search;

  final Set<int> _attempted = {};

  void onGames(List<Game> games, String token) {
    if (token.trim().isEmpty) return;
    for (final game in games) {
      if (game.bangumiSubjectId != null || _attempted.contains(game.id)) {
        continue;
      }
      _attempted.add(game.id);
      unawaited(_enrich(game, token));
    }
  }

  Future<void> _enrich(Game game, String token) async {
    // 网络/IO 失败不回滚，也不重试（本次会话只试一次，避免每次库变更都拉网络）。
    try {
      final query = searchQueryForGame(game);
      final candidates = await search.search(query: query, token: token);
      if (candidates.isEmpty) return;
      final chosen = pickUnique(candidates, query);
      if (chosen == null) return;
      // 搜索结果常常没有有效评分；按 Subject ID 拉一次详情拿权威 rating。
      var subject = chosen;
      final needsScore =
          chosen.score == null || chosen.score == 0 || chosen.id == null;
      if (chosen.id != null && needsScore) {
        final detail = await search.fetchSubject(
          subjectId: chosen.id!,
          token: token,
        );
        if (detail != null) subject = detail;
      }
      final subjectId = subject.id ?? chosen.id;
      final score = subject.score ?? chosen.score;
      // 已有用户设置/本地背景时只补评分与条目 ID，绝不覆盖用户选图。
      final hasBackground =
          game.backgroundPath != null && game.backgroundPath!.isNotEmpty;
      if (hasBackground) {
        await games.update(
          game.id,
          GamesCompanion(
            bangumiSubjectId: Value(subjectId),
            bangumiScore: Value(score),
          ),
        );
        return;
      }
      final cached = await cache.download(chosen.imageUrl);
      if (cached == null) return;
      await games.update(
        game.id,
        GamesCompanion(
          backgroundPath: Value(cached),
          detailBackgroundPath: const Value(null),
          backgroundBlurAmount: const Value(0.0),
          bangumiSubjectId: Value(subjectId),
          bangumiScore: Value(score),
        ),
      );
    } catch (_) {
      // 静默：富化是可选增强，不打扰用户。
    }
  }

  /// 选取最可能命中的搜索词：若标题明显是引擎/exe 名（如 ExHIBIT、BGI），
  /// 回退到当前文件夹名，避免拿“ExHIBIT”去搜而永远搜不到。
  static String searchQueryForGame(Game game) {
    final title = game.title.trim();
    if (title.isEmpty) return '';
    if (isBoilerplateTitle(title)) {
      final dirName = _basename(game.dirPath);
      if (dirName.isNotEmpty && !isBoilerplateTitle(dirName)) return dirName;
    }
    final exeStem = _exeStem(game.exePath);
    if (title.toLowerCase() == exeStem.toLowerCase()) {
      final dirName = _basename(game.dirPath);
      if (dirName.isNotEmpty && dirName.toLowerCase() != title.toLowerCase()) {
        return dirName;
      }
    }
    return title;
  }

  static String _basename(String p) => p.replaceAll('\\', '/').split('/').last;

  static String _exeStem(String path) {
    final name = _basename(path).toLowerCase();
    return name.endsWith('.exe') ? name.substring(0, name.length - 4) : name;
  }

  /// 保守选图：交由标题匹配器判断，单个错误结果也绝不采用。
  static BangumiImageCandidate? pickUnique(
    List<BangumiImageCandidate> candidates,
    String title,
  ) {
    return BangumiTitleMatcher.pickBest(candidates, title);
  }

  void dispose() {
    _attempted.clear();
  }
}
