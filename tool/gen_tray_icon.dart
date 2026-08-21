/// 工具：生成 assets/tray.ico（32x32 赛博绿闪电图标内嵌 PNG）。
import 'dart:io';
import 'dart:typed_data';

import '../lib/features/scanner/png_encoder.dart';

void main() {
  const size = 32;
  final rgba = Uint8List(size * size * 4);

  // 绘制 32x32 深底 + 赛博青绿 (0x00, 0xE5, 0xA3) 闪电/点
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final o = (y * size + x) * 4;
      final dx = x - 15.5;
      final dy = y - 15.5;
      final dist = dx * dx + dy * dy;
      if (dist <= 14 * 14) {
        // 圆角深色背景
        rgba[o] = 0x16;
        rgba[o + 1] = 0x19;
        rgba[o + 2] = 0x1E;
        rgba[o + 3] = 0xFF;
        // 中心青绿核心
        if (dist <= 6 * 6) {
          rgba[o] = 0x00;
          rgba[o + 1] = 0xE5;
          rgba[o + 2] = 0xA3;
          rgba[o + 3] = 0xFF;
        }
      } else {
        // 透明外圈
        rgba[o + 3] = 0x00;
      }
    }
  }

  final pngBytes = encodePngRgba(size, size, rgba);

  // ICO 容器：Header(6) + Entry(16) + PNG bytes
  final ico = BytesBuilder();
  ico.add([0x00, 0x00]); // reserved
  ico.add([0x01, 0x00]); // type = 1 (icon)
  ico.add([0x01, 0x00]); // count = 1

  // ICONDIRENTRY
  ico.addByte(size); // width
  ico.addByte(size); // height
  ico.addByte(0); // colors
  ico.addByte(0); // reserved
  ico.add([0x01, 0x00]); // planes
  ico.add([0x20, 0x00]); // bitCount = 32
  // bytesInRes (4B LE)
  ico.add([
    pngBytes.length & 0xFF,
    (pngBytes.length >> 8) & 0xFF,
    (pngBytes.length >> 16) & 0xFF,
    (pngBytes.length >> 24) & 0xFF,
  ]);
  // imageOffset = 6 + 16 = 22 (4B LE)
  ico.add([0x16, 0x00, 0x00, 0x00]);

  ico.add(pngBytes);

  Directory('assets').createSync(recursive: true);
  File('assets/tray.ico').writeAsBytesSync(ico.toBytes());
  stdout.writeln('assets/tray.ico 生成成功 (${ico.length} 字节)');
}
