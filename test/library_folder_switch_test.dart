import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/features/tracking/tracking_engine.dart';
import 'package:blackohm/providers.dart';
import 'package:blackohm/ui/pages/library_page.dart';
import 'package:blackohm/ui/theme.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Game> games;
  late List<GameFolder> folders;

  setUp(() async {
    // 只在 setup 阶段使用内存数据库构造快照；测试 UI 不再订阅 Drift watch，
    // 避免 widget teardown 与数据库关闭发生异步竞态。
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final seeded = await (db.select(
      db.gameFolders,
    )..where((f) => f.name.equals('在玩'))).getSingle();
    final folderId = seeded.id;
    await db
        .into(db.games)
        .insert(
          GamesCompanion.insert(
            title: 'Active Game',
            exePath: r'c:\games\active\game.exe',
            dirPath: r'c:\games\active',
            folderId: Value(folderId),
            totalPlaySeconds: const Value(3600),
          ),
        );
    await db
        .into(db.games)
        .insert(
          GamesCompanion.insert(
            title: 'Idle Game',
            exePath: r'c:\games\idle\game.exe',
            dirPath: r'c:\games\idle',
            totalPlaySeconds: const Value(60),
          ),
        );
    games = await db.select(db.games).get();
    folders = await db.select(db.gameFolders).get();
    await db.close();
  });

  Future<void> pumpLibrary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameListProvider.overrideWith((ref) => Stream.value(games)),
          folderListProvider.overrideWith((ref) => Stream.value(folders)),
          gameIconProvider.overrideWith((ref, id) => Future.value(null)),
          trackingStateProvider.overrideWith(
            (ref) => Stream.value(
              const TrackingPublicState(
                gameId: 1,
                elapsedMs: 65000,
                phase: TrackingPhase.live,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(body: SizedBox.expand(child: LibraryPage())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('活跃计时中切换文件夹不抛异常（网格视图）', (tester) async {
    await pumpLibrary(tester);
    // 主页只显示未分类游戏与文件夹入口。
    expect(find.text('Idle Game'), findsOneWidget);

    await tester.tap(find.text('在玩').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Active Game'), findsOneWidget);
    expect(find.text('Idle Game'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('全部游戏'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('未分类'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // 回到含活跃卡片的视图，让呼吸光效定时器跑几帧。
    await tester.tap(find.text('在玩').first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('活跃计时中切换文件夹不抛异常（列表视图）', (tester) async {
    await pumpLibrary(tester);
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('在玩').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Active Game'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('全部游戏'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
