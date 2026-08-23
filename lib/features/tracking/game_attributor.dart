/// 前台游戏归因器：在精确 exePath 命中失败后，用补充信号把包装壳
/// （Enigma Virtual Box 等单文件壳）的临时 stub 进程归因到库内游戏。
///
/// 匹配顺序（全部保守，绝不猜测）：
///   1. 精确命令：imagePath == Games.exePath（O(1)）；
///   2. 包装壳候选（imagePath 位于 %TEMP% 等临时目录）时，
///      用前台进程的 **命令行** 与库内 exe 的“核心名”做版本/补丁后缀容错匹配；
///   3. 若命令行仍无法唯一收敛，再以窗口标题 / 目录名做唯一精确匹配兜底。
///
/// 任何一步出现多个候选都返回 null（宁可漏报，不误报）。
library;

import '../../core/database/app_database.dart';

/// 归因用的轻量索引条目（纯数据，便于单元测试）。
class GameMatchEntry {
  const GameMatchEntry({
    required this.gameId,
    required this.exeStem,
    required this.title,
    required this.dirStem,
  });

  final int gameId;

  /// 标准化后的 exe 主名（去掉 .exe、统一小写）。
  final String exeStem;

  /// 标准化后的库内标题。
  final String title;

  /// 标准化后的目录名（兜底标题匹配用）。
  final String dirStem;
}

class GameAttributor {
  final Map<String, int> _exeIndex = {};
  final List<GameMatchEntry> _entries = [];

  /// 库变化时重建索引（与 TrackingEngine.rebuildIndex 同频）。
  void rebuild(List<Game> games) {
    _exeIndex
      ..clear()
      ..addEntries(games.map((g) => MapEntry(g.exePath, g.id)));
    _entries
      ..clear()
      ..addAll(
        games.map((g) {
          return GameMatchEntry(
            gameId: g.id,
            exeStem: _exeStem(g.exePath),
            title: _normalizeText(g.title),
            dirStem: _normalizeText(_basename(g.dirPath)),
          );
        }),
      );
  }

  /// 把 watcher 上报的前台快照归因到一个 gameId；无法唯一确定时返回 null。
  int? resolve({
    required String? imagePath,
    required String? commandLine,
    required String windowTitle,
    required bool visible,
  }) {
    final path = imagePath;
    if (!visible || path == null) return null;

    // 1) 精确命中：游戏 exePath 与前台进程镜像路径一致（常规游戏）。
    final exact = _exeIndex[path];
    if (exact != null) return exact;

    // 2) 仅对“包装壳候选”（前台进程位于临时目录）做补充归因，
    //    避免把浏览器/文件管理器等普通前台窗口误判成游戏。
    if (!_isWrapperCandidate(path)) return null;

    final candidates = <int>{};
    final cl = commandLine?.trim() ?? '';
    if (cl.isNotEmpty) {
      final stem = _commandStem(cl);
      if (stem.isNotEmpty) {
        for (final e in _entries) {
          if (_stemMatches(stem, e.exeStem)) candidates.add(e.gameId);
        }
      }
    }
    if (candidates.length == 1) return candidates.single;

    // 3) 命令行无法唯一收敛时，用标题/目录名精确匹配兜底，并要求与命令行
    //    候选不冲突（若命令行已经有多个候选，唯一标题必须落在其中才能收敛）。
    final titleNorm = _normalizeText(windowTitle);
    if (titleNorm.isNotEmpty) {
      final titleIds = <int>{};
      for (final e in _entries) {
        if (titleNorm == e.title || titleNorm == e.dirStem) {
          titleIds.add(e.gameId);
        }
      }
      if (titleIds.length == 1) {
        final id = titleIds.single;
        if (candidates.isEmpty || candidates.contains(id)) return id;
      }
    }
    return null;
  }

  // ── 纯字符串工具 ─────────────────────────────────────────────

  static String _basename(String p) => p.replaceAll('\\', '/').split('/').last;

  static String _exeStem(String path) {
    final name = _basename(path).toLowerCase();
    return name.endsWith('.exe') ? name.substring(0, name.length - 4) : name;
  }

  static String _commandStem(String commandLine) {
    final s = commandLine.trim();
    if (s.isEmpty) return '';
    final first = s.split(RegExp(r'\s+')).first.trim();
    var t = first;
    if (t.startsWith('"') && t.endsWith('"') && t.length >= 2) {
      t = t.substring(1, t.length - 1);
    }
    t = t.replaceAll('/', '\\');
    final name = t.split('\\').last.toLowerCase();
    return name.endsWith('.exe') ? name.substring(0, name.length - 4) : name;
  }

  static String _normalizeText(String s) => s.trim().toLowerCase();

  /// 包装壳候选判定：前台进程镜像位于用户/系统临时目录。
  /// EVB 等壳会把实际游戏窗口宿主放到 `%TEMP%\evbXXXX.tmp`。
  static bool _isWrapperCandidate(String imagePath) {
    final p = imagePath.toLowerCase();
    return p.contains(r'\appdata\local\temp\') ||
        p.startsWith(r'c:\windows\temp\') ||
        p.contains(r'\temp\evb');
  }

  /// exe 主名/补丁名容错匹配：核心前缀一致，剩余尾缀只允许
  /// 版本号 / 汉化补丁标记等（如 `_1.0`、`_chs`、`_cn`）。
  static bool _stemMatches(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    final String short;
    final String long;
    if (a.length <= b.length) {
      short = a;
      long = b;
    } else {
      short = b;
      long = a;
    }
    if (!long.startsWith(short)) return false;
    return _isVersionLikeSuffix(long.substring(short.length));
  }

  static bool _isVersionLikeSuffix(String suffix) {
    var t = suffix;
    while (t.startsWith('_') || t.startsWith('-') || t.startsWith('.')) {
      t = t.substring(1);
    }
    if (t.isEmpty) return true;
    if (t.length > 12) return false;
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(t)) return false;
    if (RegExp(r'[0-9]').hasMatch(t)) return true;
    const known = {
      'chs',
      'cn',
      'sc',
      'tc',
      'patch',
      'patched',
      'chinese',
      'han',
      'hans',
      'hant',
      'simplified',
      'traditional',
      'se',
      'remaster',
      'hd',
      'plus',
      'r',
      'rev',
      'beta',
      'alpha',
    };
    return known.contains(t);
  }
}
