/// 游戏启动服务：直启 / Locale Emulator 代理启动。
///
/// LE 调用流：
///   LEProc.exe -run "&lt;Target_Exe&gt;" [args]
/// 参数模板可配置（{exe} / {profile} / {args} 占位符），
/// 以兼容 `-runas {profile} "{exe}"` 等 LEProc 形态。
///
/// 关键设计：记录器不依赖子进程句柄生命周期——即便游戏由
/// LEProc 代理派生，计时仍通过全局前台窗口 → 进程真实镜像路径捕获，
/// 代理链对焦点引擎完全透明。
library;

import 'dart:io';

import '../../core/database/app_database.dart';
import '../../providers.dart' show AppSettingsState;

class LaunchService {
  /// 直启游戏进程（detached：不持有管道，进程独立生存）。
  Future<bool> launchDirect(Game game) async {
    try {
      await Process.start(
        game.exePath,
        _splitArgs(game.launchArgs),
        workingDirectory: game.dirPath,
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 经 Locale Emulator 代理启动。
  Future<bool> launchViaLocaleEmulator(Game game, AppSettingsState s) async {
    final leProc = s.leProcPath.trim();
    if (leProc.isEmpty || !File(leProc).existsSync()) return false;
    try {
      final tokens = _expandTemplate(
        s.leArgsTemplate,
        exe: game.exePath,
        profile: s.leProfile,
        extraArgs: game.launchArgs,
      );
      await Process.start(
        leProc,
        tokens,
        workingDirectory: File(leProc).parent.path,
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> launch(Game game, AppSettingsState s) {
    if (game.useLocaleEmulator) {
      return launchViaLocaleEmulator(game, s);
    }
    return launchDirect(game);
  }

  /// 模板展开：`-run "{exe}"` → ['-run', 'C:\...\game.exe']。
  /// 占位符替换后为空的 token（如未配置 {profile}）整段丢弃。
  List<String> _expandTemplate(
    String template, {
    required String exe,
    required String profile,
    required String extraArgs,
  }) {
    final out = <String>[];
    for (final raw in _splitArgs(template)) {
      var t = raw
          .replaceAll('{exe}', exe)
          .replaceAll('{profile}', profile)
          .replaceAll('{args}', extraArgs);
      if (t.isEmpty) continue;
      if (raw.contains('{profile}') && profile.isEmpty) continue;
      if (raw.contains('{args}') && extraArgs.isEmpty) continue;
      out.add(t);
    }
    return out;
  }

  /// 微型 shell 风格分词：空格分隔、双引号成组（不支持转义，模板足够用）。
  List<String> _splitArgs(String s) {
    final out = <String>[];
    final sb = StringBuffer();
    var inQuote = false;
    for (final ch in s.trim().split('')) {
      if (ch == '"') {
        inQuote = !inQuote;
      } else if (ch == ' ' && !inQuote) {
        if (sb.isNotEmpty) out.add(sb.toString());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    if (sb.isNotEmpty) out.add(sb.toString());
    return out;
  }
}
