import 'package:blackohm/ui/motion.dart';
import 'package:blackohm/ui/widgets/metro_tile_appear.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录 initState 次数，用来确认重建时子树没有整体换掉。
class _Probe extends StatefulWidget {
  const _Probe({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 100, height: 100);
}

double _opacityOf(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(MetroTileAppear),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  testWidgets('scope 变化时整墙重播统一淡入', (tester) async {
    Widget build(String scope) => MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MetroTileAppear(
          animate: false,
          scope: scope,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );

    await tester.pumpWidget(build('all'));
    expect(find.byType(Opacity), findsNothing);

    await tester.pumpWidget(build('folder:1'));
    expect(_opacityOf(tester), 0);

    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacityOf(tester), greaterThan(0));
    expect(_opacityOf(tester), lessThan(1));

    await tester.pump(AppMotion.appear);
    expect(_opacityOf(tester), 1);
  });

  testWidgets('scope 不变的重建不重播', (tester) async {
    Widget build(String scope) => MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MetroTileAppear(
          animate: true,
          scope: scope,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );

    await tester.pumpWidget(build('folder:1'));
    await tester.pump(AppMotion.appear);
    expect(_opacityOf(tester), 1);

    await tester.pumpWidget(build('folder:1'));
    expect(_opacityOf(tester), 1);
  });

  testWidgets('入场期间父级重建不打断动画、不重建子树', (tester) async {
    var initCount = 0;
    Widget build(bool animate) => MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MetroTileAppear(
          animate: animate,
          child: _Probe(onInit: () => initCount++),
        ),
      ),
    );

    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(milliseconds: 100));
    final before = _opacityOf(tester);

    // 模拟入场期间的一次普通重建：页面再次构建时 animate 已因"播过"变 false。
    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 60));
    final after = _opacityOf(tester);

    expect(initCount, 1);
    expect(before, lessThan(1));
    expect(after, greaterThan(before));
    expect(after, lessThan(1));
  });

  testWidgets('不再播放时直接给出子组件', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MetroTileAppear(
            animate: false,
            child: SizedBox(width: 10, height: 10),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(MetroTileAppear),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  testWidgets('减少动态时不播放', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MetroTileAppear(
            animate: true,
            child: SizedBox(width: 10, height: 10),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(MetroTileAppear),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });
}
