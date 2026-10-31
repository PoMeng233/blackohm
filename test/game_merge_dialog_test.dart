import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/ui/widgets/game_merge_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Game _game({
  required int id,
  required String title,
  required String exePath,
  int totalPlaySeconds = 0,
  int launchCount = 0,
}) {
  return Game(
    id: id,
    title: title,
    exePath: exePath,
    dirPath: exePath.substring(0, exePath.lastIndexOf(r'\')),
    backgroundBlurAmount: 0,
    launchArgs: '',
    useLocaleEmulator: false,
    leProfile: '',
    launchCount: launchCount,
    createdAt: DateTime(2026, 1, 1),
    totalPlaySeconds: totalPlaySeconds,
    favorite: false,
    tileSize: 0,
  );
}

void main() {
  testWidgets('搜索并确认合并返回源游戏', (tester) async {
    final target = _game(id: 1, title: '目标', exePath: r'g:\t\t.exe');
    final source = _game(
      id: 2,
      title: '宝石心',
      exePath: r'g:\jewelry\jeweha.exe',
      totalPlaySeconds: 3600,
      launchCount: 3,
    );
    Game? picked;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showGameMergeDialog(
                    context,
                    target: target,
                    candidates: [source],
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('宝石心'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '宝石');
    await tester.pumpAndSettle();
    expect(find.text('宝石心'), findsOneWidget);

    await tester.tap(find.text('宝石心'));
    await tester.pumpAndSettle();
    expect(find.textContaining('此操作不可撤销'), findsOneWidget);

    await tester.tap(find.text('合并'));
    await tester.pumpAndSettle();
    expect(picked?.id, 2);
  });

  testWidgets('没有可合并的游戏时显示空状态', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showGameMergeDialog(
                  context,
                  target: _game(id: 1, title: '目标', exePath: r'g:\t\t.exe'),
                  candidates: const [],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('没有可合并的其他游戏'), findsOneWidget);
  });
}
