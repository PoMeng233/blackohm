import 'package:blackohm/ui/widgets/window_resize_frame.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

Widget _harness(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, height: 200, child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_manager');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'isFullScreen' ? false : true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const edgePositions = {
    ResizeEdge.top: Offset(150, 3),
    ResizeEdge.left: Offset(3, 100),
    ResizeEdge.right: Offset(297, 100),
    ResizeEdge.bottom: Offset(150, 197),
    ResizeEdge.topLeft: Offset(3, 3),
    ResizeEdge.topRight: Offset(297, 3),
    ResizeEdge.bottomLeft: Offset(3, 197),
    ResizeEdge.bottomRight: Offset(297, 197),
  };

  for (final entry in edgePositions.entries) {
    testWidgets('鼠标拖动 ${entry.key.name} 热区调用对应原生缩放方向', (tester) async {
      await tester.pumpWidget(
        _harness(const WindowResizeFrame(child: SizedBox.expand())),
      );

      await tester.dragFrom(
        entry.value,
        const Offset(30, 30),
        kind: PointerDeviceKind.mouse,
      );
      // DragToResizeArea 也注册双击手势，推进时间以清理点击追踪计时器。
      await tester.pump(const Duration(milliseconds: 500));

      final resizeCalls = calls.where((call) => call.method == 'startResizing');
      expect(resizeCalls, hasLength(1));
      expect(resizeCalls.single.arguments, {
        'resizeEdge': entry.key.name,
        'top': const {
          ResizeEdge.top,
          ResizeEdge.topLeft,
          ResizeEdge.topRight,
        }.contains(entry.key),
        'bottom': const {
          ResizeEdge.bottom,
          ResizeEdge.bottomLeft,
          ResizeEdge.bottomRight,
        }.contains(entry.key),
        'left': const {
          ResizeEdge.left,
          ResizeEdge.topLeft,
          ResizeEdge.bottomLeft,
        }.contains(entry.key),
        'right': const {
          ResizeEdge.right,
          ResizeEdge.topRight,
          ResizeEdge.bottomRight,
        }.contains(entry.key),
      });
    });
  }

  testWidgets('默认热区透明且宽 6px，不改变内容尺寸或位置', (tester) async {
    const contentKey = ValueKey('content');
    await tester.pumpWidget(
      _harness(
        const WindowResizeFrame(child: SizedBox.expand(key: contentKey)),
      ),
    );

    final area = tester.widget<DragToResizeArea>(find.byType(DragToResizeArea));
    expect(area.resizeEdgeSize, 6);
    expect(area.resizeEdgeColor, const Color(0x00000000));
    expect(tester.getSize(find.byKey(contentKey)), const Size(300, 200));
    expect(tester.getTopLeft(find.byKey(contentKey)), Offset.zero);
    expect(tester.getSize(find.byType(DragToResizeArea)), const Size(300, 200));
  });

  testWidgets('中心内容点击和拖动不被缩放覆盖层拦截', (tester) async {
    var taps = 0;
    var drags = 0;
    await tester.pumpWidget(
      _harness(
        WindowResizeFrame(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            onPanStart: (_) => drags++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(150, 100));
    await tester.dragFrom(
      const Offset(150, 100),
      const Offset(30, 30),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    expect(taps, 1);
    expect(drags, 1);
    expect(calls.where((call) => call.method == 'startResizing'), isEmpty);
  });

  testWidgets('禁用后四边四角由内容接收拖动，不调用原生缩放', (tester) async {
    var drags = 0;
    await tester.pumpWidget(
      _harness(
        WindowResizeFrame(
          enabled: false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => drags++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.byType(DragToResizeArea), findsNothing);
    for (final position in edgePositions.values) {
      await tester.dragFrom(
        position,
        const Offset(30, 30),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
    }

    expect(drags, edgePositions.length);
    expect(calls.where((call) => call.method == 'startResizing'), isEmpty);
  });

  testWidgets('开关热区保留内容状态、尺寸和位置', (tester) async {
    final contentKey = GlobalKey<_StatefulContentState>();

    Future<void> pumpFrame(bool enabled) async {
      await tester.pumpWidget(
        _harness(
          WindowResizeFrame(
            enabled: enabled,
            child: _StatefulContent(key: contentKey),
          ),
        ),
      );
    }

    await pumpFrame(true);
    final state = contentKey.currentState;
    final size = tester.getSize(find.byKey(contentKey));
    final position = tester.getTopLeft(find.byKey(contentKey));

    await pumpFrame(false);
    expect(contentKey.currentState, same(state));
    expect(tester.getSize(find.byKey(contentKey)), size);
    expect(tester.getTopLeft(find.byKey(contentKey)), position);
    expect(find.byType(DragToResizeArea), findsNothing);

    await pumpFrame(true);
    expect(contentKey.currentState, same(state));
    expect(tester.getSize(find.byKey(contentKey)), size);
    expect(tester.getTopLeft(find.byKey(contentKey)), position);
    expect(find.byType(DragToResizeArea), findsOneWidget);
  });
}

class _StatefulContent extends StatefulWidget {
  const _StatefulContent({super.key});

  @override
  State<_StatefulContent> createState() => _StatefulContentState();
}

class _StatefulContentState extends State<_StatefulContent> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
