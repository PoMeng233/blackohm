import 'package:blackohm/features/tracking/watcher/foreground_watcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('watcher 快照快速门控（shouldSkipFullParse）', () {
    test('同窗口且可见性未变：跳过完整解析（心跳稳态路径，CPU 优化核心）', () {
      expect(
        shouldSkipFullParse(
          hwnd: 100,
          visible: true,
          lastHwnd: 100,
          lastVisible: true,
        ),
        isTrue,
      );
      expect(
        shouldSkipFullParse(
          hwnd: 100,
          visible: false,
          lastHwnd: 100,
          lastVisible: false,
        ),
        isTrue,
      );
    });

    test('可见性翻转（最小化/还原）：必须走完整解析并发出新快照', () {
      expect(
        shouldSkipFullParse(
          hwnd: 100,
          visible: false,
          lastHwnd: 100,
          lastVisible: true,
        ),
        isFalse,
      );
      expect(
        shouldSkipFullParse(
          hwnd: 100,
          visible: true,
          lastHwnd: 100,
          lastVisible: false,
        ),
        isFalse,
      );
    });

    test('前台窗口切换：必须走完整解析', () {
      expect(
        shouldSkipFullParse(
          hwnd: 200,
          visible: true,
          lastHwnd: 100,
          lastVisible: true,
        ),
        isFalse,
      );
    });

    test('快照失效后（lastHwnd=-1，如解锁/唤醒）：必须重新解析', () {
      expect(
        shouldSkipFullParse(
          hwnd: 100,
          visible: true,
          lastHwnd: -1,
          lastVisible: false,
        ),
        isFalse,
      );
    });

    test('空前台（hwnd=0）：不进入该门控语义（由调用方单独去重处理）', () {
      expect(
        shouldSkipFullParse(
          hwnd: 0,
          visible: false,
          lastHwnd: 0,
          lastVisible: false,
        ),
        isFalse,
      );
    });
  });

  group('临时目录镜像判定（isTempImagePath，EVB 壳归因前置条件）', () {
    test('用户临时目录命中', () {
      expect(
        isTempImagePath(
          r'C:\Users\me\AppData\Local\Temp\evb8a3f.tmp\dipper.exe',
        ),
        isTrue,
      );
    });

    test('系统临时目录命中', () {
      expect(isTempImagePath(r'C:\Windows\Temp\stub.exe'), isTrue);
    });

    test('常规安装路径不命中', () {
      expect(isTempImagePath(r'D:\Games\Dipper\dipper.exe'), isFalse);
      expect(isTempImagePath(r'C:\Program Files\Game\game.exe'), isFalse);
    });
  });
}
