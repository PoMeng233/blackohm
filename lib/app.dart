/// BlackOhm MaterialApp 根组件。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

class BlackOhmApp extends ConsumerWidget {
  const BlackOhmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    return MaterialApp(
      title: 'BlackOhm',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(palette: palette),
      home: const AppShell(),
    );
  }
}
