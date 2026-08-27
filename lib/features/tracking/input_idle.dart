/// 前台游戏键鼠输入空闲判断的纯逻辑。
library;

import '../../core/app_constants.dart';

/// 计算两个 32 位 Windows tick 值的无符号差值，支持计数器回绕。
int elapsedWindowsTickMs(int now, int then) => (now - then) & 0xFFFFFFFF;

bool hasReachedInputIdleThreshold(
  int idleMs, {
  Duration threshold = kInputIdlePausePeriod,
}) => idleMs >= threshold.inMilliseconds;

bool shouldPauseForInputIdle({
  required bool monitoringEnabled,
  required bool live,
  required Duration liveDuration,
  required int? idleMs,
  Duration threshold = kInputIdlePausePeriod,
}) {
  if (!monitoringEnabled || !live || idleMs == null) return false;
  return liveDuration >= threshold &&
      hasReachedInputIdleThreshold(idleMs, threshold: threshold);
}
