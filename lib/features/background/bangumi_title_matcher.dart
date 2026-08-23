/// Bangumi 条目标题匹配器：对单条搜索结果也不盲目接受。
///
/// 规则（全部保守）：
///   * 归一化：小写、去空白与标点、保留中日韩与拉丁数字；
///   * 同时比较日文原名 name、中文名 nameCn、展示标题 title；
///   * 相似度用“完全相等 / 包含 / 二元组 Dice 系数”；
///   * 只有置信度足够且唯一（或明显领先第二名）时才算命中，
///     否则即使搜索结果只有一个也返回 null——绝不把“爱娘”匹配成
///     “484413”这种名字完全不对的条目。
library;

import 'background_service.dart';

class BangumiTitleMatcher {
  /// 低于此分数视为不相关。
  static const double minScore = 0.60;

  /// 高于此分数且明显领先第二名时可接受。
  static const double strongScore = 0.85;

  /// 从候选中选出唯一可信匹配；不够确定返回 null。
  static BangumiImageCandidate? pickBest(
    List<BangumiImageCandidate> candidates,
    String query,
  ) {
    if (candidates.isEmpty) return null;
    final scored = <(BangumiImageCandidate, double)>[
      for (final c in candidates) (c, _scoreForCandidate(c, query)),
    ];
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final best = scored.first;
    if (best.$2 < minScore) return null;
    // 第二名若仍达到最低分且差距不足 0.12，视为歧义，宁可放弃。
    if (scored.length > 1) {
      final second = scored[1];
      if (second.$2 >= minScore && best.$2 - second.$2 < 0.12) {
        return null;
      }
    }
    return best.$1;
  }

  static double _scoreForCandidate(
    BangumiImageCandidate candidate,
    String query,
  ) {
    var best = 0.0;
    for (final title in [candidate.name, candidate.nameCn, candidate.title]) {
      if (title != null && title.isNotEmpty) {
        final s = score(query, title);
        if (s > best) best = s;
      }
    }
    return best;
  }

  /// 归一化：小写、去空白/标点，只保留中日韩、拉丁字母与数字。
  static String normalizeForMatch(String s) {
    final t = s.trim().toLowerCase();
    // 去掉方括号/圆括号中的发行信息，保留主体标题。
    final cleaned = t
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ');
    return cleaned.replaceAll(
      RegExp(r'[^a-z0-9\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af]+'),
      '',
    );
  }

  /// 0..1 相似度。
  static double score(String a, String b) {
    final na = normalizeForMatch(a);
    final nb = normalizeForMatch(b);
    if (na.isEmpty || nb.isEmpty) return 0;
    if (na == nb) return 1.0;

    // 包含关系：短串长度 >= 3 视为强信号。
    if (na.contains(nb) || nb.contains(na)) {
      final short = na.length < nb.length ? na : nb;
      if (short.length >= 3) return 0.95;
    }

    final gramsA = _bigrams(na);
    final gramsB = _bigrams(nb);
    if (gramsA.isEmpty || gramsB.isEmpty) return 0;
    final inter = gramsA.intersection(gramsB).length;
    final dice = 2.0 * inter / (gramsA.length + gramsB.length);
    return dice;
  }

  static Set<String> _bigrams(String s) {
    if (s.length < 2) return s.isEmpty ? {} : {s};
    final out = <String>{};
    for (var i = 0; i + 2 <= s.length; i++) {
      out.add(s.substring(i, i + 2));
    }
    return out;
  }
}
