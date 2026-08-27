/// 精准前台计时引擎（主 isolate 侧状态机）。
///
/// 输入：watcher isolate 推送的前台快照 / 锁屏 / 睡眠事件。
/// 输出：会话入库 + 对 UI 暴露的单条活跃状态流（驱动呼吸光效与秒表）。
///
/// 状态机：
///   idle ──前台命中──▶ live(累加中)
///   live ──失焦/最小化──▶ grace（不累加，卡片红色静态边框）
///     grace ──30 分钟内切回同一游戏──▶ live（同一 Session 继续）
///     grace ──超过 30 分钟──▶ commit → idle
///   失焦前 1 分钟是明确的暂停提示窗口；超过 1 分钟仍不结束 Session，
///   保持暂停态直到该窗口结束才提交。
///   任意 ──锁屏/睡眠──▶ 立即 commit（无防抖）→ idle
///
/// 落盘节奏：会话开始 1×INSERT；活跃期每 60s 1×UPDATE；
/// 结束 1×UPDATE + totalPlaySeconds 增量。崩溃最多丢失 60s。
library;

import 'dart:async';
import 'dart:isolate';

import '../../core/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../data/session_repository.dart';
import 'game_attributor.dart';
import 'input_idle.dart';
import 'watcher/foreground_watcher.dart' as watcher_lib;
import 'watcher/watcher_protocol.dart';
import 'watcher/win32_bindings.dart' show getLastInputIdleMs;

/// 引擎对 UI 的公开快照。
class TrackingPublicState {
  const TrackingPublicState({
    required this.gameId,
    required this.elapsedMs,
    required this.phase,
    this.pauseReason = TrackingPauseReason.none,
  });

  static const TrackingPublicState idle = TrackingPublicState(
    gameId: 0,
    elapsedMs: 0,
    phase: TrackingPhase.idle,
  );

  final int gameId;
  final int elapsedMs;
  final TrackingPhase phase;
  final TrackingPauseReason pauseReason;

  bool get isActive => phase != TrackingPhase.idle && gameId != 0;

  @override
  bool operator ==(Object other) =>
      other is TrackingPublicState &&
      other.gameId == gameId &&
      other.elapsedMs == elapsedMs &&
      other.phase == phase &&
      other.pauseReason == pauseReason;

  @override
  int get hashCode => Object.hash(gameId, elapsedMs, phase, pauseReason);
}

enum TrackingPhase { idle, live, grace, inputIdle }

enum TrackingPauseReason { none, focusLost, manual, inputIdle }

class _ActiveSession {
  _ActiveSession({required this.gameId});

  final int gameId;
  int sessionId = 0; // INSERT 异步回填，0 = 尚未落库
  int accumulatedMs = 0;
  DateTime? graceSince; // null = live
}

class TrackingEngine {
  TrackingEngine({required this._sessions});

  final SessionRepository _sessions;

  /// 前台归因器：精确 exe 路径命中 + EVB 等包装壳的补充归因。
  final GameAttributor _attributor = GameAttributor();

  _ActiveSession? _active;
  bool _paused = false;
  bool _sleepMonitoring = false;
  int? _inputIdleGameId;
  int? _foregroundGameId;
  DateTime? _sessionStartedAt;
  DateTime? _liveStartedAt;

  /// 主窗口可见性：隐藏到托盘时暂停秒表推送（计时/落盘不受影响），
  /// 恢复可见时补发一次当前状态。
  bool _uiVisible = true;

  Isolate? _watcherIsolate;
  ReceivePort? _port;
  int _shutdownEvent = 0;
  Timer? _tick;
  DateTime _lastFlush = DateTime.now();
  bool _recoveredOpenSessions = false;

  final StreamController<TrackingPublicState> _states =
      StreamController<TrackingPublicState>.broadcast();

  /// 活跃状态流（每秒最多一条，仅活跃时流动；单监听者场景成本可忽略）。
  Stream<TrackingPublicState> get states => _states.stream;

