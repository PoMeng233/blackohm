/// PE（Portable Executable）解析器：纯 Dart、零依赖。
///
/// 解析链路：
///   DOS Header → PE 签名 → COFF → Optional Header
///   → DataDirectory[RESOURCE] → .rsrc 节区 RVA→文件偏移映射
///   → 资源目录树（Type/Name/Language 三层）
///       ├─ RT_VERSION(16)   → VS_VERSIONINFO → FileDescription / ProductName…
///       └─ RT_GROUP_ICON(14) → 最优 GRPICONDIRENTRY → RT_ICON(3) DIB
///            → 32/24/8/4bpp DIB 解码 → RGBA → PNG
///
/// 全部同步实现，调用方需在 Isolate.run 中执行以免阻塞 UI。
library;

import 'dart:io';
import 'dart:typed_data';

import 'png_encoder.dart';

class PeInfo {
  const PeInfo({
    this.fileDescription,
    this.productName,
    this.fileVersion,
    this.originalFilename,
    this.iconPng,
  });

  final String? fileDescription;
  final String? productName;
  final String? fileVersion;
  final String? originalFilename;
  final Uint8List? iconPng;

  /// 图标缺失时的兜底展示名。
  String get bestTitle =>
      fileDescription?.trim().isNotEmpty == true
          ? fileDescription!.trim()
          : productName?.trim().isNotEmpty == true
              ? productName!.trim()
              : '';
}

/// 解析失败返回 null（非 PE 文件 / 损坏 / 权限不足）。
PeInfo? parsePeFile(String exePath) {
  final Uint8List buf;
  try {
    buf = File(exePath).readAsBytesSync();
  } catch (_) {
    return null;
  }
  return _PeParser(buf).parse();
}

class _Section {
  const _Section(this.virtualAddress, this.virtualSize, this.rawSize,
      this.rawPointer);
  final int virtualAddress;
  final int virtualSize;
  final int rawSize;
  final int rawPointer;
}

class _PeParser {
  _PeParser(this.buf) : bd = ByteData.sublistView(buf);

  final Uint8List buf;
  final ByteData bd;

  List<_Section> _sections = const [];
  int _resourceRva = 0;
  int _resourceFileOffset = -1;

  PeInfo? parse() {
    try {
      if (!_loadHeaders()) return null;
      final version = _parseVersion();
      final icon = _parseIcon();
      if (version == null && icon == null) {
        return PeInfo(
            fileDescription: null,
            productName: null,
            fileVersion: null,
            originalFilename: null,
            iconPng: null);
      }
      return PeInfo(
        fileDescription: version?['FileDescription'],
        productName: version?['ProductName'],
        fileVersion: version?['FileVersion'],
        originalFilename: version?['OriginalFilename'],
        iconPng: icon,
      );
    } catch (_) {
      return null; // 任何解析异常一律降级（游戏数据不受影响）
    }
  }

  // ── 头部 ─────────────────────────────────────────────────────

  bool _loadHeaders() {
    if (buf.length < 0x40) return false;
    if (bd.getUint16(0, Endian.little) != 0x5A4D) return false; // 'MZ'
    final peOff = bd.getUint32(0x3C, Endian.little);
    if (peOff <= 0 || peOff + 24 > buf.length) return false;
    if (bd.getUint32(peOff, Endian.little) != 0x00004550) return false; // 'PE\0\0'

    final coff = peOff + 4;
    final numSections = bd.getUint16(coff + 2, Endian.little);
    final sizeOfOpt = bd.getUint16(coff + 16, Endian.little);
    final optStart = peOff + 24;
    if (optStart + sizeOfOpt > buf.length) return false;

    final optMagic = bd.getUint16(optStart, Endian.little);
    const pe32 = 0x10B, pe32Plus = 0x20B;
    if (optMagic != pe32 && optMagic != pe32Plus) return false;

    // 数据目录：PE32 起始 96，PE32+ 起始 112；资源目录 = 索引 2。
    final dirStart = optStart + (optMagic == pe32Plus ? 112 : 96);
    if (dirStart + 8 * 3 > optStart + sizeOfOpt) return false;
    _resourceRva = bd.getUint32(dirStart + 2 * 8, Endian.little);

    final secStart = optStart + sizeOfOpt;
    if (secStart + numSections * 40 > buf.length) return false;
    _sections = List.generate(
      numSections,
      (i) {
        final s = secStart + i * 40;
        return _Section(
          bd.getUint32(s + 12, Endian.little),
          bd.getUint32(s + 8, Endian.little),
          bd.getUint32(s + 16, Endian.little),
          bd.getUint32(s + 20, Endian.little),
        );
      },
      growable: false,
    );

    _resourceFileOffset = _rvaToOffset(_resourceRva);
    return _resourceFileOffset >= 0;
  }

