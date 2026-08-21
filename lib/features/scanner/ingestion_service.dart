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

/// PE 富化结果（isolate 回传的纯数据）。
class EnrichedCandidate {
  EnrichedCandidate(this.path, this.description, this.productName, this.icon);

  final String path;
  final String? description;
  final String? productName;
  final Uint8List? icon;
}

class IngestReport {
  IngestReport({
    this.added = const [],
    this.duplicatePaths = const [],
    this.pendingDecisions = const [],
    this.noExePaths = const [],
  });

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
  Future<IngestReport> ingestDroppedPaths(List<String> paths) async {
    final report = IngestReport();
    final existing = <String>{};
    // 全库已入库路径（去重判定）。
    for (final g in await _games.watchAll().first) {
      existing.add(g.exePath);
    }

    // 1) 扫描（独立 Isolate，含 stat）
    final groups = await Isolate.run(() {
      final out = <List<String>>[];
      for (final p in paths) {
        final type = FileSystemEntity.typeSync(p, followLinks: true);
        if (type == FileSystemEntityType.directory) {
          final list = scanForGameExes(p)
              .map((c) => c.path)
              .toList(growable: false);
          out.add(list);
        } else if (type == FileSystemEntityType.file &&
            p.toLowerCase().endsWith('.exe')) {
          out.add([fileToCandidate(p).path]);
        } else {
          out.add(const []);
        }
      }
      return out;
    });

    // 2) 汇总去重 → 批量 PE 富化（单 Isolate 批处理，摊薄 isolate 启动成本）
    final allPaths = <String>[];
    for (final g in groups) {
      allPaths.addAll(g);
    }
    final deduped = allPaths
        .map(normalizeExePath)
        .toSet()
        .where((p) => !existing.contains(p))
        .toList();

    final enriched = deduped.isEmpty
        ? const <EnrichedCandidate>[]
        : await _enrich(deduped);

    // 3) 分流
    final byNorm = <String, EnrichedCandidate>{};
    for (final e in enriched) {
      byNorm[normalizeExePath(e.path)] = e;
    }
    var cursor = 0;
    for (final group in groups) {
      final normGroup = group.map(normalizeExePath).toList();
      if (normGroup.isEmpty) {
        report.noExePaths.add(paths[cursor]);
        cursor++;
        continue;
      }
      final live =
          normGroup.where((p) => byNorm.containsKey(p)).map((p) => byNorm[p]!).toList();
      final dups = normGroup.where((p) => existing.contains(p)).length;
      if (live.length == 1) {
        await _insertCandidate(live.first, report);
      } else if (live.length >= 2) {
        report.pendingDecisions.add(live);
      } else if (dups > 0) {
        report.duplicatePaths.add(paths[cursor]);
      } else {
        report.noExePaths.add(paths[cursor]);
      }
      cursor++;
    }
    return report;
  }

  /// 决策弹窗点选后调用。
  Future<void> addChosen(EnrichedCandidate c, IngestReport report) =>
      _insertCandidate(c, report);

  Future<void> _insertCandidate(
      EnrichedCandidate c, IngestReport report) async {
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
    final fallbackTitle =
        dirPath.split(Platform.pathSeparator).last;
    final title = _pickTitle(c, fallbackTitle);

    await _games.insert(GamesCompanion.insert(
      title: title,
      exePath: normalized,
      dirPath: dirPath,
      iconPng: c.icon == null ? const Value.absent() : Value(c.icon!),
    ));
    report.added.add(title);
  }

  String _pickTitle(EnrichedCandidate c, String fallback) {
    final d = c.description?.trim() ?? '';
    if (d.isNotEmpty) return d;
    final p = c.productName?.trim() ?? '';
    if (p.isNotEmpty) return p;
    return fallback.isEmpty ? c.path.split(Platform.pathSeparator).last : fallback;
  }

  /// 批量 PE 解析：文件 IO + 资源解析 + PNG 编码全部在一次性 isolate。
  Future<List<EnrichedCandidate>> _enrich(List<String> paths) {
    return Isolate.run(() {
      return [
        for (final p in paths)
          () {
            final info = parsePeFile(p);
            return EnrichedCandidate(
              p,
              info?.fileDescription,
              info?.productName,
              info?.iconPng,
            );
          }(),
      ];
    });
  }
}
