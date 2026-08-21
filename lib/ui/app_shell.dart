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
      tray.updateRecent(
          list.map((g) => (id: g.id, title: g.title)).toList());
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
      messenger.showSnackBar(SnackBar(
        content: Text('已录入 ${report.added.length} 款游戏：${report.added.join('、')}'),
        backgroundColor: AppColors.accent,
      ));
    }
    if (report.duplicatePaths.isNotEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text('${report.duplicatePaths.length} 个路径已在库中，已跳过'),
      ));
    }
    if (report.noExePaths.isNotEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text('未在 ${report.noExePaths.length} 个目录中找到有效程序'),
      ));
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('已录入：${chosen.description ?? chosen.path}'),
                backgroundColor: AppColors.accent,
              ));
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
        body: Row(
          children: [
            // 现代极简侧边栏
            Container(
              width: 72,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Logo 呼吸灯点
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceActive,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent),
                    ),
                    child: const Center(
                      child: Icon(Icons.bolt,
                          color: AppColors.accent, size: 22),
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
                    icon: Icons.tune_rounded,
                    label: '设置',
                    index: 1,
                  ),
                  const Spacer(),
                  // 底部状态小绿点（引擎常驻守护）
                  Consumer(
                    builder: (_, ref, __) {
                      final active =
                          ref.watch(trackingStateProvider).value?.isActive ??
                              false;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Tooltip(
                          message: active ? '正在前台计时' : '后台守护中 (0% CPU)',
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                              shape: BoxShape.circle,
                              boxShadow: active
                                  ? const [
                                      BoxShadow(
                                        color: AppColors.accentGlow,
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // 主视图
            Expanded(
              child: IndexedStack(
                index: _navIndex,
                children: const [
                  LibraryPage(),
                  SettingsPage(),
                ],
              ),
            ),
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
              ? Border.all(color: AppColors.accent.withAlpha(80))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? AppColors.accent : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
