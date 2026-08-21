/// 系统托盘服务：快速启动最近游戏 / 暂停统计 / 显示主窗口 / 退出。
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
    await trayManager.setIcon(await _materializeTrayIcon());
    await trayManager.setToolTip('BlackOhm · 前台焦点记录器');
    await _rebuild();
  }

  /// tray_manager 需要磁盘路径；Flutter asset 在 Release 包内不是可直接访问的文件。
  /// 首次启动时将 ICO 写入应用支持目录，之后复用同一文件。
  Future<String> _materializeTrayIcon() async {
    final dir = await getApplicationSupportDirectory();
    final icon = File(p.join(dir.path, 'tray.ico'));
    if (!await icon.exists()) {
      final asset = await rootBundle.load('assets/tray.ico');
      await icon.writeAsBytes(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      );
    }
    return icon.path;
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
    await trayManager.setContextMenu(Menu(items: items));
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
