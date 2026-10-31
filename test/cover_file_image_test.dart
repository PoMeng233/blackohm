import 'dart:async';
import 'dart:io';

import 'package:blackohm/ui/widgets/cover_file_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('blackohm_cover_');
  });

  tearDown(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await temp.delete(recursive: true);
  });

  for (final sourceSize in [(800, 400), (400, 800), (600, 600)]) {
    testWidgets('解码 ${sourceSize.$1}×${sourceSize.$2} 原图保持比例并在显示时裁切', (
      tester,
    ) async {
      final file = File('${temp.path}/cover.png');
      final decoded = await tester.runAsync<ImageInfo>(() async {
        await file.writeAsBytes(
          img.encodePng(img.Image(width: sourceSize.$1, height: sourceSize.$2)),
        );
        return ResizeImage(
          FileImage(file),
          width: 360,
          height: 380,
          policy: ResizeImagePolicy.fit,
        ).resolve(ImageConfiguration.empty).completer!.getImage();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 180,
              height: 190,
              child: CoverFileImage(
                file: file,
                cacheWidth: 360,
                cacheHeight: 380,
              ),
            ),
          ),
        ),
      );

      final widget = tester.widget<Image>(find.byType(Image));
      final provider = widget.image as ResizeImage;
      expect(provider.policy, ResizeImagePolicy.fit);
      expect(widget.fit, BoxFit.cover);
      expect(widget.alignment, Alignment.center);
      expect(tester.getSize(find.byType(Image)), const Size(180, 190));

      expect(decoded, isNotNull);
      final image = decoded!.image;
      expect(image.width, lessThanOrEqualTo(360));
      expect(image.height, lessThanOrEqualTo(380));
      expect(
        image.width / image.height,
        closeTo(sourceSize.$1 / sourceSize.$2, 0.01),
      );
      final fitted = applyBoxFit(
        widget.fit!,
        Size(image.width.toDouble(), image.height.toDouble()),
        const Size(180, 190),
      );
      expect(fitted.destination, const Size(180, 190));
      expect(
        fitted.source.width / fitted.destination.width,
        closeTo(fitted.source.height / fitted.destination.height, 0.001),
      );
      decoded.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('缺失及无效图片使用占位，不抛出未处理图片异常', (tester) async {
    final invalid = File('${temp.path}/invalid.png');
    await tester.runAsync(() => invalid.writeAsString('not an image'));
    for (final file in [File('${temp.path}/missing.png'), invalid]) {
      await tester.pumpWidget(
        MaterialApp(
          home: CoverFileImage(
            file: file,
            cacheWidth: 360,
            cacheHeight: 380,
            errorBuilder: (_, _, _) => const Text('placeholder'),
          ),
        ),
      );
      for (
        var attempt = 0;
        attempt < 100 && find.text('placeholder').evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.text('placeholder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

extension on ImageStreamCompleter {
  Future<ImageInfo> getImage() {
    final result = Completer<ImageInfo>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        removeListener(listener);
        result.complete(info);
      },
      onError: (Object error, StackTrace? stack) {
        removeListener(listener);
        result.completeError(error, stack);
      },
    );
    addListener(listener);
    return result.future;
  }
}