  /// RVA → 文件偏移；越界返回 -1。
  int _rvaToOffset(int rva) {
    if (rva <= 0) return -1;
    for (final s in _sections) {
      final span = s.virtualSize > 0 ? s.virtualSize : s.rawSize;
      if (rva >= s.virtualAddress && rva < s.virtualAddress + span) {
        final off = s.rawPointer + (rva - s.virtualAddress);
        return off < buf.length ? off : -1;
      }
    }
    // 头部内 RVA（极罕见：无节区映射）
    return rva < buf.length ? rva : -1;
  }

  // ── 资源树 ───────────────────────────────────────────────────

  /// 返回资源树某一层的 (id, 指针) 列表；[dirFileOffset] 为目录文件偏移。
  /// 指针高位置 1 表示子目录，否则为 DATA_ENTRY。
  List<(int, int)> _dirEntries(int dirFileOffset) {
    if (dirFileOffset < 0 || dirFileOffset + 16 > buf.length) return const [];
    final named =
        bd.getUint16(dirFileOffset + 12, Endian.little); // 仅取 ID 项
    final idCount = bd.getUint16(dirFileOffset + 14, Endian.little);
    final out = <(int, int)>[];
    for (var i = 0; i < idCount; i++) {
      final e = dirFileOffset + 16 + (named + i) * 8;
      if (e + 8 > buf.length) break;
      final id = bd.getUint32(e, Endian.little) & 0x7FFFFFFF;
      final target = bd.getUint32(e + 4, Endian.little);
      out.add((id, target));
    }
    return out;
  }

  /// 按 [typeId]（RT_*）取第一个叶子数据（Uint8List 视图拷贝）。
  Uint8List? _resourceData(int typeId) {
    final level1 = _dirEntries(_resourceFileOffset);
    for (final (id, t1) in level1) {
      if (id != typeId) continue;
      final dir1 = _resourceFileOffset + (t1 & 0x7FFFFFFF);
      final level2 = _dirEntries(dir1);
      if (level2.isEmpty) continue;
      final (_, t2) = level2.first;
      if (t2 & 0x80000000 == 0) continue; // 叶子直接出现在第 2 层（异常布局）
      final dir2 = _resourceFileOffset + (t2 & 0x7FFFFFFF);
      final level3 = _dirEntries(dir2);
      if (level3.isEmpty) continue;
      final (_, t3) = level3.first;
      if (t3 & 0x80000000 != 0) continue;
      final entryOff = _resourceFileOffset + t3;
      if (entryOff + 16 > buf.length) continue;
      final dataRva = bd.getUint32(entryOff, Endian.little);
      final size = bd.getUint32(entryOff + 4, Endian.little);
      final off = _rvaToOffset(dataRva);
      if (off < 0 || off + size > buf.length) continue;
      return Uint8List.sublistView(buf, off, off + size);
    }
    return null;
  }

  // ── 版本信息（VS_VERSIONINFO）────────────────────────────────

  static const _wantedKeys = {
    'FileDescription',
    'ProductName',
    'FileVersion',
    'OriginalFilename',
  };

  Map<String, String>? _parseVersion() {
    final blob = _resourceData(16); // RT_VERSION
    if (blob == null || blob.length < 64) return null;
    final map = _parseVersionStructural(blob);
    return (map == null || map.isEmpty) ? _parseVersionLenient(blob) : map;
  }

