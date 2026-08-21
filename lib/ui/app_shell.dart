/// 应用主框架：现代侧边栏 + 路由视图 + 全窗口拖拽注入 + 托盘生命周期绑定。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../features/launcher/launch_service.dart';
import '../features/scanner/ingestion_service.dart';
import '../features/tray/tray_service.dart';
import '../providers.dart';
import 'drop_zone.dart';
import 'pages/insights_page.dart';
import 'pages/library_page.dart';
import 'pages/settings_page.dart';
import 'theme.dart';
import 'widgets/exe_decision_dialog.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WindowListener {
  int _navIndex = 0;
  TrayService? _tray;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initTray();
  }

  Future<void> _initTray() async {
    final launcher = LaunchService();
    final tray = TrayService(
      onLaunchGame: (id) async {
        final g = await ref.read(gameRepoProvider).watchById(id).first;
        if (g != null) {
          final s = ref.read(settingsProvider);
          await launcher.launch(g, s);
        }
      },
      onTogglePause: () {
        final cur = ref.read(settingsProvider).trackingPaused;
        ref.read(settingsProvider.notifier).setTrackingPaused(!cur);
      },
      onShowWindow: () async {
        ref.read(memoryTrimProvider).windowVisible = true;
        await windowManager.show();
        await windowManager.focus();
      },
      onQuit: () async {
        await ref.read(trackingEngineProvider).stop();
        exit(0);
      },
    );
    _tray = tray;
    final paused = ref.read(settingsProvider).trackingPaused;
    await tray.start(paused: paused);

    // 监听最近游玩列表变化更新托盘菜单
    ref.listenManual(recentGamesProvider, (_, next) {
      final list = next.value ?? const [];
      tray.updateRecent(list.map((g) => (id: g.id, title: g.title)).toList());
    }, fireImmediately: true);

    // 监听暂停开关更新托盘复选框
    ref.listenManual(settingsProvider, (_, next) {
      tray.updatePaused(next.trackingPaused);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _tray?.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final closeToTray = ref.read(settingsProvider).closeToTray;
    if (closeToTray) {
      await windowManager.hide();
      // 隐藏到托盘：清缓存并换出工作集（常态内存显著回落）。
      final trim = ref.read(memoryTrimProvider);
      trim
        ..windowVisible = false
        ..notifyWindowHidden();
    } else {
      await ref.read(trackingEngineProvider).stop();
      exit(0);
    }
  }

  Future<void> _onDropped(List<String> paths) async {
    final svc = IngestionService(ref.read(gameRepoProvider));
    final report = await svc.ingestDroppedPaths(paths);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (report.added.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '已录入 ${report.added.length} 款游戏：${report.added.join('、')}',
          ),
          backgroundColor: context.interactiveColor,
        ),
      );
    }
    if (report.duplicatePaths.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('${report.duplicatePaths.length} 个路径已在库中，已跳过')),
      );
    }
    if (report.noExePaths.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('未在 ${report.noExePaths.length} 个目录中找到有效程序')),
      );
    }
    for (final candidates in report.pendingDecisions) {
      if (!mounted) break;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ExeDecisionDialog(
          candidates: candidates,
          onSelected: (chosen) async {
            await svc.addChosen(chosen, report);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已录入：${chosen.description ?? chosen.path}'),
                  backgroundColor: context.interactiveColor,
                ),
              );
            }
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropOverlay(
      onDropped: _onDropped,
      child: Scaffold(
        body: Column(
          children: [
            _titleBar(),
            Expanded(
              child: Row(
                children: [
                  // 现代极简侧边栏
                  Container(
                    width: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        right: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceActive,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.asset(
                              'assets/icon_source.png',
                              cacheWidth: 64,
                              cacheHeight: 64,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _navButton(
                          icon: Icons.grid_view_rounded,
                          label: '游戏库',
                          index: 0,
                        ),
                        const SizedBox(height: 8),
                        _navButton(
                          icon: Icons.query_stats_rounded,
                          label: '时长',
                          index: 1,
                        ),
                        const SizedBox(height: 8),
                        _navButton(
                          icon: Icons.tune_rounded,
                          label: '设置',
                          index: 2,
                        ),
                        const Spacer(),
                        Consumer(
                          builder: (_, ref, _) {
                            final active =
                                ref
                                    .watch(trackingStateProvider)
                                    .value
                                    ?.isActive ??
                                false;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Tooltip(
                                message: active ? '正在前台计时' : '后台守护中',
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? context.interactiveColor
                                        : AppColors.textMuted,
                                    shape: BoxShape.circle,
                                    boxShadow: null,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _navIndex,
                      children: const [
                        LibraryPage(),
                        InsightsPage(),
                        SettingsPage(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleBar() {
    return DragToMoveArea(
      child: Container(
        height: 46,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.surfaceActive,
                borderRadius: BorderRadius.circular(7),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/icon_source.png',
                  cacheWidth: 48,
                  cacheHeight: 48,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 9),
            const Text(
              'BlackOhm',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: '最小化',
              onPressed: windowManager.minimize,
              icon: const Icon(Icons.remove_rounded, size: 18),
            ),
            IconButton(
              tooltip: '最大化/还原',
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              icon: const Icon(Icons.crop_square_rounded, size: 17),
            ),
            IconButton(
              tooltip: '关闭到托盘',
              onPressed: windowManager.close,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final selected = _navIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _navIndex = index),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceActive : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: context.interactiveColor.withAlpha(80))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected
                  ? context.interactiveColor
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected
                    ? context.interactiveColor
                    : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
