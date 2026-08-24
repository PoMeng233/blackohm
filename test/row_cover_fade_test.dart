import 'package:blackohm/ui/pages/library_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const eps = 0.01;

  double edgeX(RowCoverFade f) => f.overlayLeft + f.overlayWidth * f.stops.last;

  void expectStrictlyIncreasing(List<double> stops) {
    for (var i = 1; i < stops.length; i++) {
      expect(stops[i], greaterThan(stops[i - 1]));
    }
  }

  group('横排封面渐隐几何（computeRowCoverFade）', () {

    test('典型大图：全不透明点精确落在图片右缘（修复硬切缝）', () {
      final f = computeRowCoverFade(rowWidth: 1200, imageWidth: 750);
      expect(f.overlayLeft, closeTo(570, eps));
      expect(f.overlayWidth, closeTo(252, eps));
      expect(edgeX(f), closeTo(750, eps));
      // stops 单调递增且末 stop < 1（覆盖区含冗余段）。
      expect(f.stops.first, 0.0);
      expect(f.stops[1], lessThan(f.stops[2]));
      expect(f.stops.last, lessThan(1.0));
    });

    test('fadeW 触及下限 clamp（小图）：右缘等式依然成立', () {
      final f = computeRowCoverFade(rowWidth: 1200, imageWidth: 50);
      // fadeW = max(50*0.24, 18) = 18
      expect(edgeX(f), closeTo(50, eps));
      expect(f.overlayLeft, greaterThanOrEqualTo(0));
      expectStrictlyIncreasing(f.stops);
    });

    test('fadeW 触及上限 clamp（大图）：右缘等式依然成立', () {
      final f = computeRowCoverFade(rowWidth: 1200, imageWidth: 900);
      expect(edgeX(f), closeTo(900, eps));
    });

    test('极窄行：无越界、无 NaN、stops 合法（零宽覆盖区安全退化）', () {
      final f = computeRowCoverFade(rowWidth: 60, imageWidth: 750);
      expect(f.overlayLeft, inInclusiveRange(0, 60));
      expect(f.overlayWidth, inInclusiveRange(0, 60));
      for (final s in f.stops) {
        expect(s.isNaN, isFalse);
        expect(s, inInclusiveRange(0.0, 1.0));
      }
      expectStrictlyIncreasing(f.stops);
    });

    test('imageWidth 为 0 的退化输入：不抛异常、stops 合法', () {
      final f = computeRowCoverFade(rowWidth: 800, imageWidth: 0);
      expect(f.overlayLeft, 0.0);
      expectStrictlyIncreasing(f.stops);
      expect(f.stops.last, inInclusiveRange(0.0, 1.0));
    });
  });
}
