import 'dart:convert';
import 'dart:io';

import 'package:blackohm/ui/motion.dart';
import 'package:blackohm/ui/widgets/cover_file_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1×1 透明 PNG，测试只关心 frameBuilder 的契约，不解码。
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
    'z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  testWidgets('封面首帧解码后淡入，同步命中缓存时直接显示', (tester) async {
    final file = File('${Directory.systemTemp.path}/cover_fade_probe.png')
      ..writeAsBytesSync(base64Decode(_pngBase64));
    addTearDown(() {
      try {
        file.deleteSync();
      } on FileSystemException {
        // 解码线程可能仍持有句柄，临时文件留给系统清理。
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CoverFileImage(
            file: file,
            cacheWidth: 8,
            cacheHeight: 8,
            width: 8,
            height: 8,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final frameBuilder = image.frameBuilder!;
    final context = tester.element(find.byType(CoverFileImage));
    const child = SizedBox();

    final placeholder = frameBuilder(context, child, null, false);
    expect(placeholder, isA<AnimatedOpacity>());
    expect((placeholder as AnimatedOpacity).opacity, 0);
    expect(placeholder.duration, AppMotion.coverFade);

    final firstFrame = frameBuilder(context, child, 0, false);
    expect((firstFrame as AnimatedOpacity).opacity, 1);
    expect(firstFrame.duration, AppMotion.coverFade);

    // 缓存命中时不再补淡入，避免滚动回看闪一下。
    expect(frameBuilder(context, child, 0, true), same(child));
  });
}
