/// 拖拽入库服务：扫描 + PE 解析（均在独立 Isolate）+ 决策分流。
///
/// 分流规则：
///   总候选 ≥ 2 且至少一个未入库 → 全部富化并返回待决策组；
///   单个未入库候选 → 解析图标/名称后自动录入；
///   候选全部已入库 → 报告重复；
///   候选 = 0 → 报告空目录。
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/path_normalizer.dart';
import '../../data/game_repository.dart';
import 'directory_scanner.dart';
import 'library_scanner.dart';
import 'pe_info.dart';

/// 用于决策弹窗的完整候选元数据（isolate 回传的纯数据）。
class EnrichedCandidate {
  const EnrichedCandidate({
    required this.path,
    required this.sizeBytes,
    required this.modified,
    this.description,
    this.productName,
    this.icon,
    this.alreadyAdded = false,
  });

  final String path;
  final int sizeBytes;
  final DateTime modified;
  final String? description;
  final String? productName;
  final Uint8List? icon;
  final bool alreadyAdded;
}

/// 一组扫描结果应走的入库分流路径。
enum CandidateResolution { noCandidate, duplicateOnly, autoAdd, chooseMainExe }

/// 以总候选、新候选与重复候选数量决定分流，便于独立测试 UI 决策触发条件。
CandidateResolution resolveCandidateGroup({
  required int totalCandidates,
  required int availableCandidates,
  required int duplicateCandidates,
}) {
  if (totalCandidates >= 2 && availableCandidates > 0) {
    return CandidateResolution.chooseMainExe;
  }
  if (availableCandidates == 1) return CandidateResolution.autoAdd;
  if (duplicateCandidates > 0) return CandidateResolution.duplicateOnly;
  return CandidateResolution.noCandidate;
}

class IngestReport {
  IngestReport({
    List<String>? added,
    List<String>? duplicatePaths,
    List<List<EnrichedCandidate>>? pendingDecisions,
    List<String>? noExePaths,
  }) : added = added ?? <String>[],
       duplicatePaths = duplicatePaths ?? <String>[],
       pendingDecisions = pendingDecisions ?? <List<EnrichedCandidate>>[],
       noExePaths = noExePaths ?? <String>[];

  /// 成功自动录入的游戏标题。
  final List<String> added;

  /// 重复（已入库）的路径。
  final List<String> duplicatePaths;

  /// 需要用户点选主程序的候选组。
  final List<List<EnrichedCandidate>> pendingDecisions;

  /// 无有效 exe 的拖入路径。
  final List<String> noExePaths;

  bool get hasAny =>
      added.isNotEmpty ||
      duplicatePaths.isNotEmpty ||
      pendingDecisions.isNotEmpty ||
      noExePaths.isNotEmpty;
}

/// 每批处理的游戏数量：控制峰值内存（图标字节用完即释放）。
const int _libraryChunkSize = 8;

/// 游戏库批量导入结果。
class LibraryImportReport {
  LibraryImportReport();

  /// 成功录入的游戏标题。
  final List<String> added = <String>[];

  /// 已在库中而按目录跳过的游戏（目录名）。
  final List<String> skippedExisting = <String>[];

  /// 未找到可用 exe 的目录名。
  final List<String> emptyDirectories = <String>[];

  /// 因多候选而自动选主程序的游戏标题（建议用户复核）。
  final List<String> autoChosenTitles = <String>[];

  /// 是否因超出上限而截断了游戏数量。
  bool truncated = false;

  int get totalSeen =>
      added.length + skippedExisting.length + emptyDirectories.length;
}

class IngestionService {
  IngestionService(this._games);

  final GameRepository _games;

