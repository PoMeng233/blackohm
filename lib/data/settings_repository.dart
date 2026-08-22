/// 设置仓库层：AppSettings KV 表的读写与类型化默认值。
library;

import '../core/database/app_database.dart';

/// 全局设置键。
abstract final class SettingsKeys {
  /// Locale Emulator 的 LEProc.exe 绝对路径。
  static const leProcPath = 'le.procPath';

  /// LE 启动参数模板（含 {exe} / {profile} / {args} 占位符）。
  static const leArgsTemplate = 'le.argsTemplate';

  /// 默认 LE Profile（如 Japan）。
  static const leProfile = 'le.profile';

  /// 启动时最小化到托盘。
  static const startHidden = 'ui.startHidden';

  /// 关闭按钮 = 隐藏到托盘（而非退出）。
  static const closeToTray = 'ui.closeToTray';

  /// 统计暂停开关（托盘"暂停统计"）。
  static const trackingPaused = 'tracking.paused';

  /// Bangumi/BGM API token（仅保存在本地设置，不写入日志）。
  static const bangumiToken = 'network.bangumiToken';

  /// 主界面背景图的应用缓存路径。
  static const shellBackgroundPath = 'ui.shellBackgroundPath';

  /// Material 3 配色方案（ThemePalette 枚举名）。
  static const themePalette = 'ui.themePalette';
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<String> get(String key, {String defaultValue = ''}) async {
    final q = _db.select(_db.appSettings)..where((s) => s.key.equals(key));
    final row = await q.getSingleOrNull();
    return row?.value ?? defaultValue;
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final v = await get(key, defaultValue: defaultValue ? '1' : '0');
    return v == '1' || v.toLowerCase() == 'true';
  }

  Future<void> set(String key, String value) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  Future<void> setBool(String key, bool value) => set(key, value ? '1' : '0');

  Stream<String> watch(String key, {String defaultValue = ''}) {
    final q = _db.select(_db.appSettings)..where((s) => s.key.equals(key));
    return q.watchSingleOrNull().map((row) => row?.value ?? defaultValue);
  }
}
