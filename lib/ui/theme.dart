/// BlackOhm 视觉小说暗色主题体系。
library;

import 'package:flutter/material.dart';

enum ThemePalette { obsidian, ocean, amethyst, amber, cherry }

Color paletteSeed(ThemePalette palette) => switch (palette) {
  ThemePalette.obsidian => const Color(0xFF00E5A3),
  ThemePalette.ocean => const Color(0xFF60A5FA),
  ThemePalette.amethyst => const Color(0xFFC084FC),
  ThemePalette.amber => const Color(0xFFF59E0B),
  ThemePalette.cherry => const Color(0xFFFB7185),
};

String paletteLabel(ThemePalette palette) => switch (palette) {
  ThemePalette.obsidian => '黑曜青绿',
  ThemePalette.ocean => '深海蓝',
  ThemePalette.amethyst => '紫晶',
  ThemePalette.amber => '琥珀',
  ThemePalette.cherry => '樱桃红',
};

extension AppThemeColors on BuildContext {
  Color get interactiveColor => Theme.of(this).colorScheme.primary;
  Color get interactiveContainer => Theme.of(this).colorScheme.primaryContainer;
  Color get interactiveOnColor => Theme.of(this).colorScheme.onPrimary;
  Color get secondaryInteractiveColor => Theme.of(this).colorScheme.secondary;
  Color get outlineColor => Theme.of(this).colorScheme.outline;
}

abstract final class AppColors {
  static const bgDark = Color(0xFF0D0F12);
  static const surface = Color(0xFF16191E);
  static const surfaceHover = Color(0xFF1E222A);
  static const surfaceActive = Color(0xFF252A34);
  static const border = Color(0xFF2A2F3A);

  /// 呼吸光效与前台活跃高亮色（赛博青绿）
  static const accent = Color(0xFF00E5A3);

  /// 次级强调（转区/LE 标签）
  static const leBadge = Color(0xFF8B5CF6);

  static const textPrimary = Color(0xFFF1F3F7);
  static const textSecondary = Color(0xFF8E95A5);
  static const textMuted = Color(0xFF555C6E);

  static const error = Color(0xFFFF5252);
}

ThemeData buildDarkTheme({ThemePalette palette = ThemePalette.obsidian}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: paletteSeed(palette),
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgDark,
    colorScheme: scheme.copyWith(
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    fontFamily: 'MiSans',
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHover,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary),
      ),
    ),
  );
}

/// 格式化累计秒数 → "12h 34m" / "45m" / "0m"
String formatPlayDuration(int totalSeconds) {
  if (totalSeconds <= 0) return '0 分钟';
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) return '$h 小时 $m 分';
  if (m > 0) return '$m 分钟';
  return '$s 秒';
}

String formatCompactPlayDuration(int totalSeconds) {
  if (totalSeconds >= 3600) {
    return '${(totalSeconds / 3600).toStringAsFixed(1)}h';
  }
  if (totalSeconds >= 60) return '${totalSeconds ~/ 60}m';
  return '${totalSeconds}s';
}

/// 实时秒表格式：01:23:45 / 12:34
String formatStopwatch(int elapsedMs) {
  final totalSec = elapsedMs ~/ 1000;
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  final ss = s.toString().padLeft(2, '0');
  final mm = m.toString().padLeft(2, '0');
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:$mm:$ss';
  }
  return '$mm:$ss';
}
