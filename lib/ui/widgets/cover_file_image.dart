import 'dart:io';

import 'package:flutter/material.dart';

/// A bounded, aspect-ratio-preserving decode followed by a display-only crop.
/// Supplying two dimensions to Image.file uses exact resizing and can distort
/// the source before BoxFit.cover ever sees it.
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
    errorBuilder: errorBuilder,
    gaplessPlayback: gaplessPlayback,
  );
}
