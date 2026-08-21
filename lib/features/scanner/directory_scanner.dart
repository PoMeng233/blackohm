/// 游戏目录递归扫描器：深度受限的 BFS + 噪声过滤 + 启发式评分。
///
/// 纯同步实现（dart:io），调用方必须包在 Isolate.run 里执行，
/// 大目录扫描不触碰 UI 线程。
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_constants.dart';

/// 扫描命中的 exe 候选（仅文件属性；PE 富化由 IngestionService 负责）。
class ExeCandidate {
  ExeCandidate({
    required this.path,
    required this.dirPath,
    required this.sizeBytes,
    required this.modified,
  });

  /// 原始大小写路径（启动用）。
  final String path;
  final String dirPath;
  final int sizeBytes;
  final DateTime modified;

  /// 启发式评分：名称吻合目录 +50，体积每 MB +1（封顶 90）。
  int get score {
    var s = 0;
    final name = path.split(Platform.pathSeparator).last.toLowerCase();
    final dir = dirPath.split(Platform.pathSeparator).last.toLowerCase();
    if (dir.isNotEmpty && name.startsWith(dir)) s += 50;
    s += sizeBytes ~/ (1024 * 1024);
    if (s > 90) s = 90;
    return s;
  }
}

/// 明确跳过的目录名（运行库/安装器聚集地）。
const Set<String> _dirBlacklist = {
  'directx',
  'dotnet',
  'vcredist',
  '_commonredist',
  'commonredist',
  'redist',
  'installer',
  'windowsinput',
  r'$recycle.bin',
  'system volume information',
};

/// 递归扫描 [rootDir] 下的游戏 exe 候选。
/// 深度限制 [maxDepth]，返回按评分降序的候选列表（可能为空）。
List<ExeCandidate> scanForGameExes(String rootDir, {int? maxDepth}) {
  final depth = maxDepth ?? kScanMaxDepth;
  final root = Directory(rootDir);
  if (!root.existsSync()) return const [];

  final candidates = <ExeCandidate>[];
  final queue = <(Directory, int)>[(root, 0)];

  while (queue.isNotEmpty) {
    final (dir, level) = queue.removeAt(0);
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false).toList(growable: false);
    } catch (_) {
      continue; // 权限不足等
    }
    if (entries.length > kScanMaxEntriesPerDir) continue;

    for (final e in entries) {
      // Directory.uri 的 pathSegments 最后会附带空元素（尾随 '/'），
      // 因此必须从 path.basename 取名，否则所有子目录都会被错误跳过。
      final name = p.basename(e.path);
      if (name.isEmpty || name == '.' || name == '..') continue;
      if (name.startsWith('.')) continue;

      if (e is Directory) {
        if (level < depth && !_dirBlacklist.contains(name.toLowerCase())) {
          queue.add((e, level + 1));
        }
      } else if (e is File && name.toLowerCase().endsWith('.exe')) {
        if (kExeBlacklist.hasMatch(name)) continue;
        try {
          final st = e.statSync();
          candidates.add(
            ExeCandidate(
              path: e.path,
              dirPath: dir.path,
              sizeBytes: st.size,
              modified: st.modified,
            ),
          );
        } catch (_) {
          /* 文件被占用等，跳过 */
        }
        if (candidates.length >= 64) {
          queue.clear();
          break; // 候选爆炸防线
        }
      }
    }
  }

  candidates.sort((a, b) => b.score.compareTo(a.score));
  return candidates;
}

/// 单个 exe 文件包装为候选（直接拖入 .exe 场景）。
ExeCandidate fileToCandidate(String exePath) {
  final f = File(exePath);
  final st = f.statSync();
  return ExeCandidate(
    path: exePath,
    dirPath: f.parent.path,
    sizeBytes: st.size,
    modified: st.modified,
  );
}
