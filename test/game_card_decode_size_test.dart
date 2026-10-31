import 'dart:convert';
import 'dart:io';

import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/data/settings_repository.dart';
import 'package:blackohm/features/tracking/tracking_engine.dart';
import 'package:blackohm/providers.dart';
import 'package:blackohm/ui/theme.dart';
import 'package:blackohm/ui/widgets/cover_file_image.dart';
import 'package:blackohm/ui/widgets/game_card.dart';
import 'package:blackohm/ui/widgets/metro_tile_layout.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySettingsRepository extends SettingsRepository {
  _MemorySettingsRepository(super.db);

  @override
  Future<String> get(String key, {String defaultValue = ''}) async =>
      defaultValue;

  @override
  Future<void> set(String key, String value) async {}
}

// 1×1 透明 PNG，只用于让 backgroundPath 通过 existsSync 检查。
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late File cover;
  late Game game;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cover = File(
      '${Directory.systemTemp.createTempSync('blackohm-cover').path}/cover.png',
    )..writeAsBytesSync(base64Decode(_pngBase64));
    await db
        .into(db.games)
        .insert(
          GamesCompanion.insert(
            title: 'G',
            exePath: r'c:\games\g\game.exe',
            dirPath: r'c:\games\g',
            backgroundPath: Value(cover.path),
          ),
        );
    game = await db.select(db.games).getSingle();
  });

  tearDown(() async {
    await db.close();
    cover.parent.deleteSync(recursive: true);
  });

  int decodeWidthOf(WidgetTester tester) {
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(CoverFileImage),
        matching: find.byType(Image),
      ),
    );
    return (image.image as ResizeImage).width!;
  }

  testWidgets('重排动画期间封面解码尺寸保持稳定', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final width = ValueNotifier<double>(200);
    addTearDown(width.dispose);

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
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<double>(
                valueListenable: width,
                builder: (context, value, _) => AnimatedContainer(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.linear,
                  width: value,
                  height: value,
                  child: GameCard(
                    game: game,
                    tileSize: MetroTileSize.small,
                    decodeWidth: 144,
                    decodeHeight: 144,
                    onLaunch: () {},
                    onOpenDirectory: () {},
                    onOpenDetail: () {},
                    onDelete: () {},
                    onToggleFavorite: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(decodeWidthOf(tester), 144);

    // 模拟切换文件夹时的重排：磁贴盒子在 420ms 内变大。
    width.value = 320;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(decodeWidthOf(tester), 144, reason: '动画中途不应换缓存键');
    await tester.pump(const Duration(milliseconds: 240));
    expect(decodeWidthOf(tester), 144, reason: '动画结束仍保持同一解码尺寸');
  });
}
