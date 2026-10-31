/// 卡片合并选择器：搜索源卡 → 预览 → 二次确认。
library;

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../theme.dart';

Future<Game?> showGameMergeDialog(
  BuildContext context, {
  required Game target,
  required List<Game> candidates,
}) {
  return showDialog<Game>(
    context: context,
    builder: (_) => _GameMergeDialog(target: target, candidates: candidates),
  );
}

class _GameMergeDialog extends StatefulWidget {
  const _GameMergeDialog({required this.target, required this.candidates});

  final Game target;
  final List<Game> candidates;

  @override
  State<_GameMergeDialog> createState() => _GameMergeDialogState();
}

class _GameMergeDialogState extends State<_GameMergeDialog> {
  final _searchCtrl = TextEditingController();
  Game? _selected;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Game> get _visible {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return widget.candidates;
    return widget.candidates
        .where(
          (g) =>
              g.title.toLowerCase().contains(query) ||
              g.exePath.toLowerCase().contains(query),
        )
        .toList(growable: false);
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
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _selected == null ? _buildPicker() : _buildPreview(),
        ),
      ),
    );
  }

  Widget _buildPicker() {
    final list = _visible;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '合并其他游戏',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '选择要并入当前卡片的游戏。合并后源卡会被移除。',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: '搜索游戏名称或路径…',
            prefixIcon: Icon(Icons.search, size: 18),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '没有可合并的其他游戏',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (context, i) {
                final game = list[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.videogame_asset_outlined,
                    size: 20,
                  ),
                  title: Text(
                    game.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    game.exePath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () => setState(() => _selected = game),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final source = _selected!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '确认合并',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '将《${source.title}》合并到《${widget.target.title}》',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        const SizedBox(height: 10),
        _line(
          '累计时长',
          '${widget.target.totalPlaySeconds + source.totalPlaySeconds} 秒',
        ),
        _line('启动次数', '${widget.target.launchCount + source.launchCount} 次'),
        _line('游玩记录', '源卡的会话将迁移到目标卡'),
        _line('跟踪 EXE', '源卡主程序与别名将加入目标卡'),
        const SizedBox(height: 10),
        const Text(
          '源卡的标题、图标、背景、文件夹与启动配置将被移除。此操作不可撤销。',
          style: TextStyle(color: AppColors.error, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _selected = null),
              child: const Text('返回'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, source),
              child: const Text('合并'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
