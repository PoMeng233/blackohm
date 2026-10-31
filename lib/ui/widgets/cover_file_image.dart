import 'dart:io';

import 'package:flutter/material.dart';

import '../motion.dart';

/// A bounded, aspect-ratio-preserving decode followed by a display-only crop.
/// Supplying two dimensions to Image.file uses exact resizing and can distort
/// the source before BoxFit.cover ever sees it.
///
/// 位图解码是异步的：没有占位层时，解码完成的瞬间会硬切出封面，
/// 叠加入场淡入就像整墙在闪。这里给"非同步命中缓存"的首帧加一段
/// 淡入（不复制位图，只是同一帧的透明度过渡）。
class CoverFileImage extends StatelessWidget {
  const CoverFileImage({
    required this.file,
    required this.cacheWidth,
    required this.cacheHeight,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.errorBuilder,
    this.gaplessPlayback = false,
    this.fadeIn = true,
    super.key,
  }) : assert(cacheWidth > 0),
       assert(cacheHeight > 0);

  final File file;
  final int cacheWidth;
  final int cacheHeight;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;
  final bool gaplessPlayback;
  final bool fadeIn;

  @override
  Widget build(BuildContext context) => Image(
    image: ResizeImage(
      FileImage(file),
      width: cacheWidth,
      height: cacheHeight,
      policy: ResizeImagePolicy.fit,
    ),
    width: width,
    height: height,
    fit: BoxFit.cover,
    alignment: alignment,
    filterQuality: filterQuality,
    frameBuilder: !fadeIn
        ? null
        : (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: AppMotion.coverFade,
              curve: AppMotion.curve,
              child: child,
            );
          },
    errorBuilder: errorBuilder,
    gaplessPlayback: gaplessPlayback,
  );
}