  /// 拖入一批路径（目录或 exe）→ 扫描 + 富化 + 分流。
  Future<IngestReport> ingestDroppedPaths(
    List<String> paths, {
    int? folderId,
  }) async {
    final report = IngestReport();
    final existing = <String>{};
    // 全库已入库路径（去重判定）。
    for (final g in await _games.watchAll().first) {
      existing.add(g.exePath);
    }

    // 1) 扫描（独立 Isolate，含 stat）
    final groups = await Isolate.run(() {
      final out = <List<ExeCandidate>>[];
      for (final path in paths) {
        final type = FileSystemEntity.typeSync(path, followLinks: true);
        if (type == FileSystemEntityType.directory) {
          out.add(scanForGameExes(path));
        } else if (type == FileSystemEntityType.file &&
            path.toLowerCase().endsWith('.exe')) {
          out.add([fileToCandidate(path)]);
        } else {
          out.add(<ExeCandidate>[]);
        }
      }
      return out;
    });

    // 2) 汇总去重 → 批量 PE 富化（单 Isolate 批处理，摊薄 isolate 启动成本）
    final allCandidates = <ExeCandidate>[];
    for (final group in groups) {
      allCandidates.addAll(group);
    }
    // 去重只使用标准化路径作 key；保留原始文件路径及 stat 元数据，
    // 让 PE 解析、弹窗体积和修改时间都来自同一个候选对象。
    final uniqueCandidates = <String, ExeCandidate>{};
    for (final candidate in allCandidates) {
      uniqueCandidates.putIfAbsent(
        normalizeExePath(candidate.path),
        () => candidate,
      );
    }
    final candidatesToEnrich = uniqueCandidates.values.toList(growable: false);

    final enriched = candidatesToEnrich.isEmpty
        ? const <EnrichedCandidate>[]
        : await _enrich(candidatesToEnrich, existing);

    // 3) 分流
    final byNorm = <String, EnrichedCandidate>{};
    for (final e in enriched) {
      byNorm[normalizeExePath(e.path)] = e;
    }
    var cursor = 0;
    for (final group in groups) {
      final normGroup = group
          .map((c) => normalizeExePath(c.path))
          .toSet()
          .toList(growable: false);
      if (normGroup.isEmpty) {
        report.noExePaths.add(paths[cursor]);
        cursor++;
        continue;
      }
      final live = normGroup
          .where((p) => byNorm.containsKey(p))
          .map((p) => byNorm[p]!)
          .toList();
      final dups = live.where((candidate) => candidate.alreadyAdded).length;
      final available = live.length - dups;
      switch (resolveCandidateGroup(
        totalCandidates: live.length,
        availableCandidates: available,
        duplicateCandidates: dups,
      )) {
        case CandidateResolution.autoAdd:
          await _insertCandidate(live.single, report, folderId: folderId);
        case CandidateResolution.chooseMainExe:
          report.pendingDecisions.add(live);
        case CandidateResolution.duplicateOnly:
          report.duplicatePaths.add(paths[cursor]);
        case CandidateResolution.noCandidate:
          report.noExePaths.add(paths[cursor]);
      }
      cursor++;
    }
    return report;
  }

  /// 决策弹窗点选后调用。
  Future<void> addChosen(
    EnrichedCandidate c,
    IngestReport report, {
    int? folderId,
  }) => _insertCandidate(c, report, folderId: folderId);

  Future<void> _insertCandidate(
    EnrichedCandidate c,
    IngestReport report, {
    int? folderId,
  }) async {
    final title = await _insertReturningTitle(c, folderId: folderId);
    if (title == null) {
      report.duplicatePaths.add(c.path);
      return;
    }
    report.added.add(title);
  }

  /// 插入单个候选并返回标题；该 exe 已在库中时返回 null。
  Future<String?> _insertReturningTitle(
    EnrichedCandidate c, {
    int? folderId,
  }) async {
    // 符号链接解析 → 长路径 → 标准化（与运行期捕获同构）。
    String real;
    try {
      real = await File(c.path).resolveSymbolicLinks();
    } catch (_) {
      real = c.path;
    }
    final normalized = normalizeExePath(real);
    if (await _games.findByExePath(normalized) != null) return null;
    final dirPath = File(c.path).parent.path;
    final fallbackTitle = dirPath.split(Platform.pathSeparator).last;
    final title = _pickTitle(c, fallbackTitle);

    await _games.insert(
      GamesCompanion.insert(
        title: title,
        exePath: normalized,
        dirPath: dirPath,
        iconPng: c.icon == null ? const Value.absent() : Value(c.icon!),
        folderId: Value(folderId),
      ),
    );
    return title;
  }

  /// 批量导入游戏库：逐款自动选主程序、分块富化并入库。
  ///
  /// 分块（每 [_libraryChunkSize] 款一次）是刻意的内存设计：整库一次性
  /// 富化会让所有图标同时驻留内存，与「常态低占用」目标冲突。
  Future<LibraryImportReport> importLibrary(
    LibraryLayout layout, {
    int? folderId,
    void Function(int done, int total)? onProgress,
  }) async {
    final report = LibraryImportReport()..truncated = layout.truncated;
    final existing = <String>{};
    for (final g in await _games.watchAll().first) {
      existing.add(g.exePath);
    }

    final total = layout.games.length;
    var done = 0;
    void advance() {
      done++;
      onProgress?.call(done, total);
    }

    for (
      var start = 0;
      start < layout.games.length;
      start += _libraryChunkSize
    ) {
      final chunk = layout.games
          .skip(start)
          .take(_libraryChunkSize)
          .toList(growable: false);

      final pending = <(LibraryGameEntry, ExeCandidate)>[];
      for (final entry in chunk) {
        // 该游戏任一候选已入库 → 视为同一款游戏，整款跳过（避免重复卡片）。
        final alreadyAdded = entry.candidates.any(
          (c) => existing.contains(normalizeExePath(c.path)),
        );
        if (alreadyAdded) {
          report.skippedExisting.add(p.basename(entry.dirPath));
          advance();
          continue;
        }
        final chosen = entry.preferred;
        if (chosen == null) {
          report.emptyDirectories.add(p.basename(entry.dirPath));
          advance();
          continue;
        }
        pending.add((entry, chosen));
      }
      if (pending.isEmpty) continue;

      final enriched = await _enrich(
        pending.map((e) => e.$2).toList(growable: false),
        existing,
      );

      for (var i = 0; i < pending.length; i++) {
        final (entry, chosen) = pending[i];
        final title = await _insertReturningTitle(
          enriched[i],
          folderId: folderId,
        );
        if (title == null) {
          report.skippedExisting.add(p.basename(entry.dirPath));
        } else {
          report.added.add(title);
          if (entry.hasMultipleCandidates) {
            report.autoChosenTitles.add(title);
          }
        }
        advance();
      }
    }
    return report;
  }

