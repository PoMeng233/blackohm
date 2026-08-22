import 'dart:typed_data';

import 'package:blackohm/core/path_normalizer.dart';
import 'package:blackohm/features/scanner/pe_info.dart';
import 'package:blackohm/features/scanner/png_encoder.dart';
import 'package:blackohm/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeExePath', () {
    test('小写化并统一反斜杠', () {
      expect(
        normalizeExePath(r'C:\Games\Foo\Game.EXE'),
        r'c:\games\foo\game.exe',
      );
    });

    test('剥离 \\\\?\\ 设备前缀', () {
      expect(normalizeExePath(r'\\?\C:\Games\a.exe'), r'c:\games\a.exe');
    });

    test('剥离尾部分隔符', () {
      expect(normalizeExePath(r'C:\Games\a.exe\'), r'c:\games\a.exe');
    });
  });

  group('encodePngRgba', () {
    test('输出合法 PNG 签名', () {
      final png = encodePngRgba(1, 1, Uint8List.fromList([0, 229, 163, 255]));
      expect(png.take(8).toList(), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      expect(png.length, greaterThan(40));
    });
  });

  group('isBoilerplateTitle', () {
    test('KiriKiri 内核自述被识别为样板文本', () {
      expect(
        isBoilerplateTitle(
          'TVP(KIRIKIRI) 2 core / Scripting Platform for Win32',
        ),
        isTrue,
      );
      expect(isBoilerplateTitle('krkr'), isTrue);
      expect(isBoilerplateTitle('KiriKiriZ'), isTrue);
    });

    test('正常游戏描述与空值不被过滤', () {
      expect(isBoilerplateTitle('FAVORITE 某某游戏'), isFalse);
      expect(isBoilerplateTitle('My Visual Novel'), isFalse);
      expect(isBoilerplateTitle(''), isTrue);
      expect(isBoilerplateTitle(null), isTrue);
    });
  });

  group('时长格式化', () {
    test('总时长以小时分钟展示', () {
      expect(formatPlayDuration(3661), '1 小时 1 分');
      expect(formatPlayDuration(45), '45 秒');
    });

    test('紧凑时长使用 h/m/s 且小时保留一位小数', () {
      expect(formatCompactPlayDuration(5400), '1.5h');
      expect(formatCompactPlayDuration(3600), '1.0h');
      expect(formatCompactPlayDuration(3599), '59m');
      expect(formatCompactPlayDuration(45), '45s');
      expect(formatCompactPlayDuration(0), '0s');
    });

    test('实时秒表使用稳定的数字位数', () {
      expect(formatStopwatch(83 * 1000), '01:23');
      expect(formatStopwatch((2 * 3600 + 3 * 60 + 4) * 1000), '02:03:04');
    });
  });
}
