/// 卡片设置中的「跟踪的 EXE」：主程序、别名增删与卡片合并入口。
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/path_normalizer.dart';
import '../../providers.dart';
import '../theme.dart';
import 'game_merge_dialog.dart';

class GameExeTrackingSection extends ConsumerStatefulWidget {
  const GameExeTrackingSection({super.key, required this.game, this.onMerged});

  final Game game;
  final ValueChanged<Game>? onMerged;

  @override
  ConsumerState<GameExeTrackingSection> createState() =>
      _GameExeTrackingSectionState();
}

class _GameExeTrackingSectionState
    extends ConsumerState<GameExeTrackingSection> {
  late final Stream<List<GameAlias>> _aliases = ref
      .read(aliasRepoProvider)
      .watchForGame(widget.game.id);

  void _notify(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addAlias() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['exe'],
      dialogTitle: '选择要跟踪的 EXE',
    );
    final selected = result?.files.single.path;
    if (selected == null || selected.isEmpty || !mounted) return;

    String real = selected;
    try {
      real = await File(selected).resolveSymbolicLinks();
    } catch (_) {
      real = selected;
    }
    final ownerId = await ref.read(aliasRepoProvider).ownerGameIdOf(real);
    if (!mounted) return;
    if (ownerId != null) {
      if (ownerId == widget.game.id) {
        _notify('该 exe 已在当前卡片的跟踪列表中');
      } else {
        final games = ref.read(gameListProvider).value ?? const <Game>[];
        final owner = games
            .where((g) => g.id == ownerId)
            .map((g) => g.title)
            .firstOrNull;
        _notify('该 exe 已由《${owner ?? '其他游戏'}》跟踪，可在该卡片设置中合并');
      }
      return;
    }

    final id = await ref
        .read(aliasRepoProvider)
        .addAlias(
          gameId: widget.game.id,
          exePath: real,
          dirPath: File(real).parent.path,
        );
    if (!mounted) return;
    _notify(id > 0 ? '已添加跟踪 exe' : '添加失败：该 exe 已被占用');
  }

  Future<void> _removeAlias(GameAlias alias) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除别名？'),
        content: Text('移除后，通过 ${alias.exePath} 启动的游戏将不再计入此卡片。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(aliasRepoProvider).removeAlias(alias.id);
  }

  Future<void> _merge() async {
    final games = ref.read(gameListProvider).value ?? const <Game>[];
    final candidates = games
        .where((g) => g.id != widget.game.id)
        .toList(growable: false);
    final source = await showGameMergeDialog(
      context,
      target: widget.game,
      candidates: candidates,
    );
    if (source == null || !mounted) return;

    await ref.read(trackingEngineProvider).settleActive();
    final ok = await ref
        .read(aliasRepoProvider)
        .mergeInto(targetId: widget.game.id, sourceId: source.id);
    if (!mounted) return;
    if (!ok) {
      _notify('合并失败：目标或源游戏已不存在');
      return;
    }
    widget.onMerged?.call(source);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '跟踪的 EXE',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addAlias,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加 EXE'),
            ),
            TextButton.icon(
              onPressed: _merge,
              icon: const Icon(Icons.merge_type, size: 16),
              label: const Text('合并其他游戏'),
            ),
          ],
        ),
        _row(
          label: '主程序',
          path: widget.game.exePath,
          trailing: const SizedBox(width: 28),
        ),
        StreamBuilder<List<GameAlias>>(
          stream: _aliases,
          builder: (context, snapshot) {
            final aliases = snapshot.data ?? const <GameAlias>[];
            if (aliases.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(left: 60, top: 2, bottom: 4),
                child: Text(
                  '暂无别名 exe',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              );
            }
            return Column(
              children: [
                for (final alias in aliases)
                  _row(
                    label: alias.label?.isNotEmpty == true
                        ? alias.label!
                        : '别名',
                    path: alias.exePath,
                    trailing: IconButton(
                      tooltip: '移除别名',
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => _removeAlias(alias),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _row({
    required String label,
    required String path,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Tooltip(
              message: path,
              child: Text(
                displayPath(path),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