  /// 结构化解析：wValueLen / szKey / 32 位对齐逐层下钻。
  /// 约定：顶层 Value（VS_FIXEDFILEINFO）按字节计；String 层按 WORD 计；
  /// StringFileInfo / StringTable 层 wValueLen 恒为 0。
  /// 防死循环铁律：每轮外层迭代必须前进，否则 +4 跳过。
  Map<String, String>? _parseVersionStructural(Uint8List b) {
    final bd = ByteData.sublistView(b);
    final result = <String, String>{};

    String keyAt(int p) {
      final start = p;
      var q = p;
      while (q + 1 < b.length && !(b[q] == 0 && b[q + 1] == 0)) {
        q += 2;
      }
      if (q + 1 >= b.length) throw const FormatException('截断的 szKey');
      return _utf16(b, start, q - start);
    }

    try {
      // 顶层 VS_VERSION_INFO
      final fixedLen = bd.getUint16(0, Endian.little); // 字节
      final topKey = keyAt(4);
      if (topKey != 'VS_VERSION_INFO') throw const FormatException();
      var pos = (4 + topKey.length * 2 + 2 + 3) & ~3; // 值起始（对齐后）
      pos = ((pos + fixedLen) + 3) & ~3; // 跳过 fixed info

      // 子块层：只关心 StringFileInfo；其余（VarFileInfo 等）跳过。
      while (pos + 6 <= b.length) {
        final blockStart = pos;
        final blockValueLen = bd.getUint16(pos, Endian.little);
        var q = pos + 4;
        final blockKey = keyAt(q);
        q += blockKey.length * 2 + 2;
        q = (q + 3) & ~3;
        final childStart = q + blockValueLen;

        if (blockKey == 'StringFileInfo') {
          // StringTable 层（'040904b0' 等；现实文件仅一张表，取第一张）
          var t = (childStart + 3) & ~3;
          if (t + 6 <= b.length) {
            final stValueLen = bd.getUint16(t, Endian.little);
            var tq = t + 4;
            final stKey = keyAt(tq);
            tq += stKey.length * 2 + 2;
            tq = (tq + 3) & ~3;
            var s = (tq + stValueLen + 3) & ~3;

            // String 层：键值对本体，解析至资源尾部
            while (s + 6 <= b.length) {
              final sStart = s;
              final vWords = bd.getUint16(s, Endian.little);
              if (vWords >= b.length) break; // 破损防线
              var sq = s + 4;
              final sKey = keyAt(sq);
              sq += sKey.length * 2 + 2;
              sq = (sq + 3) & ~3;
              final vBytes = vWords * 2;
              if (_wantedKeys.contains(sKey) &&
                  vWords > 0 &&
                  sq + vBytes <= b.length) {
                final v = _utf16(b, sq, vBytes);
                if (v.isNotEmpty) result[sKey] = v;
              }
              final next =
                  (sStart + 4 + sKey.length * 2 + 2 + vBytes + 3) & ~3;
              if (next <= sStart) break; // 前进失败防线
              s = next;
            }
          }
          break; // 已取到全部目标键，结束扫描
        }
        pos = blockStart + 4; // 未知块：强制前进防死循环
      }
    } on FormatException {
      if (result.isEmpty) return null;
    } on RangeError {
      if (result.isEmpty) return null;
    }
    return result.isEmpty ? null : result;
  }

  /// 宽松兜底：直接在版本资源里搜目标键的 UTF-16 编码，
  /// 跳过对齐空字节后读取后续 UTF-16 字符串。
  Map<String, String>? _parseVersionLenient(Uint8List b) {
    final result = <String, String>{};
    for (final key in _wantedKeys) {
      final pat = _utf16Encode(key);
      final idx = _indexOf(b, pat);
      if (idx < 0) continue;
      var p = idx + pat.length;
      // 跳过键结尾 NUL 与对齐填充（最多 6 字节）
      var skipped = 0;
      while (p + 1 < b.length && skipped < 6) {
        if (b[p] == 0 && b[p + 1] == 0) {
          p += 2;
          skipped += 2;
        } else if (b[p] == 0 && b[p + 1] != 0 && p % 2 == 1) {
          p += 1;
          skipped += 1;
        } else {
          break;
        }
      }
      final start = p;
      while (p + 1 < b.length && !(b[p] == 0 && b[p + 1] == 0)) {
        p += 2;
      }
      final v = _utf16(b, start, p - start);
      if (v.isNotEmpty && !result.containsKey(key)) result[key] = v;
    }
    return result.isEmpty ? null : result;
  }

  static String _utf16(Uint8List b, int start, int byteLen) {
    final words = byteLen ~/ 2;
    final sb = StringBuffer();
    for (var i = 0; i < words; i++) {
      final c = b[start + i * 2] | (b[start + i * 2 + 1] << 8);
      if (c == 0) break;
      sb.writeCharCode(c);
    }
    return sb.toString();
  }

