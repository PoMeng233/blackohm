import 'dart:io';

import 'package:blackohm/core/path_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonicalPath', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('canonical_path_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('文件路径还原磁盘真实大小写', () {
      final file = File('${tempDir.path}${Platform.pathSeparator}MixedCase.Exe')
        ..writeAsStringSync('');
      final lower = file.path.toLowerCase();

      expect(canonicalPath(lower), canonicalPath(file.path));
    }, skip: !Platform.isWindows);

    test('目录路径还原磁盘真实大小写', () {
      final dir = Directory(
        '${tempDir.path}${Platform.pathSeparator}MixedCaseDir',
      )..createSync();
      final lower = dir.path.toLowerCase();

      expect(canonicalPath(lower), canonicalPath(dir.path));
    }, skip: !Platform.isWindows);

    test('不存在的路径原样返回', () {
      final missing = '${tempDir.path}${Platform.pathSeparator}not_here.exe';

      expect(canonicalPath(missing), missing);
    });
  });
}
