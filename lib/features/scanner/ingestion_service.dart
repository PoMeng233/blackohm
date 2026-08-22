/// 拖拽入库服务：扫描 + PE 解析（均在独立 Isolate）+ 决策分流。
///
/// 分流规则：
///   候选 = 1  → 解析图标/名称后自动录入；
///   候选 ≥ 2  → 返回待决策组，由 UI 弹出"启动程序决策弹窗"；
///   候选 = 0  → 报告空目录；
///   已入库路径 → 跳过并报告重复。
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import '../../core/path_normalizer.dart';
import '../../data/game_repository.dart';
import 'directory_scanner.dart';
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
  });

  final String path;
  final int sizeBytes;
  final DateTime modified;
  final String? description;
  final String? productName;
  final Uint8List? icon;
}

/// 一组扫描结果应走的入库分流路径。
enum CandidateResolution { noCandidate, duplicateOnly, autoAdd, chooseMainExe }

/// 仅以新候选与重复候选数量决定分流，便于独立测试 UI 决策触发条件。
CandidateResolution resolveCandidateGroup({
  required int availableCandidates,
  required int duplicateCandidates,
}) {
  if (availableCandidates >= 2) return CandidateResolution.chooseMainExe;
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
    final candidatesToEnrich = uniqueCandidates.entries
        .where((entry) => !existing.contains(entry.key))
        .map((entry) => entry.value)
        .toList(growable: false);

    final enriched = candidatesToEnrich.isEmpty
        ? const <EnrichedCandidate>[]
        : await _enrich(candidatesToEnrich);

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
      final dups = normGroup.where((p) => existing.contains(p)).length;
      switch (resolveCandidateGroup(
        availableCandidates: live.length,
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
    // 符号链接解析 → 长路径 → 标准化（与运行期捕获同构）。
    String real;
    try {
      real = await File(c.path).resolveSymbolicLinks();
    } catch (_) {
      real = c.path;
    }
    final normalized = normalizeExePath(real);
    if (await _games.findByExePath(normalized) != null) {
      report.duplicatePaths.add(c.path);
      return;
    }
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
    report.added.add(title);
  }

  String _pickTitle(EnrichedCandidate c, String fallback) {
    // KiriKiri 等引擎的 FileDescription 是内核自述（"TVP(KIRIKIRI) 2 core…"），
    // 不能当游戏名；逐级回退：描述 → 产品名 → exe 文件名 → 目录名。
    final d = c.description?.trim() ?? '';
    if (!isBoilerplateTitle(d)) return d;
    final p = c.productName?.trim() ?? '';
    if (!isBoilerplateTitle(p)) return p;

    final fileName = c.path.split(Platform.pathSeparator).last;
    final lower = fileName.toLowerCase();
    final stem = lower.endsWith('.exe')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    if (!isBoilerplateTitle(stem)) return stem;

    return fallback.isEmpty ? fileName : fallback;
  }

  /// 批量 PE 解析：文件 IO + 资源解析 + PNG 编码全部在一次性 isolate。
  Future<List<EnrichedCandidate>> _enrich(List<ExeCandidate> candidates) {
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
            );
          }(),
      ];
    });
  }
}
