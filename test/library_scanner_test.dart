import 'dart:io';

import 'package:blackohm/features/scanner/library_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('blackohm_library_test_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('顶层含 exe 时判定为单款游戏而非库', () async {
    await _write(root, 'Shamrock.exe');
    await _write(root, 'pac/voice.ypf');
    await _write(root, 'sub_a/a.exe');

    final layout = detectLibraryLayout(root.path);

    expect(layout.isLibrary, isFalse);
    expect(layout.games, isEmpty);
  });

  test('只有一个子目录含 exe 时不判定为库', () async {
    await _write(root, 'GameA/GameA.exe');
    await _write(root, 'readme.txt');

    final layout = detectLibraryLayout(root.path);

    expect(layout.isLibrary, isFalse);
    expect(layout.games, isEmpty);
  });

  test('顶层无 exe 且多个子目录各含 exe 时判定为库并逐款列出', () async {
    await _write(root, 'GameA/GameA.exe');
    await _write(root, 'GameB/GameB.exe');
    await _write(root, 'GameC/bin/GameC.exe');

    final layout = detectLibraryLayout(root.path);

    expect(layout.isLibrary, isTrue);
    expect(layout.truncated, isFalse);
    expect(layout.games.map((g) => _basename(g.dirPath)).toSet(), {
      'GameA',
      'GameB',
      'GameC',
    });
    for (final game in layout.games) {
      expect(game.candidates, isNotEmpty);
    }
  });

  test('黑名单目录与隐藏目录中的 exe 不计入游戏', () async {
    await _write(root, 'GameA/GameA.exe');
    await _write(root, 'GameB/GameB.exe');
    await _write(root, 'vcredist/vc_redist.x64.exe');
    await _write(root, '.hidden/Hidden.exe');

    final layout = detectLibraryLayout(root.path);

    expect(layout.isLibrary, isTrue);
    expect(layout.games.map((g) => _basename(g.dirPath)).toSet(), {
      'GameA',
      'GameB',
    });
  });

  test('每款游戏的候选按评分降序，名称匹配目录者优先', () async {
    await _write(root, 'GameA/GameA.exe', bytes: 1024);
    await _write(root, 'GameA/setup_tool.exe', bytes: 8 * 1024 * 1024);
    await _write(root, 'GameB/GameB.exe');

    final layout = detectLibraryLayout(root.path);
    final gameA = layout.games.firstWhere(
      (g) => _basename(g.dirPath) == 'GameA',
    );

    // 名称与目录一致获得 +50 评分，优先于体积更大的工具程序。
    expect(_basename(gameA.candidates.first.path), 'GameA.exe');
  });

  test('超过上限时截断并标记 truncated', () async {
    for (var i = 0; i < 4; i++) {
      await _write(root, 'Game$i/Game$i.exe');
    }

    final layout = detectLibraryLayout(root.path, maxGames: 2);

    expect(layout.isLibrary, isTrue);
    expect(layout.games, hasLength(2));
    expect(layout.truncated, isTrue);
  });

  test('空目录既不判定为库也不报游戏', () async {
    final layout = detectLibraryLayout(root.path);

    expect(layout.isLibrary, isFalse);
    expect(layout.games, isEmpty);
  });
}

Future<File> _write(Directory root, String relative, {int bytes = 1}) async {
  final separator = Platform.pathSeparator;
  final file = File(
    '${root.path}$separator${relative.split('/').join(separator)}',
  );
  await file.parent.create(recursive: true);
  return file.writeAsBytes(List<int>.filled(bytes, 0));
}

String _basename(String path) => path.split(Platform.pathSeparator).last;
