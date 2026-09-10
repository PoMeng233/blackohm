/// 游戏库批量导入的目录判定与逐款分组。
///
/// 现有单游戏流程把「拖入的目录」整体当作一款游戏：若拖入的是库根目录
/// （内含上百个游戏文件夹），会被误判为一款游戏，并受单目录候选数量上限
/// 截断。这里提供独立判定：
///   顶层无 exe，且 ≥2 个直接子目录各自含 exe → 视为游戏库。
/// 顶层含 exe 时保持单游戏流程，避免把「游戏目录里带了安装器」误判成库。
library;

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'directory_scanner.dart';

/// 库中的一款游戏：所在目录 + 按评分降序的候选 exe。
class LibraryGameEntry {
  const LibraryGameEntry({required this.dirPath, required this.candidates});

  final String dirPath;
  final List<ExeCandidate> candidates;

  /// 评分最高的候选（批量导入时自动采用）。
  ExeCandidate? get preferred => candidates.isEmpty ? null : candidates.first;

  /// 是否存在多个候选（需要用户留意主程序选择）。
  bool get hasMultipleCandidates => candidates.length > 1;
}

/// 库判定结果。
class LibraryLayout {
  const LibraryLayout({
    required this.isLibrary,
    required this.games,
    required this.truncated,
  });

  const LibraryLayout.singleGame()
    : isLibrary = false,
      games = const <LibraryGameEntry>[],
      truncated = false;

  final bool isLibrary;
  final List<LibraryGameEntry> games;
  final bool truncated;
}

/// 探测 exe 时向下搜索的最大层数（覆盖 `Game/bin/game.exe` 这类布局）。
const int _probeDepth = 2;

/// 判定 [rootDir] 是否为游戏库，并列出每款游戏的候选 exe。
LibraryLayout detectLibraryLayout(String rootDir, {int maxGames = 1000}) {
  final root = Directory(rootDir);
  if (!root.existsSync()) return const LibraryLayout.singleGame();

  // 顶层自身含 exe → 按单款游戏处理，避免把游戏目录里的安装器误判成库。
  if (scanForGameExes(rootDir, maxDepth: 0).isNotEmpty) {
    return const LibraryLayout.singleGame();
  }

  final List<FileSystemEntity> entries;
  try {
    entries = root.listSync(followLinks: false);
  } catch (_) {
    return const LibraryLayout.singleGame();
  }

  final gameFolders = <String>[];
  for (final entity in entries) {
    if (entity is! Directory) continue;
    final name = p.basename(entity.path);
    if (name.isEmpty || name.startsWith('.')) continue;
    if (isIgnoredDirectoryName(name)) continue;
    if (_containsExecutable(entity, _probeDepth)) {
      gameFolders.add(entity.path);
    }
  }

  if (gameFolders.length < 2) return const LibraryLayout.singleGame();

  gameFolders.sort();
  final truncated = gameFolders.length > maxGames;
  final selected = truncated ? gameFolders.sublist(0, maxGames) : gameFolders;

  final games = <LibraryGameEntry>[];
  for (final dir in selected) {
    final candidates = scanForGameExes(dir, maxDepth: 1);
    if (candidates.isEmpty) continue;
    games.add(LibraryGameEntry(dirPath: dir, candidates: candidates));
  }
  // 分组后仍不足两款时退回单游戏流程。
  if (games.length < 2) return const LibraryLayout.singleGame();
  return LibraryLayout(isLibrary: true, games: games, truncated: truncated);
}

/// 在独立 isolate 中判定库布局，避免大目录扫描阻塞 UI 线程。
Future<LibraryLayout> detectLibraryLayoutInIsolate(
  String rootDir, {
  int maxGames = 1000,
}) => Isolate.run(() => detectLibraryLayout(rootDir, maxGames: maxGames));

/// 浅层探测目录内是否存在 exe（找到即返回，避免整树遍历）。
bool _containsExecutable(Directory dir, int depth) {
  final queue = <(Directory, int)>[(dir, 0)];
  while (queue.isNotEmpty) {
    final (current, level) = queue.removeAt(0);
    final List<FileSystemEntity> entries;
    try {
      entries = current.listSync(followLinks: false);
    } catch (_) {
      continue; // 权限不足等，跳过
    }
    for (final entity in entries) {
      final name = p.basename(entity.path);
      if (name.isEmpty || name.startsWith('.')) continue;
      if (entity is File) {
        if (name.toLowerCase().endsWith('.exe')) return true;
      } else if (entity is Directory) {
        if (level < depth && !isIgnoredDirectoryName(name)) {
          queue.add((entity, level + 1));
        }
      }
    }
  }
  return false;
}