  TrackingPublicState get current {
    final idleGameId = _inputIdleGameId;
    if (idleGameId != null) {
      return TrackingPublicState(
        gameId: idleGameId,
        elapsedMs: 0,
        phase: TrackingPhase.inputIdle,
        pauseReason: TrackingPauseReason.inputIdle,
      );
    }
    final a = _active;
    if (a == null) return TrackingPublicState.idle;
    return TrackingPublicState(
      gameId: a.gameId,
      elapsedMs: a.accumulatedMs,
      phase: _paused || a.graceSince != null
          ? TrackingPhase.grace
          : TrackingPhase.live,
      pauseReason: _paused
          ? TrackingPauseReason.manual
          : (a.graceSince != null
                ? TrackingPauseReason.focusLost
                : TrackingPauseReason.none),
    );
  }

  /// 游戏库变化时重建命中索引（拖拽入库 / 删除后自动生效，无需重启）。
  void rebuildIndex(List<Game> games) {
    _attributor.rebuild(games);
  }

  /// 启动引擎：spawn watcher isolate + 1s 精算 tick。
  Future<void> start() async {
    if (_port != null) return;
    if (!_recoveredOpenSessions) {
      await _sessions.recoverOpenSessions();
      _recoveredOpenSessions = true;
    }
    _port = ReceivePort();
    _watcherIsolate = await watcher_lib.spawnForegroundWatcher(_port!.sendPort);
    _port!.listen(_onWatcherEvent, onError: (_) => _restartWatcher());

    // 1s tick：活跃累加 / 防抖超时判定 / 60s 刷盘三合一。
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  /// watcher 意外退出（理论上不会发生）→ 冷重启。
  Future<void> _restartWatcher() async {
    await _killWatcher();
    await start();
  }

  Future<void> _killWatcher() async {
    _port?.close();
    _port = null;
    _watcherIsolate?.kill(priority: Isolate.immediate);
    _watcherIsolate = null;
    _shutdownEvent = 0;
  }

  /// 优雅停止：SetEvent 通知 watcher 退出 → 兜底 kill；当前会话强制落盘。
  Future<void> stop() async {
    _tick?.cancel();
    _tick = null;
    await _commitActive();
    if (_shutdownEvent != 0) {
      watcher_lib.signalShutdown(_shutdownEvent);
    }
    await _killWatcher();
    await _states.close();
  }

  /// 托盘"暂停统计"。
  void setPaused(bool paused) {
    _paused = paused;
    // 手动暂停开关不覆盖无操作暂停；恢复手动暂停后仍需等待下一次输入。
    _emit();
  }

  void setSleepMonitoring(bool enabled) {
    _sleepMonitoring = enabled;
    if (!enabled && _inputIdleGameId != null) {
      // 关闭监测后不补记暂停期间；当前游戏仍在前台时从现在开始新会话。
      final gameId = _inputIdleGameId!;
      _inputIdleGameId = null;
      if (_foregroundGameId == gameId && !_paused) {
        _startSession(gameId);
        return;
      }
    }
    _emit();
  }

  bool get isPaused => _paused;

  /// 主窗口可见性同步（AppShell 调用）。隐藏期间 _emit 静默。
  void setUiVisible(bool visible) {
    if (_uiVisible == visible) return;
    _uiVisible = visible;
    if (visible) _emit();
  }

  // ── watcher 事件入口 ─────────────────────────────────────────

  Future<void> _onWatcherEvent(dynamic raw) async {
    switch (raw) {
      case WatcherReady(:final shutdownEventHandle):
        _shutdownEvent = shutdownEventHandle;
      case ForegroundSnapshot s:
        _onSnapshot(s);
      case SystemLocked() || SystemSuspend():
        // 锁屏/睡眠：立即挂起并落盘，无防抖。
        _inputIdleGameId = null;
        _foregroundGameId = null;
        await _commitActive();
      case SystemUnlocked() || SystemResumed():
        break; // 解锁后由前台快照自然恢复（新会话）。
      case WatcherStopped():
        await _killWatcher();
    }
  }

  void _onSnapshot(ForegroundSnapshot s) {
    final gameId = _attributor.resolve(
      imagePath: s.imagePath,
      commandLine: s.commandLine,
      windowTitle: s.windowTitle,
      visible: s.visible,
    );
    _foregroundGameId = gameId;
    if (gameId == null) {
      final wasInputIdle = _inputIdleGameId != null;
      _inputIdleGameId = null;
      _liveStartedAt = null;
      _enterGraceIfNeeded();
      if (wasInputIdle && _active == null) _emit();
      return;
    }
    if (_inputIdleGameId == gameId) {
      // 自动暂停时保留前台归因；恢复输入由 tick 创建新会话。
      _emit();
      return;
    }
    final active = _active;
    if (active != null && active.gameId == gameId) {
      active.graceSince = null; // 防抖窗口内回归：合并为连续 Session
      _liveStartedAt = DateTime.now();
      _emit();
      return;
    }
    if (active != null) {
      unawaited(_commitActive()); // 换游戏：先结前一个（Drift 后台串行写入）
    }
    _inputIdleGameId = null;
    _startSession(gameId);
  }

  void _enterGraceIfNeeded() {
    final a = _active;
    if (a == null || a.graceSince != null) return;
    a.graceSince = DateTime.now();
    _emit();
  }

  void _startSession(int gameId) {
    _active = _ActiveSession(gameId: gameId);
    _sessionStartedAt = DateTime.now();
    _liveStartedAt = _sessionStartedAt;
    _lastFlush = DateTime.now();
    // INSERT 会话行（drift 后台 isolate 串行执行，回填 sessionId）。
    _sessions.start(gameId, DateTime.now()).then((id) {
      final a = _active;
      if (a != null && a.gameId == gameId && a.sessionId == 0) {
        a.sessionId = id;
      }
    });
    _emit();
  }

  // ── 1s tick：累加 / 防抖超时 / 输入空闲 / 周期刷盘 ──────────

  void _onTick() {
    final idleGameId = _inputIdleGameId;
    if (idleGameId != null) {
      _handleInputIdlePause(idleGameId);
      return;
    }

    final a = _active;
    if (a == null) return;
    final live = a.graceSince == null && !_paused;
    if (live && _sleepMonitoring) {
      final idleMs = getLastInputIdleMs();
      final liveDuration = _liveStartedAt == null
          ? Duration.zero
          : DateTime.now().difference(_liveStartedAt!);
      // 仅将“当前连续前台期间系统整体无输入”视为睡眠，
      // 避免切回游戏前在其它窗口的旧空闲时间立即触发暂停。
      if (shouldPauseForInputIdle(
        monitoringEnabled: _sleepMonitoring,
        live: live,
        liveDuration: liveDuration,
        idleMs: idleMs,
      )) {
        _inputIdleGameId = a.gameId;
        unawaited(_commitActive());
        _emit();
        return;
      }
    }
    if (live) a.accumulatedMs += 1000;

    // 防抖超时 → 会话终结
    final grace = a.graceSince;
    if (grace != null &&
        DateTime.now().difference(grace) >= kFocusGracePeriod) {
      unawaited(_commitActive());
      return;
    }
    // 周期刷盘（内存累加 → SQLite）
    if (live &&
        DateTime.now().difference(_lastFlush) >= kSessionFlushInterval) {
      _lastFlush = DateTime.now();
      unawaited(_sessions.flushProgress(a.sessionId, a.accumulatedMs ~/ 1000));
    }
    _emit();
  }

  void _handleInputIdlePause(int gameId) {
    if (!_sleepMonitoring || _foregroundGameId != gameId) {
      _inputIdleGameId = null;
      if (_foregroundGameId == gameId && !_paused) {
        _startSession(gameId);
      } else {
        _emit();
      }
      return;
    }
    final idleMs = getLastInputIdleMs();
    if (idleMs == null || hasReachedInputIdleThreshold(idleMs) || _paused) {
      _emit();
      return;
    }
    _inputIdleGameId = null;
    _startSession(gameId);
  }

  /// 结束当前会话并落盘（含 totalPlaySeconds 增量）。
  Future<void> _commitActive() async {
    final a = _active;
    _active = null;
    _sessionStartedAt = null;
    _liveStartedAt = null;
    if (a == null) return;
    final seconds = a.accumulatedMs ~/ 1000;
    if (seconds <= 0) {
      // 空会话：清行，避免污染时间线。
      await _sessions.deleteSession(a.sessionId);
      _emit();
      return;
    }
    await _sessions
        .commit(a.sessionId, a.gameId, seconds, DateTime.now())
        .catchError((_) {});
    _emit();
  }

  void _emit() {
    if (!_uiVisible) return;
    if (!_states.isClosed) _states.add(current);
  }
}
