/// 系统托盘服务：快速启动最近游戏 / 暂停统计 / 显示主窗口 / 退出。
library;

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayService with TrayListener {
  final void Function(int gameId) onLaunchGame;
  final VoidCallback onTogglePause;
  final VoidCallback onShowWindow;
  final VoidCallback onQuit;

  TrayService({
    required this.onLaunchGame,
    required this.onTogglePause,
    required this.onShowWindow,
    required this.onQuit,
  });

  bool _started = false;
  List<({int id, String title})> _recent = const [];
  bool _paused = false;

  Future<void> start({required bool paused}) async {
    if (_started) return;
    _started = true;
    _paused = paused;
    trayManager.addListener(this);
    await trayManager.setIcon('assets/tray.ico');
    await trayManager.setToolTip('BlackOhm · 前台焦点记录器');
    await _rebuild();
  }

  Future<void> updateRecent(List<({int id, String title})> recent) async {
    _recent = recent;
    if (_started) await _rebuild();
  }

  Future<void> updatePaused(bool paused) async {
    _paused = paused;
    if (_started) await _rebuild();
  }

  Future<void> _rebuild() async {
    final items = <MenuItem>[
      MenuItem(
        key: 'hdr_recent',
        label: _recent.isEmpty ? '暂无最近游玩记录' : '最近游玩 · 点击启动',
        disabled: true,
      ),
      for (var i = 0; i < _recent.length; i++)
        MenuItem(
          key: 'launch:${_recent[i].id}',
          label: '  ${i + 1}. ${_recent[i].title}',
        ),
      MenuItem.separator(),
      MenuItem.checkbox(key: 'pause', label: '暂停统计', checked: _paused),
      MenuItem(key: 'show', label: '显示主窗口'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出 BlackOhm'),
    ];
    await trayManager.setMenu(Menu(items: items));
  }

  Future<void> dispose() async {
    if (!_started) return;
    _started = false;
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key ?? '';
    if (key.startsWith('launch:')) {
      final id = int.tryParse(key.substring(7));
      if (id != null) onLaunchGame(id);
    } else if (key == 'pause') {
      onTogglePause();
    } else if (key == 'show') {
      onShowWindow();
    } else if (key == 'quit') {
      onQuit();
    }
  }

  @override
  void onTrayIconMouseDown() => onShowWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();
}
