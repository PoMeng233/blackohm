/// 游戏库批量导入弹窗：预览 → 进度 → 汇总。
///
/// 批量场景不逐个弹「选择主程序」窗口（上百款游戏不可接受）：
/// 预览里展示每款游戏自动选中的主程序，多候选者标记提示，
/// 导入完成后列出待复核项，可在游戏详情页调整启动 exe。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../features/scanner/ingestion_service.dart';
import '../../features/scanner/library_scanner.dart';
import '../theme.dart';

class LibraryImportDialog extends StatefulWidget {
  const LibraryImportDialog({
    required this.layout,
    required this.service,
    this.folderId,
    super.key,
  });

  final LibraryLayout layout;
  final IngestionService service;
  final int? folderId;

  @override
  State<LibraryImportDialog> createState() => _LibraryImportDialogState();
}

enum _Phase { preview, running, done }

class _LibraryImportDialogState extends State<LibraryImportDialog> {
  _Phase _phase = _Phase.preview;
  int _done = 0;
  int _total = 0;
  LibraryImportReport? _report;

  Future<void> _start() async {
    final layout = widget.layout;
    setState(() {
      _phase = _Phase.running;
      _done = 0;
      _total = layout.games.length;
    });
    final report = await widget.service.importLibrary(
      layout,
      folderId: widget.folderId,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _done = done;
          _total = total;
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _phase = _Phase.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.library_add_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '批量添加游戏库',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _body(context)),
              const SizedBox(height: 12),
              _actions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (_phase) {
      case _Phase.preview:
        return _preview(context);
      case _Phase.running:
        return _running(context);
      case _Phase.done:
        return _summary(context);
    }
  }

  Widget _preview(BuildContext context) {
    final layout = widget.layout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '检测到 ${layout.games.length} 款游戏，将逐款自动选择主程序并添加；'
          '已在库中的游戏会整款跳过。',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        if (layout.truncated) ...[
          const SizedBox(height: 6),
          const Text(
            '注意：游戏数量已达本次导入上限，仅处理前若干款，可分批再次拖入。',
            style: TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceHover,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: layout.games.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) {
                final game = layout.games[i];
                final chosen = game.preferred;
                final title = game.dirPath.split(Platform.pathSeparator).last;
                final exeName = chosen == null
                    ? '未找到可执行程序'
                    : chosen.path.split(Platform.pathSeparator).last;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              exeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (game.hasMultipleCandidates)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceActive,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '多候选',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _running(BuildContext context) {
    final ratio = _total == 0 ? 0.0 : _done / _total;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LinearProgressIndicator(value: ratio),
        const SizedBox(height: 14),
        Text(
          '正在处理 $_done / $_total',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        const Text(
          '正在解析图标与标题并写入数据库，请稍候…',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final report = _report;
    if (report == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '已添加 ${report.added.length} 款 · '
          '跳过 ${report.skippedExisting.length} 款'
          '${report.emptyDirectories.isEmpty ? '' : ' · ${report.emptyDirectories.length} 个目录未找到程序'}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (report.truncated) ...[
          const SizedBox(height: 6),
          const Text(
            '本次因数量上限被截断，可分批再次拖入剩余目录。',
            style: TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        if (report.autoChosenTitles.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            '以下游戏存在多个可执行程序，已按名称与体积自动选择，可在游戏详情页调整：',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: report.autoChosenTitles.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    report.autoChosenTitles[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ] else
          const Spacer(),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_phase == _Phase.preview) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _start, child: const Text('开始添加')),
        ] else if (_phase == _Phase.done)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
      ],
    );
  }
}
