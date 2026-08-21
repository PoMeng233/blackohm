/// BlackOhm 入口点：初始化 WindowManager + 托盘保活 + 挂载 Riverpod。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'data/settings_repository.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await windowManager.setAsFrameless();

  final windowOptions = const WindowOptions(
    size: Size(1080, 720),
    minimumSize: Size(800, 560),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    title: 'BlackOhm',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true); // 拦截关闭 → 最小化到托盘
  });

  // 读取 startHidden 设置决定首屏展示/隐藏
  final container = ProviderContainer();
  final startHidden = await container
      .read(settingsRepoProvider)
      .getBool(SettingsKeys.startHidden);

  if (!startHidden) {
    await windowManager.show();
    await windowManager.focus();
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const BlackOhmApp()),
  );
}
