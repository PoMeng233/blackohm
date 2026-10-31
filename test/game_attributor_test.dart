import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/features/tracking/game_attributor.dart';
import 'package:flutter_test/flutter_test.dart';

Game _game({
  required int id,
  required String title,
  required String exePath,
  required String dirPath,
}) {
  return Game(
    id: id,
    title: title,
    exePath: exePath,
    dirPath: dirPath,
    backgroundBlurAmount: 0,
    launchArgs: '',
    useLocaleEmulator: false,
    leProfile: '',
    launchCount: 0,
    createdAt: DateTime(2026, 1, 1),
    totalPlaySeconds: 0,
    favorite: false,
    tileSize: 0,
  );
}

void main() {
  final attr = GameAttributor();
  attr.rebuild([
    _game(
      id: 100,
      title: '宝石心',
      exePath: r'g:\galgame\jewelry_chs\jeweha_chs_1.0.exe',
      dirPath: r'g:\galgame\jewelry_chs',
    ),
    _game(
      id: 101,
      title: 'AnotherGame',
      exePath: r'g:\games\another\another.exe',
      dirPath: r'g:\games\another',
    ),
  ]);

  group('精确命中', () {
    test('前台镜像路径等于库内 exePath 时直接命中', () {
      expect(
        attr.resolve(
          imagePath: r'g:\galgame\jewelry_chs\jeweha_chs_1.0.exe',
          commandLine: null,
          windowTitle: '宝石心',
          visible: true,
        ),
        100,
      );
    });

    test('不可见窗口不命中', () {
      expect(
        attr.resolve(
          imagePath: r'g:\galgame\jewelry_chs\jeweha_chs_1.0.exe',
          commandLine: null,
          windowTitle: '宝石心',
          visible: false,
        ),
        isNull,
      );
    });
  });

  group('EVB 包装壳归因', () {
    test('临时 stub + 命令行核心名（含版本后缀）可命中', () {
      expect(
        attr.resolve(
          imagePath: r'c:\users\pomeng\appdata\local\temp\evbA12A.tmp',
          commandLine: 'jeweha_chs.exe',
          windowTitle: '宝石心',
          visible: true,
        ),
        100,
      );
    });

    test('命令行带完整路径时同样命中', () {
      expect(
        attr.resolve(
          imagePath: r'c:\users\pomeng\appdata\local\temp\evb1234.tmp',
          commandLine: r'"g:\galgame\jewelry_chs\jeweha_chs_1.0.exe"',
          windowTitle: '',
          visible: true,
        ),
        100,
      );
    });

    test('命令行缺失时用唯一窗口标题兜底', () {
      expect(
        attr.resolve(
          imagePath: r'c:\users\pomeng\appdata\local\temp\evb5678.tmp',
          commandLine: null,
          windowTitle: '宝石心',
          visible: true,
        ),
        100,
      );
    });

    test('非临时目录的前台进程不做补充归因', () {
      expect(
        attr.resolve(
          imagePath: r'c:\program files\chrome\chrome.exe',
          commandLine: 'chrome.exe',
          windowTitle: '宝石心',
          visible: true,
        ),
        isNull,
      );
    });

    test('多个候选歧义时返回 null 而非猜测', () {
      final a = GameAttributor();
      a.rebuild([
        _game(
          id: 1,
          title: 'A',
          exePath: r'g:\a\game_chs.exe',
          dirPath: r'g:\a',
        ),
        _game(
          id: 2,
          title: 'B',
          exePath: r'g:\b\game_1.0.exe',
          dirPath: r'g:\b',
        ),
      ]);
      expect(
        a.resolve(
          imagePath: r'c:\users\pomeng\appdata\local\temp\evb9999.tmp',
          commandLine: 'game.exe',
          windowTitle: '',
          visible: true,
        ),
        isNull,
      );
    });
  });

  group('别名 exe', () {
    final aliasAttr = GameAttributor();
    aliasAttr.rebuild(
      [
        _game(
          id: 100,
          title: '宝石心',
          exePath: r'g:\galgame\jewelry\jeweha.exe',
          dirPath: r'g:\galgame\jewelry',
        ),
      ],
      [
        GameAlias(
          id: 1,
          gameId: 100,
          exePath: r'g:\galgame\jewelry\patch\patch_chs.exe',
          dirPath: r'g:\galgame\jewelry\patch',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    test('别名路径精确命中并返回命中路径', () {
      final match = aliasAttr.resolveMatch(
        imagePath: r'g:\galgame\jewelry\patch\patch_chs.exe',
        commandLine: null,
        windowTitle: '',
        visible: true,
      );
      expect(match, isNotNull);
      expect(match!.gameId, 100);
      expect(match.matchedExePath, r'g:\galgame\jewelry\patch\patch_chs.exe');
      expect(match.matchedExeFileName, 'patch_chs.exe');
    });

    test('包装壳命令行匹配别名主名时收敛到同一张卡', () {
      expect(
        aliasAttr.resolve(
          imagePath: r'c:\users\pomeng\appdata\local\temp\evbXYZ.tmp',
          commandLine: 'patch_chs.exe',
          windowTitle: '',
          visible: true,
        ),
        100,
      );
    });

    test('exeFileNamesFor 同时包含主程序与别名', () {
      expect(aliasAttr.exeFileNamesFor(100), {'jeweha.exe', 'patch_chs.exe'});
    });
  });
}
