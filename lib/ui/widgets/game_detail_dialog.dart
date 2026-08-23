/// 游戏详情与会话历史弹窗。
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/path_normalizer.dart';
import '../../features/background/background_service.dart';
import '../../features/tracking/session_merge.dart';
import '../../providers.dart';
import '../theme.dart';
import 'game_icon.dart';

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
  int? _folderId;
  String? _backgroundPath;
  String? _detailBackgroundPath;
  double _blurAmount = 0;
  double _requestedBlurAmount = 0;
  bool _preparingBlur = false;
  bool _backgroundBusy = false;
  late String _exePath;
  late String _exeDirPath;
  late final Stream<List<PlaySession>> _sessionsStream;

  final _backgroundCache = BackgroundCacheService();
  final _bangumiSearch = BangumiImageSearchService();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.game.title);
    _argsCtrl = TextEditingController(text: widget.game.launchArgs);
    _profileCtrl = TextEditingController(text: widget.game.leProfile);
    _useLe = widget.game.useLocaleEmulator;
    _folderId = widget.game.folderId;
    _backgroundPath = widget.game.backgroundPath;
    _detailBackgroundPath = widget.game.detailBackgroundPath;
    _blurAmount = widget.game.backgroundBlurAmount.clamp(0.0, 1.0);
    _requestedBlurAmount = _blurAmount;
    _exePath = widget.game.exePath;
    _exeDirPath = widget.game.dirPath;
    _sessionsStream = ref
        .read(sessionRepoProvider)
        .watchForGame(widget.game.id);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _argsCtrl.dispose();
    _profileCtrl.dispose();
    super.dispose();
  }

  Future<void> _prepareDetailBackground(String? sourcePath) async {
    if (sourcePath == null || sourcePath.isEmpty || _preparingBlur) return;
    setState(() => _preparingBlur = true);
    final detailPath = await _backgroundCache.createDetailBackground(
      sourcePath,
    );
    if (!mounted || detailPath == null || _backgroundPath != sourcePath) {
      if (mounted) setState(() => _preparingBlur = false);
      return;
    }
    await ref
        .read(gameRepoProvider)
        .update(
          widget.game.id,
          GamesCompanion(detailBackgroundPath: Value(detailPath)),
        );
    if (mounted) {
      setState(() {
        _detailBackgroundPath = detailPath;
        _blurAmount = _requestedBlurAmount;
        _preparingBlur = false;
      });
    }
  }

  Future<bool> _enableBlur(double value) async {
    _requestedBlurAmount = value;
    if (value <= 0) {
      if (mounted) setState(() => _blurAmount = 0);
      return true;
    }
    final path = _detailBackgroundPath;
    if (path == null || !await File(path).exists()) {
      await _prepareDetailBackground(_backgroundPath);
      final prepared = _detailBackgroundPath;
      if (prepared == null || !await File(prepared).exists()) {
        if (mounted) setState(() => _blurAmount = 0);
        return false;
      }
    }
    if (mounted) setState(() => _blurAmount = value);
    return true;
  }

  Future<void> _commitBlurAmount(double value) async {
    final ready = await _enableBlur(value);
    if (ready) {
      await _saveBlurAmount(value);
    }
  }

  Future<void> _saveBlurAmount(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    await ref
        .read(gameRepoProvider)
        .update(
          widget.game.id,
          GamesCompanion(backgroundBlurAmount: Value(clamped)),
        );
  }

  Future<void> _chooseLocalBackground() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: '选择背景图片',
      type: FileType.image,
    );
    final source = result?.files.single.path;
    if (source == null || !mounted) return;
    setState(() => _backgroundBusy = true);
    final cached = await _backgroundCache.copyLocal(source);
    if (!mounted) return;
    if (cached == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片格式不支持或文件超过 12 MB')));
    } else {
      final oldBackgroundPath = _backgroundPath;
      final oldDetailPath = _detailBackgroundPath;
      await _backgroundCache.delete(oldBackgroundPath);
      await _backgroundCache.delete(oldDetailPath);
      await ref
          .read(gameRepoProvider)
          .update(
            widget.game.id,
            GamesCompanion(
              backgroundPath: Value(cached),
              detailBackgroundPath: const Value(null),
              backgroundBlurAmount: const Value(0.0),
            ),
          );
      setState(() {
        _backgroundPath = cached;
        _detailBackgroundPath = null;
        _blurAmount = 0;
        _requestedBlurAmount = 0;
      });
    }
    if (mounted) setState(() => _backgroundBusy = false);
  }

  Future<void> _clearBackground() async {
    await _backgroundCache.delete(_backgroundPath);
    await _backgroundCache.delete(_detailBackgroundPath);
    await ref
        .read(gameRepoProvider)
        .update(
          widget.game.id,
          const GamesCompanion(
            backgroundPath: Value(null),
            detailBackgroundPath: Value(null),
            backgroundBlurAmount: Value(0.0),
          ),
        );
    if (mounted) {
      setState(() {
        _backgroundPath = null;
        _detailBackgroundPath = null;
      });
    }
  }

  Future<void> _searchBangumi() async {
    final token = ref.read(settingsProvider).bangumiToken;
    if (token.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中填写 Bangumi API Token')),
      );
      return;
    }
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var value = normalizeBangumiSearchQuery(_titleCtrl.text);
        return AlertDialog(
          title: const Text('搜索 Bangumi 游戏封面'),
          content: TextField(
            autofocus: true,
            controller: TextEditingController(text: value),
            decoration: const InputDecoration(
              labelText: '搜索关键词或 Bangumi 游戏链接',
              helperText: '支持 bgm.tv / bangumi.tv / chii.in 的 Subject 链接',
            ),
            onChanged: (next) => value = next,
            onSubmitted: (_) => Navigator.pop(dialogContext, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, value.trim()),
              child: const Text('搜索'),
            ),
          ],
        );
      },
    );
    if (query == null || query.trim().isEmpty || !mounted) return;
    setState(() => _backgroundBusy = true);
    final subjectId = parseBangumiSubjectId(query);
    final candidates = subjectId == null
        ? await _bangumiSearch.search(query: query, token: token)
        : switch (await _bangumiSearch.fetchSubject(
            subjectId: subjectId,
            token: token,
          )) {
            final candidate? => [candidate],
            null => const <BangumiImageCandidate>[],
          };
    if (!mounted) return;
    setState(() => _backgroundBusy = false);
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            subjectId == null
                ? '没有找到可用的 Bangumi 图片候选'
                : '该 Bangumi 游戏链接未找到可用封面或不是游戏条目',
          ),
        ),
      );
      return;
    }
    final chosen = await showDialog<BangumiImageCandidate>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择 Bangumi 背景'),
        children: candidates
            .map(
              (candidate) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, candidate),
                child: Row(
                  children: [
                    Image.network(
                      candidate.imageUrl,
                      width: 48,
                      height: 64,
                      fit: BoxFit.cover,
                      cacheWidth: 96,
                      cacheHeight: 128,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        candidate.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _backgroundBusy = true);
    final cached = await _backgroundCache.download(chosen.imageUrl);
    if (!mounted) return;
    if (cached == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片下载失败或格式不受支持')));
    } else {
      final oldBackgroundPath = _backgroundPath;
      final oldDetailPath = _detailBackgroundPath;
      await _backgroundCache.delete(oldBackgroundPath);
      await _backgroundCache.delete(oldDetailPath);
      await ref
          .read(gameRepoProvider)
          .update(
            widget.game.id,
            GamesCompanion(
              backgroundPath: Value(cached),
              detailBackgroundPath: const Value(null),
              backgroundBlurAmount: const Value(0.0),
            ),
          );
      setState(() {
        _backgroundPath = cached;
        _detailBackgroundPath = null;
        _blurAmount = 0;
        _requestedBlurAmount = 0;
      });
    }
    if (mounted) setState(() => _backgroundBusy = false);
  }

  Future<void> _save() async {
    final repo = ref.read(gameRepoProvider);
    await repo.update(
      widget.game.id,
      GamesCompanion(
        title: Value(_titleCtrl.text.trim()),
        exePath: Value(normalizeExePath(_exePath)),
        dirPath: Value(_exeDirPath),
        launchArgs: Value(_argsCtrl.text.trim()),
        useLocaleEmulator: Value(_useLe),
        leProfile: Value(_profileCtrl.text.trim()),
        folderId: Value(_folderId),
        backgroundPath: Value(_backgroundPath),
        backgroundBlurAmount: Value(_blurAmount.clamp(0.0, 1.0)),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickLaunchExe() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['exe'],
      dialogTitle: '选择启动程序 (exe)',
    );
    final selectedPath = result?.files.single.path;
    if (selectedPath == null || selectedPath.isEmpty || !mounted) return;

    String real = selectedPath;
    try {
      real = await File(selectedPath).resolveSymbolicLinks();
    } catch (_) {}
    final normalized = normalizeExePath(real);
    final existing = await ref.read(gameRepoProvider).findByExePath(normalized);
    if (!mounted) return;
    if (existing != null && existing.id != widget.game.id) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该 exe 已被其他游戏占用，不能切换')));
      return;
    }
    setState(() {
      _exePath = real;
      _exeDirPath = File(real).parent.path;
    });
  }

  Widget _metadataChips() {
    final score = widget.game.bangumiScore;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Chip(
          avatar: const Icon(Icons.timer_outlined, size: 15),
          label: Text(
            '总时长 ${formatPlayDuration(widget.game.totalPlaySeconds)}',
          ),
          visualDensity: VisualDensity.compact,
        ),
        Chip(
          avatar: const Icon(Icons.rocket_launch_outlined, size: 15),
          label: Text('启动 ${widget.game.launchCount} 次'),
          visualDensity: VisualDensity.compact,
        ),
        if (score != null)
          Chip(
            avatar: const Icon(Icons.star_rate_rounded, size: 15),
            label: Text('Bangumi ${score.toStringAsFixed(1)}'),
            visualDensity: VisualDensity.compact,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
      ],
    );
  }

  Widget _exeSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '启动程序 exe',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  displayPath(_exePath),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _pickLaunchExe,
            child: const Text('更换'),
          ),
        ],
      ),
    );
  }

  Widget _backgroundSection() {
    final path = _backgroundPath;
    final hasBackground = path != null && File(path).existsSync();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 58,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
            child: hasBackground
                ? Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: 240,
                    cacheHeight: 116,
                  )
                : const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: AppColors.textMuted,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _backgroundBusy ? null : _chooseLocalBackground,
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('本地图片'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _backgroundBusy ? null : _searchBangumi,
                  icon: const Icon(Icons.travel_explore_rounded, size: 16),
                  label: const Text('BGM 搜索 / 链接'),
                ),
                if (hasBackground)
                  TextButton.icon(
                    onPressed: _backgroundBusy ? null : _clearBackground,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('清除'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sourcePath = _backgroundPath;
              final detailPath = _detailBackgroundPath;
              final hasSource =
                  sourcePath != null && File(sourcePath).existsSync();
              final hasDetail =
                  detailPath != null && File(detailPath).existsSync();
              final pixelRatio = MediaQuery.devicePixelRatioOf(context);
              final cacheWidth = (constraints.maxWidth * pixelRatio * 1.15)
                  .round()
                  .clamp(1, 1240);
              final cacheHeight = (constraints.maxHeight * pixelRatio * 1.15)
                  .round()
                  .clamp(1, 1200);
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (hasSource)
                    Transform.scale(
                      scale: 1.12,
                      child: Image.file(
                        File(sourcePath),
                        fit: BoxFit.cover,
                        cacheWidth: cacheWidth,
                        cacheHeight: cacheHeight,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  if (hasDetail && _blurAmount > 0)
                    Positioned.fill(
                      child: Opacity(
                        opacity: _blurAmount,
                        child: Transform.scale(
                          scale: 1.12,
                          child: Image.file(
                            File(detailPath),
                            fit: BoxFit.cover,
                            cacheWidth: cacheWidth,
                            cacheHeight: cacheHeight,
                            filterQuality: FilterQuality.low,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  if (hasSource)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x660D0F12),
                            Color(0xD90D0F12),
                            AppColors.bgDark,
                          ],
                          stops: [0.0, 0.48, 0.76],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GameIcon(
                                gameId: widget.game.id,
                                size: 44,
                                radius: 8,
                                iconSize: 24,
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
                                    const SizedBox(height: 6),
                                    _metadataChips(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: '游戏名称',
                            ),
                          ),
                          const SizedBox(height: 10),
                          ref
                              .watch(folderListProvider)
                              .when(
                                data: (folders) =>
                                    DropdownButtonFormField<int?>(
                                      initialValue: _folderId,
                                      decoration: const InputDecoration(
                                        labelText: '所属文件夹',
                                      ),
                                      items: [
                                        const DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text('未分类 (无文件夹)'),
                                        ),
                                        ...folders.map(
                                          (f) => DropdownMenuItem<int?>(
                                            value: f.id,
                                            child: Text(f.name),
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) =>
                                          setState(() => _folderId = val),
                                    ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, _) => const SizedBox.shrink(),
                              ),
                          const SizedBox(height: 10),
                          _exeSection(),
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
                                activeColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                                onChanged: (v) =>
                                    setState(() => _useLe = v ?? false),
                              ),
                              const Text(
                                '使用 Locale Emulator 转区启动',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
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
                          _backgroundSection(),
                          if (_backgroundPath != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text(
                                  '背景模糊',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _blurAmount,
                                    onChanged: _preparingBlur
                                        ? null
                                        : (value) => setState(
                                            () => _blurAmount = value,
                                          ),
                                    onChangeEnd: _preparingBlur
                                        ? null
                                        : (value) {
                                            _requestedBlurAmount = value;
                                            unawaited(_commitBlurAmount(value));
                                          },
                                  ),
                                ),
                                SizedBox(
                                  width: 34,
                                  child: Text(
                                    '${(_blurAmount * 100).round()}%',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_preparingBlur)
                              const Padding(
                                padding: EdgeInsets.only(left: 52),
                                child: Text(
                                  '正在准备模糊背景…',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 6),
                          const Text(
                            '游玩历史记录',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 200,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHover,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: StreamBuilder<List<PlaySession>>(
                                stream: _sessionsStream,
                                builder: (context, snapshot) {
                                  final list = mergeSessions(
                                    snapshot.data ?? const [],
                                  );
                                  if (list.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        '暂无游玩记录',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }
                                  return ListView.separated(
                                    itemCount: list.length,
                                    separatorBuilder: (_, _) => const Divider(
                                      height: 1,
                                      color: AppColors.border,
                                    ),
                                    itemBuilder: (_, i) {
                                      final s = list[i];
                                      final dateStr =
                                          '${s.startedAt.year}-${s.startedAt.month.toString().padLeft(2, '0')}-${s.startedAt.day.toString().padLeft(2, '0')} ${s.startedAt.hour.toString().padLeft(2, '0')}:${s.startedAt.minute.toString().padLeft(2, '0')}';
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              dateStr,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              formatPlayDuration(
                                                s.durationSeconds,
                                              ),
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
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
                                child: const Text(
                                  '取消',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                                onPressed: _save,
                                child: const Text(
                                  '保存修改',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
