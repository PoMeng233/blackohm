/// 游戏进程存活判定：区分「挂后台未关」与「已经关闭」。
///
/// 前台快照只说明此刻谁在前台。当游戏失焦进入 grace（红框暂停态）时，
/// 必须额外确认游戏进程是否仍然存在，否则关闭游戏后红框会一直挂到
/// 30 分钟自动提交，与用户预期不符。
library;

import 'watcher/win32_bindings.dart' as w;

/// 存活判定结论。
enum GameLiveness {
  /// 仍在前台或后台运行。
  running,

  /// 进程已退出：应立即结束会话。
  closed,

  /// 信息不足（未记录 PID 或进程表枚举失败），保持现状不做处理。
  unknown,
}

/// 结合「PID 是否存活」与「是否有同名进程」得出结论。
///
/// - PID 存活 → running；
/// - PID 已退出但有同名进程 → running（游戏换壳/重启导致 PID 变化）；
/// - PID 已退出且无同名进程 → closed；
/// - 未记录 PID → unknown（宁可漏判，也不误结束会话）。
GameLiveness evaluateGameLiveness({
  required int pid,
  required bool pidAlive,
  required bool nameMatched,
}) {
  if (pid <= 0) return GameLiveness.unknown;
  if (pidAlive) return GameLiveness.running;
  return nameMatched ? GameLiveness.running : GameLiveness.closed;
}

/// 可注入的存活探测，便于单元测试与异常降级。
abstract interface class GameLivenessProbe {
  GameLiveness probe({required int pid, required String exeFileName});
}

/// Windows 实现：查询系统进程表。
class WindowsProcessLivenessProbe implements GameLivenessProbe {
  const WindowsProcessLivenessProbe();

  @override
  GameLiveness probe({required int pid, required String exeFileName}) {
    if (pid <= 0) return GameLiveness.unknown;
    final names = w.runningProcessNames();
    // 枚举失败（快照不可用）时不做判断，避免误结束正在进行的会话。
    if (names.isEmpty) return GameLiveness.unknown;
    final matched =
        exeFileName.isNotEmpty && names.contains(exeFileName.toLowerCase());
    return evaluateGameLiveness(
      pid: pid,
      pidAlive: w.isProcessAlive(pid),
      nameMatched: matched,
    );
  }
}

/// grace（红框暂停）期间按固定间隔检查游戏是否已退出。
class GraceWatchdog {
  GraceWatchdog({
    required this.probe,
    this.interval = const Duration(seconds: 3),
  });

  final GameLivenessProbe probe;
  final Duration interval;

  int _pid = 0;
  String _exeFileName = '';
  DateTime? _lastCheck;
  bool _armed = false;

  bool get isArmed => _armed;

  /// 会话开始或进入 grace 时武装，并重置检查计时基准。
  void arm({
    required int pid,
    required String exeFileName,
    required DateTime now,
  }) {
    _pid = pid;
    _exeFileName = exeFileName;
    _lastCheck = now;
    _armed = true;
  }

  /// 会话提交或切换游戏时解除武装。
  void disarm() {
    _armed = false;
    _pid = 0;
    _exeFileName = '';
    _lastCheck = null;
  }

  /// 到达检查间隔且确认游戏已退出时返回 true。
  bool shouldCloseGame({required DateTime now}) {
    if (!_armed) return false;
    final last = _lastCheck;
    if (last != null && now.difference(last) < interval) return false;
    _lastCheck = now;
    return probe.probe(pid: _pid, exeFileName: _exeFileName) ==
        GameLiveness.closed;
  }
}
