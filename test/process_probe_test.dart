import 'dart:io';

import 'package:blackohm/features/tracking/process_probe.dart';
import 'package:blackohm/features/tracking/watcher/win32_bindings.dart' as w;
import 'package:flutter_test/flutter_test.dart';

class _FakeProbe implements GameLivenessProbe {
  _FakeProbe(this.result);

  GameLiveness result;
  int calls = 0;
  int? lastPid;
  String? lastName;

  @override
  GameLiveness probe({required int pid, required String exeFileName}) {
    calls++;
    lastPid = pid;
    lastName = exeFileName;
    return result;
  }
}

void main() {
  group('evaluateGameLiveness', () {
    test('PID 存活时判定为运行中', () {
      expect(
        evaluateGameLiveness(pid: 100, pidAlive: true, nameMatched: false),
        GameLiveness.running,
      );
    });

    test('PID 已退出但有同名进程时仍判定为运行中', () {
      expect(
        evaluateGameLiveness(pid: 100, pidAlive: false, nameMatched: true),
        GameLiveness.running,
      );
    });

    test('PID 已退出且无同名进程时判定为已关闭', () {
      expect(
        evaluateGameLiveness(pid: 100, pidAlive: false, nameMatched: false),
        GameLiveness.closed,
      );
    });

    test('未记录 PID 时返回 unknown，避免误结束会话', () {
      expect(
        evaluateGameLiveness(pid: 0, pidAlive: false, nameMatched: false),
        GameLiveness.unknown,
      );
    });
  });

  group('GraceWatchdog', () {
    test('未武装时不探测也不结束会话', () {
      final probe = _FakeProbe(GameLiveness.closed);
      final watchdog = GraceWatchdog(probe: probe);
      expect(watchdog.shouldCloseGame(now: DateTime(2026, 1, 1)), isFalse);
      expect(probe.calls, 0);
    });

    test('未到检查间隔时不探测', () {
      final probe = _FakeProbe(GameLiveness.closed);
      final watchdog = GraceWatchdog(
        probe: probe,
        interval: const Duration(seconds: 3),
      );
      final start = DateTime(2026, 1, 1, 10);
      watchdog.arm(pid: 42, exeFileName: 'game.exe', now: start);

      expect(
        watchdog.shouldCloseGame(now: start.add(const Duration(seconds: 2))),
        isFalse,
      );
      expect(probe.calls, 0);
    });

    test('到达间隔且游戏已退出时要求结束会话', () {
      final probe = _FakeProbe(GameLiveness.closed);
      final watchdog = GraceWatchdog(
        probe: probe,
        interval: const Duration(seconds: 3),
      );
      final start = DateTime(2026, 1, 1, 10);
      watchdog.arm(pid: 42, exeFileName: 'game.exe', now: start);

      expect(
        watchdog.shouldCloseGame(now: start.add(const Duration(seconds: 3))),
        isTrue,
      );
      expect(probe.calls, 1);
      expect(probe.lastPid, 42);
      expect(probe.lastName, 'game.exe');
    });

    test('到达间隔但游戏仍在运行时保持会话', () {
      final probe = _FakeProbe(GameLiveness.running);
      final watchdog = GraceWatchdog(
        probe: probe,
        interval: const Duration(seconds: 3),
      );
      final start = DateTime(2026, 1, 1, 10);
      watchdog.arm(pid: 42, exeFileName: 'game.exe', now: start);

      expect(
        watchdog.shouldCloseGame(now: start.add(const Duration(seconds: 3))),
        isFalse,
      );
      // 游戏随后退出：下一次到达间隔的检查应要求结束会话。
      probe.result = GameLiveness.closed;
      expect(
        watchdog.shouldCloseGame(now: start.add(const Duration(seconds: 9))),
        isTrue,
      );
      expect(probe.calls, 2);
    });

    test('解除武装后不再探测', () {
      final probe = _FakeProbe(GameLiveness.closed);
      final watchdog = GraceWatchdog(
        probe: probe,
        interval: const Duration(seconds: 3),
      );
      final start = DateTime(2026, 1, 1, 10);
      watchdog.arm(pid: 42, exeFileName: 'game.exe', now: start);
      watchdog.disarm();

      expect(
        watchdog.shouldCloseGame(now: start.add(const Duration(minutes: 1))),
        isFalse,
      );
      expect(probe.calls, 0);
    });
  });

  group('Windows 进程枚举', () {
    test('能读到进程表并正确判断当前进程与不存在的 PID', () {
      expect(w.runningProcessNames(), isNotEmpty);
      expect(w.isProcessAlive(pid), isTrue);
      expect(w.isProcessAlive(999999), isFalse);
    });

    test('探测当前进程时判定为运行中', () {
      const probe = WindowsProcessLivenessProbe();
      final current = Platform.resolvedExecutable
          .split(Platform.pathSeparator)
          .last;
      final liveness = probe.probe(pid: pid, exeFileName: current);
      expect(liveness, isNot(GameLiveness.closed));
    });
  });
}
