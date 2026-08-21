/// 极简 PNG 编码器（RGBA8 → PNG）。
///
/// 仅为 PE 图标提取服务：ICO 内部是 DIB 位图，转成 RGBA 后
/// 用标准 CRC32 + dart:io 的 zlib 即可打包成合法 PNG，
/// 无需引入重量级图像库，保持零额外依赖。
library;

import 'dart:io';
import 'dart:typed_data';

final Uint32List _crcTable = _buildCrcTable();

Uint32List _buildCrcTable() {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    table[n] = c;
  }
  return table;
}

int _crc32(Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

Uint8List _be32(int v) => Uint8List(4)
  ..[0] = (v >> 24) & 0xFF
  ..[1] = (v >> 16) & 0xFF
  ..[2] = (v >> 8) & 0xFF
  ..[3] = v & 0xFF;

Uint8List _chunk(String type, Uint8List data) {
  final typeBytes = Uint8List.fromList(type.codeUnits);
  final crcInput = Uint8List.fromList([...typeBytes, ...data]);
  return Uint8List.fromList([
    ..._be32(data.length),
    ...typeBytes,
    ...data,
    ..._be32(_crc32(crcInput)),
  ]);
}

/// RGBA（行序自上而下）→ PNG 字节。width*height*4 == rgba.length。
Uint8List encodePngRgba(int width, int height, Uint8List rgba) {
  assert(rgba.length == width * height * 4, 'RGBA 尺寸不匹配');

  // 每行前置 filter type 0（None）
  final stride = width * 4;
  final raw = Uint8List(height * (stride + 1));
  for (var y = 0; y < height; y++) {
    final rowStart = y * (stride + 1);
    raw[rowStart] = 0;
    raw.setRange(rowStart + 1, rowStart + 1 + stride, rgba, y * stride);
  }

  final ihdr = Uint8List(13);
  ihdr.setRange(0, 4, _be32(width));
  ihdr.setRange(4, 8, _be32(height));
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // color type: RGBA
  // 10 压缩=0 11 滤波=0 12 隔行=0

  final idat = Uint8List.fromList(ZLibEncoder().convert(raw));

  return Uint8List.fromList([
    ...[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    ..._chunk('IHDR', ihdr),
    ..._chunk('IDAT', idat),
    ..._chunk('IEND', Uint8List(0)),
  ]);
}
