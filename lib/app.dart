/// BlackOhm MaterialApp 根组件。
library;

import 'package:flutter/material.dart';

import 'ui/app_shell.dart';
import 'ui/theme.dart';

class BlackOhmApp extends StatelessWidget {
  const BlackOhmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlackOhm',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      home: const AppShell(),
    );
  }
}
