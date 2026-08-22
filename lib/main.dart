/// BlackOhm 入口点：初始化 WindowManager + 托盘保活 + 挂载 Riverpod。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
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

  // 读取 startHidden 设置决定首屏展示/隐藏，并等待设置加载完成
  final container = ProviderContainer();
  await container.read(settingsProvider.notifier).loadFuture;
  final startHidden = container.read(settingsProvider).startHidden;

  // 内存治理：收紧图像缓存上限（默认 1000 张 / 100 MiB，远超本应用需求），
  // 并尽早启动托盘态工作集修剪服务。
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 128;
  imageCache.maximumSizeBytes = 8 << 20;
  final trim = container.read(memoryTrimProvider);
  trim.windowVisible = !startHidden;

  if (!startHidden) {
    await windowManager.show();
    await windowManager.focus();
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const BlackOhmApp()),
  );
}
