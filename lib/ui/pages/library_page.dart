/// 游戏库视图：支持搜索、网格/列表双视图、收藏过滤、直启与详情。
library;

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../features/launcher/launch_service.dart';
import '../../features/scanner/ingestion_service.dart';
import '../../providers.dart';
import '../theme.dart';
import '../widgets/exe_decision_dialog.dart';
import '../widgets/game_card.dart';
import '../widgets/game_detail_dialog.dart';

enum LibraryViewMode { grid, list }

enum LibrarySort { recent, title, totalTime, createdAt, favorite }

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  LibraryViewMode _viewMode = LibraryViewMode.grid;
  LibrarySort _sort = LibrarySort.recent;
  bool _onlyFavorites = false;
  String _searchQuery = '';
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchGame(Game game, LaunchService launcher) async {
    final ok = await launcher.launch(game, ref.read(settingsProvider));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('运行文件失败，请检查路径或 Locale Emulator 配置')),
      );
    }
  }

  Future<void> _openGameDirectory(Game game, LaunchService launcher) async {
    final ok = await launcher.openGameDirectory(game);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('游戏目录不存在或无法打开')));
    }
  }

  Future<void> _addGame() async {
    if (_adding) return;
    final source = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('添加游戏'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'directory'),
            child: const ListTile(
              leading: Icon(Icons.folder_open_rounded),
              title: Text('扫描游戏目录'),
              subtitle: Text('递归查找 exe 并过滤安装器'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'file'),
            child: const ListTile(
              leading: Icon(Icons.play_circle_outline_rounded),
              title: Text('选择运行文件'),
              subtitle: Text('直接选择一个 .exe 入库'),
            ),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    String? path;
    if (source == 'directory') {
      path = await FilePicker.getDirectoryPath(dialogTitle: '选择游戏目录');
    } else {
      final result = await FilePicker.pickFiles(
        dialogTitle: '选择游戏运行文件',
        type: FileType.custom,
        allowedExtensions: ['exe'],
      );
      path = result?.files.single.path;
    }
    if (path == null || !mounted) return;
    setState(() => _adding = true);
    try {
      final service = IngestionService(ref.read(gameRepoProvider));
      final report = await service.ingestDroppedPaths([path]);
      if (!mounted) return;
      for (final candidates in report.pendingDecisions) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ExeDecisionDialog(
            candidates: candidates,
            onSelected: (candidate) => service.addChosen(candidate, report),
          ),
        );
      }
      if (!mounted) return;
      final message = report.added.isNotEmpty
          ? '已添加 ${report.added.length} 款游戏'
          : report.pendingDecisions.isNotEmpty
          ? '请选择主运行文件'
          : report.duplicatePaths.isNotEmpty
          ? '该游戏已经在库中'
          : '未找到有效的游戏运行文件';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gameListProvider);
    final activeState =
        ref.watch(trackingStateProvider).value ??
        ref.watch(trackingEngineProvider).current;
    final launcher = LaunchService();

    return Column(
      children: [
        // 顶部工具栏：搜索 + 收藏过滤 + 网格/列表切换
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: '搜索游戏名称或路径...',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: _searchCtrl.clear,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButtonHideUnderline(
                child: DropdownButton<LibrarySort>(
                  value: _sort,
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: AppColors.surfaceActive,
                  onChanged: (value) {
                    if (value != null) setState(() => _sort = value);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: LibrarySort.recent,
                      child: Text('最近游玩'),
                    ),
                    DropdownMenuItem(
                      value: LibrarySort.title,
                      child: Text('名称 A-Z'),
                    ),
                    DropdownMenuItem(
                      value: LibrarySort.totalTime,
                      child: Text('累计时长'),
                    ),
                    DropdownMenuItem(
                      value: LibrarySort.createdAt,
                      child: Text('添加时间'),
                    ),
                    DropdownMenuItem(
                      value: LibrarySort.favorite,
                      child: Text('收藏优先'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _onlyFavorites ? '显示全部' : '仅看收藏',
                icon: Icon(
                  _onlyFavorites ? Icons.star : Icons.star_border,
                  color: _onlyFavorites
                      ? Colors.amber
                      : AppColors.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _onlyFavorites = !_onlyFavorites),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _adding ? null : _addGame,
                icon: _adding
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded, size: 17),
                label: const Text('添加游戏'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<LibraryViewMode>(
                segments: const [
                  ButtonSegment(
                    value: LibraryViewMode.grid,
                    icon: Icon(Icons.grid_view, size: 16),
                  ),
                  ButtonSegment(
                    value: LibraryViewMode.list,
                    icon: Icon(Icons.view_list, size: 16),
                  ),
                ],
                selected: {_viewMode},
                onSelectionChanged: (s) => setState(() => _viewMode = s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
        // 游戏库内容区
        Expanded(
          child: gamesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                '加载失败：$e',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            data: (games) {
              var filtered = games.where((g) {
                if (_onlyFavorites && !g.favorite) return false;
                if (_searchQuery.isEmpty) return true;
                return g.title.toLowerCase().contains(_searchQuery) ||
                    g.exePath.contains(_searchQuery);
              }).toList();

              filtered.sort((a, b) {
                switch (_sort) {
                  case LibrarySort.title:
                    return a.title.toLowerCase().compareTo(
                      b.title.toLowerCase(),
                    );
                  case LibrarySort.totalTime:
                    return b.totalPlaySeconds.compareTo(a.totalPlaySeconds);
                  case LibrarySort.createdAt:
                    return b.createdAt.compareTo(a.createdAt);
                  case LibrarySort.favorite:
                    if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
                    return a.title.compareTo(b.title);
                  case LibrarySort.recent:
                    final aTime =
                        a.lastPlayedAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final bTime =
                        b.lastPlayedAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final result = bTime.compareTo(aTime);
                    if (result != 0) return result;
                    if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
                    return a.title.compareTo(b.title);
                }
              });

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_stories,
                        size: 56,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? '未找到匹配的游戏'
                            : '游戏库为空，请将游戏目录或 exe 拖入此处',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _adding ? null : _addGame,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('添加游戏'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              if (_viewMode == LibraryViewMode.grid) {
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisExtent: 190,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final g = filtered[i];
                    return RepaintBoundary(
                      child: GameCard(
                        game: g,
                        activeState: activeState,
                        onLaunch: () => _launchGame(g, launcher),
                        onOpenDirectory: () => _openGameDirectory(g, launcher),
                        onOpenDetail: () => showDialog<void>(
                          context: context,
                          builder: (_) => GameDetailDialog(game: g),
                        ),
                        onDelete: () => ref.read(gameRepoProvider).delete(g.id),
                        onToggleFavorite: () => ref
                            .read(gameRepoProvider)
                            .update(
                              g.id,
                              GamesCompanion(favorite: Value(!g.favorite)),
                            ),
                      ),
                    );
                  },
                );
              }

              // 列表视图
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final g = filtered[i];
                  final isCardActive =
                      activeState.isActive && activeState.gameId == g.id;
                  return Material(
                    color: isCardActive
                        ? AppColors.surfaceActive
                        : AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: g.favorite
                            ? const Color(0xFFFFC857)
                            : AppColors.border,
                        width: g.favorite ? 1.5 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => GameDetailDialog(game: g),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            if (g.iconPng != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(
                                  g.iconPng!,
                                  width: 28,
                                  height: 28,
                                  cacheWidth: 56,
                                  cacheHeight: 56,
                                ),
                              )
                            else
                              const Icon(
                                Icons.videogame_asset,
                                size: 24,
                                color: AppColors.textMuted,
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.title,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    g.exePath,
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
                            if (isCardActive) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                formatStopwatch(activeState.elapsedMs),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else
                              Text(
                                formatPlayDuration(g.totalPlaySeconds),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: '运行文件',
                              icon: Icon(
                                Icons.play_arrow,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              onPressed: () => _launchGame(g, launcher),
                            ),
                            IconButton(
                              tooltip: '打开游戏目录',
                              icon: const Icon(
                                Icons.folder_open_rounded,
                                color: AppColors.textSecondary,
                                size: 19,
                              ),
                              onPressed: () => _openGameDirectory(g, launcher),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
