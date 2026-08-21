/// 启动程序决策弹窗：多候选 exe 时展示图标、体积、描述并交由用户手动点选。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../features/scanner/ingestion_service.dart';
import '../theme.dart';

class ExeDecisionDialog extends StatelessWidget {
  const ExeDecisionDialog({
    required this.candidates,
    required this.onSelected,
    super.key,
  });

  final List<EnrichedCandidate> candidates;
  final ValueChanged<EnrichedCandidate> onSelected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.alt_route, color: AppColors.accent, size: 22),
                  SizedBox(width: 10),
                  Text(
                    '选择主启动程序',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '该目录下扫描到多个可执行程序，请点选用于记录游玩时长的主程序：',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = candidates[i];
                    final fileName =
                        c.path.split(Platform.pathSeparator).last;
                    int size = 0;
                    try {
                      size = File(c.path).lengthSync();
                    } catch (_) {}
                    final sizeMb = (size / (1024 * 1024)).toStringAsFixed(1);

                    return Material(
                      color: AppColors.surfaceHover,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelected(c);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              c.icon != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.memory(
                                        c.icon!,
                                        width: 40,
                                        height: 40,
                                      ),
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceActive,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.sports_esports,
                                          color: AppColors.textMuted),
                                    ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.description?.isNotEmpty == true
                                          ? '${c.description} ($fileName)'
                                          : fileName,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${c.path} · $sizeMb MB',
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
                              const Icon(Icons.chevron_right,
                                  color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
