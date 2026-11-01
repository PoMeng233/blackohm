import 'package:blackohm/ui/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('windowVisibilityForEvent', () {
    test('最大化窗口从最小化恢复时按可见处理', () {
      // 回归：Windows 此时只发 WM_SIZE SIZE_MAXIMIZED，
      // window_manager 派发 maximize 而非 restore。
      expect(windowVisibilityForEvent('maximize'), isTrue);
    });

    test('普通恢复与显示事件按可见处理', () {
      for (final event in ['show', 'restore', 'unmaximize', 'focus']) {
        expect(windowVisibilityForEvent(event), isTrue, reason: event);
      }
    });

    test('最小化与隐藏事件按不可见处理', () {
      expect(windowVisibilityForEvent('minimize'), isFalse);
      expect(windowVisibilityForEvent('hide'), isFalse);
    });

    test('与可见性无关的事件不改变状态', () {
      for (final event in ['blur', 'resize', 'resized', 'move', 'moved']) {
        expect(windowVisibilityForEvent(event), isNull, reason: event);
      }
    });
  });
}
