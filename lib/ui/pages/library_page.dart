/// 游戏库视图：支持搜索、网格/列表双视图、文件夹归类与拖拽、收藏过滤、直启与详情。
library;

import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../features/launcher/launch_service.dart';
import '../../features/scanner/ingestion_service.dart';
import '../../features/tracking/tracking_engine.dart';
import '../../providers.dart';
import '../theme.dart';
import '../widgets/active_record_frame.dart';
import '../widgets/exe_decision_dialog.dart';
import '../widgets/folder_card.dart';
import '../widgets/game_card.dart';
import '../widgets/game_detail_dialog.dart';
import '../widgets/game_icon.dart';

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

  /// 当前选中的文件夹 ID：null 表示“全部”；-1 表示“未分类”；>= 0 为具体文件夹 ID
  int? _selectedFolderId;

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
    final ok = await launcher.launch(
      game,
      ref.read(settingsProvider),
      games: ref.read(gameRepoProvider),
    );
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

  void _selectFolder(int? folderId) {
    setState(() => _selectedFolderId = folderId);
    final target = folderId != null && folderId > 0 ? folderId : null;
    ref.read(currentBrowsingFolderIdProvider.notifier).state = target;
  }

  Future<void> _addGame() async {
    if (_adding) return;
    final targetFolderId = _selectedFolderId != null && _selectedFolderId! > 0
        ? _selectedFolderId
        : null;
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
      final report = await service.ingestDroppedPaths([
        path,
      ], folderId: targetFolderId);
      if (!mounted) return;
      for (final candidates in report.pendingDecisions) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ExeDecisionDialog(
            candidates: candidates,
            onSelected: (candidate) =>
                service.addChosen(candidate, report, folderId: targetFolderId),
          ),
        );
      }
      if (!mounted) return;
      final message = report.added.isNotEmpty
          ? '成功入库 ${report.added.length} 款游戏'
          : '未找到有效的游戏运行文件';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _createFolderDialog() async {
    final nameCtrl = TextEditingController();
    var showOnHome = true;
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          constraints: const BoxConstraints(maxWidth: 480),
          title: const Text('新建文件夹'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '文件夹名称',
                  hintText: '如：全通、神作、待推',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '在“全部游戏”显示文件夹卡片',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  '关闭后仍可从顶部文件夹栏进入和拖入游戏',
                  style: TextStyle(fontSize: 11),
                ),
                value: showOnHome,
                onChanged: (v) => setDialogState(() => showOnHome = v),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '全部游戏会显示所有游戏；进入文件夹后只显示其中成员。该开关只控制主页是否显示文件夹卡片。',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    if (created == true && nameCtrl.text.trim().isNotEmpty) {
      await ref
          .read(folderRepoProvider)
          .create(nameCtrl.text.trim(), showOnHome: showOnHome);
    }
  }

  Future<void> _editFolderDialog(GameFolder folder) async {
    final nameCtrl = TextEditingController(text: folder.name);
    final games = ref.read(gameListProvider).valueOrNull ?? const <Game>[];
    final members = games.where((game) => game.folderId == folder.id).toList();
    final totalSeconds = members.fold<int>(
      0,
      (total, game) => total + game.totalPlaySeconds,
    );
    var showOnHome = folder.showOnHome;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          constraints: const BoxConstraints(maxWidth: 480),
          title: const Text('编辑文件夹'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_copy_outlined,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${members.length} 款游戏 · 成员累计 ${formatPlayDuration(totalSeconds)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '文件夹名称'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '在“全部游戏”显示文件夹卡片',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  '关闭后仍可从顶部文件夹栏进入和拖入游戏',
                  style: TextStyle(fontSize: 11),
                ),
                value: showOnHome,
                onChanged: (v) => setDialogState(() => showOnHome = v),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '全部游戏会显示所有游戏；进入文件夹后只显示其中成员。该开关只控制主页是否显示文件夹卡片。',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('删除', style: TextStyle(color: AppColors.error)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result == 'save') {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      await ref
          .read(folderRepoProvider)
          .update(
            folder.id,
            GameFoldersCompanion(
              name: Value(name),
              showOnHome: Value(showOnHome),
            ),
          );
    } else if (result == 'delete') {
      await _confirmDeleteFolder(folder);
    }
  }

  Future<void> _moveGameToFolder(Game game, int? folderId, String label) async {
    if (game.folderId == folderId) return;
    await ref
        .read(gameRepoProvider)
        .update(game.id, GamesCompanion(folderId: Value(folderId)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已将 "${game.title}" 移至 "$label"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmDeleteFolder(GameFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件夹？'),
        content: Text('“${folder.name}”中的游戏会转为未分类。游戏条目、游玩记录和本地游戏文件均不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除文件夹'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(folderRepoProvider).delete(folder.id);
    if (_selectedFolderId == folder.id && mounted) {
      setState(() => _selectedFolderId = null);
    }
  }

  Future<void> _showFolderContextMenu(
    GameFolder folder,
    TapUpDetails details,
  ) async {
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final offset = overlay.globalToLocal(details.globalPosition);
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(offset.dx, offset.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      color: AppColors.surfaceActive,
      items: const [
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18),
              SizedBox(width: 8),
              Text('文件夹设置'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: AppColors.error, size: 18),
              SizedBox(width: 8),
              Text('删除文件夹', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
    if (!mounted) return;
    if (action == 'settings') {
      await _editFolderDialog(folder);
    } else if (action == 'delete') {
      await _confirmDeleteFolder(folder);
    }
  }

  Widget _buildFolderTabs(List<GameFolder> folders) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _folderChip(
            label: '全部游戏',
            isSelected: _selectedFolderId == null,
            onTap: () => _selectFolder(null),
          ),
          const SizedBox(width: 8),
          _folderChip(
            label: '未分类',
            isSelected: _selectedFolderId == -1,
            targetFolderId: -1,
            onTap: () => _selectFolder(-1),
          ),
          const SizedBox(width: 8),
          ...folders.map(
            (f) => Padding(
              key: ValueKey('folder-tab-${f.id}'),
              padding: const EdgeInsets.only(right: 8),
              child: LongPressDraggable<GameFolder>(
                data: f,
                axis: Axis.horizontal,
                feedback: Material(
                  color: Colors.transparent,
                  child: _folderChip(
                    label: f.name,
                    isSelected: false,
                    targetFolderId: null,
                    onTap: () {},
                  ),
                ),
                child: DragTarget<GameFolder>(
                  onWillAcceptWithDetails: (details) => details.data.id != f.id,
                  onAcceptWithDetails: (details) =>
                      _reorderFolder(details.data, f),
                  builder: (context, candidateData, rejectedData) =>
                      _folderChip(
                        label: f.name,
                        isSelected: _selectedFolderId == f.id,
                        targetFolderId: f.id,
                        isReorderHovering: candidateData.isNotEmpty,
                        onTap: () => _selectFolder(f.id),
                        onSecondaryTapUp: (details) =>
                            _showFolderContextMenu(f, details),
                      ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '新建文件夹',
            icon: const Icon(Icons.create_new_folder_outlined, size: 20),
            onPressed: _createFolderDialog,
          ),
        ],
      ),
    );
  }

  Future<void> _reorderFolder(GameFolder source, GameFolder target) async {
    final folders = ref.read(folderListProvider).valueOrNull;
    if (folders == null) return;
    final ids = folders.map((folder) => folder.id).toList();
    final from = ids.indexOf(source.id);
    final to = ids.indexOf(target.id);
    if (from < 0 || to < 0 || from == to) return;
    ids.removeAt(from);
    ids.insert(to, source.id);
    await ref.read(folderRepoProvider).reorder(ids);
  }

  Widget _folderChip({
    required String label,
    required bool isSelected,
    int? targetFolderId,
    bool isReorderHovering = false,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    GestureTapUpCallback? onSecondaryTapUp,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget chip({bool isHovered = false}) => InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapUp: onSecondaryTapUp,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isHovered || isReorderHovering
              ? primary.withAlpha(40)
              : (isSelected ? primary.withAlpha(28) : AppColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHovered || isReorderHovering
                ? primary
                : (isSelected ? primary : AppColors.border),
            width: isHovered || isReorderHovering || isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              targetFolderId == null
                  ? Icons.apps_rounded
                  : (targetFolderId == -1
                        ? Icons.inbox_rounded
                        : Icons.folder_rounded),
              size: 15,
              color: isSelected ? primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    // “全部游戏”只是筛选视图；不接受拖拽，避免误把游戏移为未分类。
    if (targetFolderId == null) return chip();
    return DragTarget<Game>(
      onWillAcceptWithDetails: (details) =>
          details.data.folderId !=
          (targetFolderId == -1 ? null : targetFolderId),
      onAcceptWithDetails: (details) => _moveGameToFolder(
        details.data,
        targetFolderId == -1 ? null : targetFolderId,
        label,
      ),
      builder: (context, candidateData, rejectedData) =>
          chip(isHovered: candidateData.isNotEmpty),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gameListProvider);
    final foldersAsync = ref.watch(folderListProvider);
    final activeState = ref.watch(
      trackingStateProvider.select(
        (value) => value.valueOrNull ?? TrackingPublicState.idle,
      ),
    );
    final activeGameId = activeState.gameId;
    final launcher = LaunchService();

    return Column(
      children: [
        // 顶部工具栏：搜索 + 排序 + 收藏过滤 + 网格/列表切换
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

        // 文件夹分类栏
        foldersAsync.when(
          data: _buildFolderTabs,
          loading: () => const SizedBox(height: 38),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 6),

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
              final folders = foldersAsync.valueOrNull ?? const [];

              // 过滤文件夹
              var filtered = games.where((g) {
                if (_onlyFavorites && !g.favorite) return false;
                if (_selectedFolderId == -1) {
                  if (g.folderId != null) return false;
                } else if (_selectedFolderId != null &&
                    g.folderId != _selectedFolderId) {
                  return false;
                }
                if (_searchQuery.isEmpty) return true;
                return g.title.toLowerCase().contains(_searchQuery) ||
                    g.exePath.contains(_searchQuery);
              }).toList();

              // 全库/当前库最大游玩时长（计算横排背景动态比例，最大 3/4）
              final maxPlaySeconds = games.fold<int>(
                0,
                (max, g) => g.totalPlaySeconds > max ? g.totalPlaySeconds : max,
              );

              filtered.sort((a, b) {
                switch (_sort) {
                  case LibrarySort.title:
                    return a.title.toLowerCase().compareTo(
                      b.title.toLowerCase(),
                    );
                  case LibrarySort.totalTime:
                    // 文件夹内浏览按游戏真实时长排序；全部游戏视图则展示所有游戏。
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

              final folderTotals = <int, int>{
                for (final folder in folders) folder.id: 0,
              };
              for (final game in games) {
                final folderId = game.folderId;
                if (folderId != null && folderTotals.containsKey(folderId)) {
                  folderTotals[folderId] =
                      (folderTotals[folderId] ?? 0) + game.totalPlaySeconds;
                }
              }
              final folderCards = _selectedFolderId == null
                  ? folders.where((folder) => folder.showOnHome).toList()
                  : <GameFolder>[];
              if (filtered.isEmpty && folderCards.isEmpty) {
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

              // 网格视图
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
                  itemCount: folderCards.length + filtered.length,
                  itemBuilder: (context, i) {
                    if (i < folderCards.length) {
                      final folder = folderCards[i];
                      final gameCount = games
                          .where((game) => game.folderId == folder.id)
                          .length;
                      return FolderCard(
                        folder: folder,
                        gameCount: gameCount,
                        totalPlaySeconds: folderTotals[folder.id] ?? 0,
                        onOpen: () => _selectFolder(folder.id),
                        onMoveGame: (game) =>
                            _moveGameToFolder(game, folder.id, folder.name),
                        onShowMenu: (details) =>
                            _showFolderContextMenu(folder, details),
                      );
                    }

                    final g = filtered[i - folderCards.length];
                    final card = RepaintBoundary(
                      child: GameCard(
                        game: g,
                        onOpenDetail: () => showDialog<void>(
                          context: context,
                          builder: (_) => GameDetailDialog(game: g),
                        ),
                        onLaunch: () => _launchGame(g, launcher),
                        onOpenDirectory: () => _openGameDirectory(g, launcher),
                        onToggleFavorite: () => ref
                            .read(gameRepoProvider)
                            .update(
                              g.id,
                              GamesCompanion(favorite: Value(!g.favorite)),
                            ),
                        onDelete: () => ref.read(gameRepoProvider).delete(g.id),
                      ),
                    );
                    return Draggable<Game>(
                      data: g,
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 140,
                          height: 150,
                          child: Opacity(opacity: 0.85, child: card),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: 0.3, child: card),
                      child: card,
                    );
                  },
                );
              }

              // 横排/列表视图
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final g = filtered[i];
                  final isCardActive = activeGameId == g.id;
                  final backgroundPath = g.backgroundPath;
                  final backgroundFile =
                      backgroundPath != null && backgroundPath.isNotEmpty
                      ? File(backgroundPath)
                      : null;
                  final hasBackground =
                      backgroundFile != null && backgroundFile.existsSync();
                  final detailPath = g.detailBackgroundPath;
                  final hasBlurBackground =
                      g.backgroundBlurAmount > 0 &&
                      detailPath != null &&
                      File(detailPath).existsSync();

                  // 游玩时长占比：最高占整行 3/4 (0.75) 面积
                  final ratio = maxPlaySeconds > 0
                      ? (g.totalPlaySeconds / maxPlaySeconds).clamp(0.0, 1.0)
                      : 0.0;
                  final widthFraction = ratio * 0.75;
                  final pixelRatio = MediaQuery.devicePixelRatioOf(context);
                  final listCacheWidth = (800 * pixelRatio).round().clamp(
                    1,
                    1440,
                  );
                  final listCacheHeight = (96 * pixelRatio).round().clamp(
                    1,
                    240,
                  );

                  final rowItem = Material(
                    color: isCardActive
                        ? AppColors.surfaceActive
                        : AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: g.favorite
                            ? const Color(0xFFFFC857)
                            : (isCardActive
                                  ? context.interactiveColor
                                  : AppColors.border),
                        width: g.favorite || isCardActive ? 1.5 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => GameDetailDialog(game: g),
                      ),
                      child: Stack(
                        children: [
                          // 动态面积背景图：从左往右展示，根据游玩时长最多占 3/4，大羽化渐变 + 压暗遮罩保护文字
                          if (hasBackground && widthFraction > 0.05)
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: widthFraction,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(
                                        backgroundFile,
                                        fit: BoxFit.cover,
                                        cacheWidth: listCacheWidth,
                                        cacheHeight: listCacheHeight,
                                        filterQuality: FilterQuality.low,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox.shrink(),
                                      ),
                                      if (hasBlurBackground)
                                        Opacity(
                                          opacity: g.backgroundBlurAmount.clamp(
                                            0.0,
                                            1.0,
                                          ),
                                          child: Image.file(
                                            File(detailPath),
                                            fit: BoxFit.cover,
                                            cacheWidth: listCacheWidth,
                                            cacheHeight: listCacheHeight,
                                            filterQuality: FilterQuality.low,
                                            errorBuilder: (_, _, _) =>
                                                const SizedBox.shrink(),
                                          ),
                                        ),
                                      // 压暗与由左至右大羽化渐变蒙层
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              AppColors.bgDark.withAlpha(153),
                                              AppColors.bgDark.withAlpha(230),
                                              AppColors.bgDark,
                                            ],
                                            stops: [0.0, 0.65, 1.0],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          // 前景内容区
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                GameIcon(
                                  gameId: g.id,
                                  size: 32,
                                  radius: 6,
                                  iconSize: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '正在游玩',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ] else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgDark.withAlpha(135),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppColors.border.withAlpha(130),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.schedule,
                                          size: 13,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          formatCompactPlayDuration(
                                            g.totalPlaySeconds,
                                          ),
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                IconButton(
                                  tooltip: '运行文件',
                                  icon: Icon(
                                    Icons.play_arrow,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                                  onPressed: () =>
                                      _openGameDirectory(g, launcher),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  final framedRow = ActiveRecordFrame(
                    active:
                        activeState.phase == TrackingPhase.live &&
                        activeGameId == g.id,
                    color: Theme.of(context).colorScheme.primary,
                    radius: 8,
                    child: rowItem,
                  );
                  return Draggable<Game>(
                    data: g,
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: 320,
                        child: Opacity(opacity: 0.85, child: rowItem),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.3, child: framedRow),
                    child: framedRow,
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
