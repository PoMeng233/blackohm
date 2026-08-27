import 'package:blackohm/core/app_constants.dart';
import 'package:blackohm/features/tracking/input_idle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('输入空闲判定', () {
    test('30 分钟阈值前后判定正确', () {
      expect(
        hasReachedInputIdleThreshold(kInputIdlePausePeriod.inMilliseconds - 1),
        isFalse,
      );
      expect(
        hasReachedInputIdleThreshold(kInputIdlePausePeriod.inMilliseconds),
        isTrue,
      );
    });

    test('仅在监测开启、游戏 live 且两个时长都达到阈值时暂停', () {
      const threshold = Duration(seconds: 5);
      expect(
        shouldPauseForInputIdle(
          monitoringEnabled: false,
          live: true,
          liveDuration: threshold,
          idleMs: 5000,
          threshold: threshold,
        ),
        isFalse,
      );
      expect(
        shouldPauseForInputIdle(
          monitoringEnabled: true,
          live: false,
          liveDuration: threshold,
          idleMs: 5000,
          threshold: threshold,
        ),
        isFalse,
      );
      expect(
        shouldPauseForInputIdle(
          monitoringEnabled: true,
          live: true,
          liveDuration: const Duration(seconds: 4),
          idleMs: 5000,
          threshold: threshold,
        ),
        isFalse,
      );
      expect(
        shouldPauseForInputIdle(
          monitoringEnabled: true,
          live: true,
          liveDuration: threshold,
          idleMs: 5000,
          threshold: threshold,
        ),
        isTrue,
      );
    });

    test('Windows 32 位 tick 回绕后可正确计算差值', () {
      expect(elapsedWindowsTickMs(0x00000020, 0xFFFFFFF0), 48);
    });
  });
}
