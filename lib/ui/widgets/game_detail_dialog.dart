/// 游戏详情与会话历史弹窗。
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../providers.dart';
import '../theme.dart';

class GameDetailDialog extends ConsumerStatefulWidget {
  const GameDetailDialog({required this.game, super.key});

  final Game game;

  @override
  ConsumerState<GameDetailDialog> createState() => _GameDetailDialogState();
}

class _GameDetailDialogState extends ConsumerState<GameDetailDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _argsCtrl;
  late final TextEditingController _profileCtrl;
  late bool _useLe;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.game.title);
    _argsCtrl = TextEditingController(text: widget.game.launchArgs);
    _profileCtrl = TextEditingController(text: widget.game.leProfile);
    _useLe = widget.game.useLocaleEmulator;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _argsCtrl.dispose();
    _profileCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(gameRepoProvider);
    await repo.update(
      widget.game.id,
      GamesCompanion(
        title: Value(_titleCtrl.text.trim()),
        launchArgs: Value(_argsCtrl.text.trim()),
        useLocaleEmulator: Value(_useLe),
        leProfile: Value(_profileCtrl.text.trim()),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsStream =
        ref.watch(sessionRepoProvider).watchForGame(widget.game.id);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  widget.game.iconPng != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(widget.game.iconPng!,
                              width: 44, height: 44),
                        )
                      : Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceActive,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.videogame_asset,
                              color: AppColors.textMuted),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.game.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '总时长：${formatPlayDuration(widget.game.totalPlaySeconds)}',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '游戏名称'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _argsCtrl,
                decoration: const InputDecoration(
                  labelText: '附加启动参数',
                  hintText: '-windowed -novsync',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _useLe,
                    activeColor: AppColors.leBadge,
                    onChanged: (v) => setState(() => _useLe = v ?? false),
                  ),
                  const Text('使用 Locale Emulator 转区启动',
                      style: TextStyle(color: AppColors.textPrimary)),
                ],
              ),
              if (_useLe)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: TextField(
                    controller: _profileCtrl,
                    decoration: const InputDecoration(
                      labelText: 'LE Profile 名 / GUID（留空使用全局默认）',
                      hintText: 'Japan',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                '游玩历史记录',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: StreamBuilder<List<PlaySession>>(
                    stream: sessionsStream,
                    builder: (context, snapshot) {
                      final list = snapshot.data ?? const [];
                      if (list.isEmpty) {
                        return const Center(
                          child: Text('暂无游玩记录',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        );
                      }
                      return ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (_, i) {
                          final s = list[i];
                          final dateStr =
                              '${s.startedAt.year}-${s.startedAt.month.toString().padLeft(2, '0')}-${s.startedAt.day.toString().padLeft(2, '0')} ${s.startedAt.hour.toString().padLeft(2, '0')}:${s.startedAt.minute.toString().padLeft(2, '0')}';
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Text(dateStr,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                                const Spacer(),
                                Text(
                                  formatPlayDuration(s.durationSeconds),
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.bgDark,
                    ),
                    onPressed: _save,
                    child: const Text('保存修改',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
