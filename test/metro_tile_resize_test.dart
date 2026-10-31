import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/data/settings_repository.dart';
import 'package:blackohm/features/tracking/tracking_engine.dart';
import 'package:blackohm/providers.dart';
import 'package:blackohm/ui/pages/library_page.dart';
import 'package:blackohm/ui/theme.dart';
import 'package:blackohm/ui/widgets/game_card.dart';
import 'package:blackohm/ui/widgets/metro_tile_layout.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySettingsRepository extends SettingsRepository {
  _MemorySettingsRepository(super.db);

  final Map<String, String> values = {};

  @override
  Future<String> get(String key, {String defaultValue = ''}) async =>
      values[key] ?? defaultValue;

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (var i = 0; i < 4; i++) {
      await db
          .into(db.games)
          .insert(
            GamesCompanion.insert(
              title: 'G$i',
              exePath: 'c:\\games\\g$i\\game.exe',
              dirPath: 'c:\\games\\g$i',
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpLibrary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsRepoProvider.overrideWithValue(_MemorySettingsRepository(db)),
          gameIconProvider.overrideWith((ref, id) => Future.value(null)),
          trackingStateProvider.overrideWith(
            (ref) => Stream.value(TrackingPublicState.idle),
          ),
        ],
        child: MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(body: SizedBox.expand(child: LibraryPage())),
        ),
      ),
    );
    await tester.pump();
    // 入场动画最长 600ms + 错峰 280ms，等它结束再取磁贴坐标做拖拽。
    await tester.pump(const Duration(milliseconds: 900));
  }

  Finder gameCardOf(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(GameCard));

  Future<Game> readGame(String title) =>
      (db.select(db.games)..where((g) => g.title.equals(title))).getSingle();

  // 卸载 ProviderScope 后 drift 会排零时长定时器关闭流查询，补几帧清掉它。
  Future<void> disposeUi(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('从右边缘拉伸到宽砖并写入数据库', (tester) async {
    await pumpLibrary(tester);
    final metrics = MetroGridMetrics.forWidth(1080 - 40);
    final before = tester.getSize(gameCardOf('G1'));
    expect(before.width, closeTo(metrics.tileExtent, 0.001));

    final rect = tester.getRect(gameCardOf('G1'));
    final gesture = await tester.startGesture(
      Offset(rect.right - 4, rect.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(Offset(rect.right + 20, rect.center.dy));
    await tester.pump();
    await gesture.moveTo(Offset(rect.right + 90, rect.center.dy));
    await tester.pump();

    expect(find.text('宽 2×1'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('宽 2×1'), findsNothing);
    expect(
      (await readGame('G1')).tileSize,
      metroTileSizeToCode(MetroTileSize.wide),
    );
    expect(
      tester.getSize(gameCardOf('G1')).width,
      closeTo(metrics.widthFor(MetroTileSize.wide), 0.001),
    );
    expect(tester.takeException(), isNull);
    await disposeUi(tester);
  });

  testWidgets('从下边缘拉伸到竖砖并保持其余磁贴尺寸', (tester) async {
    await pumpLibrary(tester);
    final metrics = MetroGridMetrics.forWidth(1080 - 40);
    final rect = tester.getRect(gameCardOf('G2'));

    final gesture = await tester.startGesture(
      Offset(rect.center.dx, rect.bottom - 4),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(Offset(rect.center.dx, rect.bottom + 20));
    await tester.pump();
    await gesture.moveTo(Offset(rect.center.dx, rect.bottom + 90));
    await tester.pump();
    expect(find.text('竖 1×2'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      (await readGame('G2')).tileSize,
      metroTileSizeToCode(MetroTileSize.tall),
    );
    expect(
      tester.getSize(gameCardOf('G2')).height,
      closeTo(metrics.heightFor(MetroTileSize.tall), 0.001),
    );
    expect(
      tester.getSize(gameCardOf('G3')).width,
      closeTo(metrics.tileExtent, 0.001),
    );
    expect(tester.takeException(), isNull);
    await disposeUi(tester);
  });

  testWidgets('右键菜单可恢复自动尺寸', (tester) async {
    await db.update(db.games).write(GamesCompanion(tileSize: const Value(2)));

    await pumpLibrary(tester);
    final rect = tester.getRect(gameCardOf('G0'));
    await tester.tapAt(rect.center, buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('磁贴尺寸'), findsOneWidget);
    expect(find.text('自动（随列数调整）'), findsOneWidget);

    await tester.tap(find.text('自动（随列数调整）'));
    await tester.pumpAndSettle();

    expect((await readGame('G0')).tileSize, 0);
    expect(tester.takeException(), isNull);
    await disposeUi(tester);
  });

  testWidgets('右键菜单直接指定大砖', (tester) async {
    await pumpLibrary(tester);
    final metrics = MetroGridMetrics.forWidth(1080 - 40);
    final rect = tester.getRect(gameCardOf('G3'));
    await tester.tapAt(rect.center, buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('大 2×2'));
    await tester.pumpAndSettle();

    expect(
      (await readGame('G3')).tileSize,
      metroTileSizeToCode(MetroTileSize.large),
    );
    expect(
      tester.getSize(gameCardOf('G3')).width,
      closeTo(metrics.widthFor(MetroTileSize.large), 0.001),
    );
    expect(
      tester.getSize(gameCardOf('G3')).height,
      closeTo(metrics.heightFor(MetroTileSize.large), 0.001),
    );
    expect(tester.takeException(), isNull);
    await disposeUi(tester);
  });
}
