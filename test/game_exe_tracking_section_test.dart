import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/providers.dart';
import 'package:blackohm/ui/widgets/game_exe_tracking_section.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('显示主程序与别名，并可移除别名', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final gameId = await db
        .into(db.games)
        .insert(
          GamesCompanion.insert(
            title: '宝石心',
            exePath: r'g:\jewelry\jeweha.exe',
            dirPath: r'g:\jewelry',
          ),
        );
    await db
        .into(db.gameAliases)
        .insert(
          GameAliasesCompanion.insert(
            gameId: gameId,
            exePath: r'g:\jewelry\patch\patch.exe',
            dirPath: r'g:\jewelry\patch',
          ),
        );
    final game = await (db.select(
      db.games,
    )..where((g) => g.id.equals(gameId))).getSingle();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GameExeTrackingSection(game: game),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('跟踪的 EXE'), findsOneWidget);
    expect(find.text(r'g:\jewelry\jeweha.exe'), findsOneWidget);
    expect(find.text(r'g:\jewelry\patch\patch.exe'), findsOneWidget);

    await tester.tap(find.byTooltip('移除别名'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();

    expect(await db.select(db.gameAliases).get(), isEmpty);

    // 主动卸载组件，让 drift 取消流订阅后调度的零延迟 Timer 在本帧内跑完。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