  static Uint8List _utf16Encode(String s) {
    final out = Uint8List(s.length * 2);
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      out[i * 2] = c & 0xFF;
      out[i * 2 + 1] = c >> 8;
    }
    return out;
  }

  static int _indexOf(Uint8List haystack, Uint8List needle) {
    outer:
    for (var i = 0; i + needle.length <= haystack.length; i += 2) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  // ── 图标（RT_GROUP_ICON → RT_ICON DIB）──────────────────────

  Uint8List? _parseIcon() {
    final group = _resourceData(14); // RT_GROUP_ICON
    if (group == null || group.length < 6) return null;
    final gbd = ByteData.sublistView(group);
    final count = gbd.getUint16(4, Endian.little);
    if (count == 0) return null;

    // 最优条目：面积优先，同面积取色深更高者。
    var best = -1, bestScore = -1;
    for (var i = 0; i < count && 6 + (i + 1) * 14 <= group.length; i++) {
      final e = 6 + i * 14;
      final w = group[e] == 0 ? 256 : group[e];
      final h = group[e + 1] == 0 ? 256 : group[e + 1];
      final bpp = gbd.getUint16(e + 6, Endian.little);
      final score = w * h * 100 + bpp;
      if (score > bestScore) {
        bestScore = score;
        best = gbd.getUint16(e + 12, Endian.little); // nId
      }
    }
    if (best < 0) return null;

    final dib = _iconById(best);
    if (dib == null) return null;
    return _dibToPng(dib);
  }

  Uint8List? _iconById(int iconId) {
    final level1 = _dirEntries(_resourceFileOffset);
    for (final (id, t1) in level1) {
      if (id != 3) continue; // RT_ICON
      final dir1 = _resourceFileOffset + (t1 & 0x7FFFFFFF);
      final level2 = _dirEntries(dir1);
      for (final (nameId, t2) in level2) {
        if (nameId != iconId) continue;
        final dir2 = _resourceFileOffset + (t2 & 0x7FFFFFFF);
        final level3 = _dirEntries(dir2);
        if (level3.isEmpty) return null;
        final (_, t3) = level3.first;
        if (t3 & 0x80000000 != 0) return null;
        final entryOff = _resourceFileOffset + t3;
        final dataRva = bd.getUint32(entryOff, Endian.little);
        final size = bd.getUint32(entryOff + 4, Endian.little);
        final off = _rvaToOffset(dataRva);
        if (off < 0 || off + size > buf.length) return null;
        return Uint8List.sublistView(buf, off, off + size);
      }
    }
    return null;
  }

  /// ICO 内嵌 DIB（BITMAPINFOHEADER + 调色板 + XOR + AND）→ PNG。
  Uint8List? _dibToPng(Uint8List d) {
    if (d.length < 40) return null;
    final dbd = ByteData.sublistView(d);
    final width = dbd.getInt32(4, Endian.little);
    final height2 = dbd.getInt32(8, Endian.little);
    final bpp = dbd.getUint16(14, Endian.little);
    if (width <= 0 || width > 256 || height2 <= 0) return null;
    final height = height2 ~/ 2;
    final biSize = dbd.getUint32(0, Endian.little);
    final clrUsed = dbd.getUint32(32, Endian.little);
    if (bpp != 32 && bpp != 24 && bpp != 8 && bpp != 4) return null;

    var p = biSize; // 调色板起始
    var palCount = 0;
    if (bpp <= 8) {
      palCount = clrUsed == 0 ? (1 << bpp) : clrUsed;
      if (p + palCount * 4 > d.length) return null;
    }

    final xorStride = ((width * bpp + 31) ~/ 32) * 4;
    final xorStart = p + palCount * 4;
    final andStride = ((width + 31) ~/ 32) * 4;
    final andStart = xorStart + xorStride * height;
    if (xorStart + xorStride * height > d.length) return null;
    final hasMask = andStart + andStride * height <= d.length;

    final rgba = Uint8List(width * height * 4);
    var allAlphaZero = bpp == 32;

    for (var y = 0; y < height; y++) {
      final srcY = height - 1 - y; // DIB 自底向上
      final rowOff = xorStart + srcY * xorStride;
      final andRow =
          hasMask ? andStart + srcY * andStride : -1;
      for (var x = 0; x < width; x++) {
        final o = (y * width + x) * 4;
        var r = 0, g = 0, b = 0, a = 255;
        switch (bpp) {
          case 32:
            final q = rowOff + x * 4;
            b = d[q];
            g = d[q + 1];
            r = d[q + 2];
            a = d[q + 3];
            if (a != 0) allAlphaZero = false;
          case 24:
            final q = rowOff + x * 3;
            b = d[q];
            g = d[q + 1];
            r = d[q + 2];
          case 8:
            final idx = d[rowOff + x];
            if (idx >= palCount) break;
            final q = biSize + idx * 4;
            b = d[q];
            g = d[q + 1];
            r = d[q + 2];
          case 4:
            final byte = d[rowOff + (x >> 1)];
            final idx = (x & 1) == 0 ? byte >> 4 : byte & 0x0F;
            if (idx >= palCount) break;
            final q = biSize + idx * 4;
            b = d[q];
            g = d[q + 1];
            r = d[q + 2];
        }
        if (hasMask && bpp < 32) {
          final maskBit =
              (d[andRow + (x >> 3)] >> (7 - (x & 7))) & 1;
          if (maskBit == 1) a = 0;
        }
        rgba[o] = r;
        rgba[o + 1] = g;
        rgba[o + 2] = b;
        rgba[o + 3] = a;
      }
    }
    // 旧式 32bpp 图标 alpha 全零：视为不透明。
    if (allAlphaZero) {
      for (var i = 3; i < rgba.length; i += 4) {
        rgba[i] = 255;
      }
    }
    return encodePngRgba(width, height, rgba);
  }
}