  String _pickTitle(EnrichedCandidate c, String fallback) {
    // 不再“一刀切”按固定顺序取名字，而是给每个候选名打分：
    //   exe 主名 / 目录名 / 描述 / 产品名
    // 打分考虑：是否是中日文（更可能是游戏原标题）、是否引擎/通用词、
    // 是否与目录名一致、同一名字是否在多个字段出现（出现次数）。
    final folder = fallback.trim();
    final fileName = c.path.split(Platform.pathSeparator).last;
    final lower = fileName.toLowerCase();
    final stem = lower.endsWith('.exe')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    final d = c.description?.trim() ?? '';
    final p = c.productName?.trim() ?? '';

    final choices = <_TitleChoice>[
      _TitleChoice(stem, 0),
      _TitleChoice(folder, 1),
      _TitleChoice(d, 2),
      _TitleChoice(p, 3),
    ];
    final normLabels = choices
        .map((x) => _normalizeTitle(x.label))
        .toList(growable: false);
    for (final x in choices) {
      x.score = _scoreTitle(x.label, x.priority, folder, normLabels);
    }
    choices.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.priority.compareTo(b.priority);
    });
    final best = choices.first;
    return best.label.isNotEmpty ? best.label : folder;
  }

  double _scoreTitle(
    String label,
    int priority,
    String folder,
    List<String> normLabels,
  ) {
    final nl = _normalizeTitle(label);
    if (nl.isEmpty) return -1000;
    if (isBoilerplateTitle(label)) return -100;
    if (_isGenericTitle(label)) return -80;

    var s = 0.0;
    if (label.length <= 2) s -= 10;
    if (_hasCjk(label)) s += 30; // 中日文标题更可能是游戏原名
    if (label == folder) s += 15;
    if (priority == 1) s += 8; // 目录名作为兜底偏好
    // 出现次数：同一名字出现在多个字段（如 exe 名 == 目录名）时加分。
    final occurrences = normLabels
        .where(
          (x) => x.isNotEmpty && (x == nl || x.contains(nl) || nl.contains(x)),
        )
        .length;
    if (occurrences >= 2) s += 12;
    return s;
  }

  bool _hasCjk(String s) => RegExp(r'[぀-ヿ㐀-䶿一-鿿가-힯]').hasMatch(s);

  bool _isGenericTitle(String s) {
    final lower = s.trim().toLowerCase();
    if (lower.length <= 2) return true;
    const generic = {
      'game',
      'games',
      'galgame',
      'galgames',
      'vn',
      'visualnovel',
      'visual-novel',
      'visual_novel',
      'newfolder',
      'new folder',
      'untitled',
      'launcher',
      'launch',
      'start',
      'main',
      'app',
      'run',
      'boot',
      'loader',
      'setup',
      'install',
      'installer',
      'uninstall',
      'downloads',
      'download',
      'desktop',
      'documents',
      'folder',
      'bf',
      'acmp',
      'exe',
      'executable',
      'application',
      'program',
    };
    return generic.contains(lower);
  }

  String _normalizeTitle(String s) => s.trim().toLowerCase();

  /// 批量 PE 解析：文件 IO + 资源解析 + PNG 编码全部在一次性 isolate。
  Future<List<EnrichedCandidate>> _enrich(
    List<ExeCandidate> candidates,
    Set<String> existing,
  ) {
    return Isolate.run(() {
      return [
        for (final candidate in candidates)
          () {
            final info = parsePeFile(candidate.path);
            return EnrichedCandidate(
              path: candidate.path,
              sizeBytes: candidate.sizeBytes,
              modified: candidate.modified,
              description: info?.fileDescription,
              productName: info?.productName,
              icon: info?.iconPng,
              alreadyAdded: existing.contains(normalizeExePath(candidate.path)),
            );
          }(),
      ];
    });
  }
}

class _TitleChoice {
  _TitleChoice(this.label, this.priority);

  final String label;
  final int priority;
  double score = 0;
}
