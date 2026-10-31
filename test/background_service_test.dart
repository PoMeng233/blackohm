import 'dart:io';
import 'dart:typed_data';

import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/data/game_repository.dart';
import 'package:blackohm/features/background/background_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  test('解析 Bangumi 游戏图片候选并按图片字段回退', () {
    const body = '''{
      "data": [
        {"id": 42, "name": "Visual Novel", "images": {"common": "https://img/common.jpg"}},
        {"id": 43, "name_cn": "中文标题", "images": {"large": "https://img/large.jpg"}},
        {"id": 44, "name": "No Image", "images": {}}
      ]
    }''';

    final result = parseBangumiSubjectsJson(body);
    expect(result, hasLength(2));
    expect(result.first.imageUrl, 'https://img/common.jpg');
    expect(result.first.subjectUrl, 'https://bgm.tv/subject/42');
    expect(result.last.title, '中文标题');
  });

  test('搜索词清洗发行信息，保留视觉小说主体标题', () {
    expect(
      normalizeBangumiSearchQuery('(18禁ゲーム) [230224] [枕] サクラノ刻 ―櫻の森の下を歩む― 通常版'),
      'サクラノ刻 ―櫻の森の下を歩む―',
    );
  });

  test('空响应或非法 JSON 返回空候选', () {
    expect(parseBangumiSubjectsJson('{}'), isEmpty);
    expect(parseBangumiSubjectsJson('not-json'), isEmpty);
  });

  test('识别 Bangumi Subject 链接及常见 URL 变体', () {
    expect(parseBangumiSubjectId('https://bgm.tv/subject/42'), 42);
    expect(parseBangumiSubjectId('https://bangumi.tv/subject/42/'), 42);
    expect(
      parseBangumiSubjectId('https://www.chii.in/subject/42?from=search#top'),
      42,
    );
    expect(parseBangumiSubjectId('http://www.bgm.tv/subject/114514'), 114514);
  });

  test('拒绝非游戏主条目的 Bangumi 链接', () {
    expect(parseBangumiSubjectId('https://example.com/subject/42'), isNull);
    expect(parseBangumiSubjectId('https://bgm.tv/subject/0'), isNull);
    expect(parseBangumiSubjectId('https://bgm.tv/subject/42/ep/1'), isNull);
    expect(parseBangumiSubjectId('https://bgm.tv/person/42'), isNull);
    expect(parseBangumiSubjectId('https://api.bgm.tv/v0/subjects/42'), isNull);
    expect(parseBangumiSubjectId('bgm.tv/subject/42'), isNull);
  });

  test('解析单条 Bangumi 游戏 Subject JSON', () {
    const body = '''{
      "id": 42,
      "type": 4,
      "name": "Japanese Title",
      "name_cn": "中文标题",
      "images": {"large": "https://img/large.jpg"}
    }''';
    final result = parseBangumiGameSubjectJson(body);
    expect(result, isNotNull);
    expect(result!.title, '中文标题');
    expect(result.subjectUrl, 'https://bgm.tv/subject/42');
    expect(result.imageUrl, 'https://img/large.jpg');
    expect(result.id, 42);
    expect(result.score, isNull);
  });

  test('解析首个 Subject 时会带出评分', () {
    const body = '''{
      "id": 7,
      "type": 4,
      "name": "Game",
      "name_cn": "游戏",
      "images": {"large": "https://img/large.jpg"},
      "rating": {"score": 8.6}
    }''';
    final result = parseBangumiGameSubjectJson(body);
    expect(result, isNotNull);
    expect(result!.score, 8.6);
  });

  test('日文条目 name_cn 为空字符串时回退到 name（280839 验收）', () {
    const body = '''{
      "id": 280839,
      "type": 4,
      "name": "鍵を隠したカゴのトリ-Bird in cage hiding the key-",
      "name_cn": "",
      "images": {"large": "https://img/l.jpg"}
    }''';
    final result = parseBangumiGameSubjectJson(body);
    expect(result, isNotNull);
    expect(result!.title, '鍵を隠したカゴのトリ-Bird in cage hiding the key-');
    expect(result.nameCn, isNull);
  });

  test('单条 Subject 仅接受游戏且必须有图片', () {
    expect(
      parseBangumiGameSubjectJson(
        '{"id": 1, "type": 2, "name": "动画", "images": {"large": "a"}}',
      ),
      isNull,
    );
    expect(
      parseBangumiGameSubjectJson('{"id": 1, "type": 4, "name": "无图"}'),
      isNull,
    );
    expect(parseBangumiGameSubjectJson('not-json'), isNull);
  });

  test('全量游戏搜索请求省略 nsfw 筛选', () {
    final payload = buildBangumiSearchPayload('游戏 通常版');
    expect(payload['keyword'], '游戏');
    expect(payload['sort'], 'match');
    expect(payload['filter'], {
      'type': [4],
    });
    expect((payload['filter'] as Map).containsKey('nsfw'), isFalse);
  });

  test('详情背景派生图会安全拒绝非法图像', () {
    expect(createDetailBackgroundBytesForTest([0, 1, 2]), isNull);
  });

  for (final size in [(1200, 600), (600, 1200), (120, 60), (60, 120)]) {
    test('详情背景派生图保留 ${size.$1}×${size.$2} 原图比例且不放大小图', () {
      final source = img.Image(width: size.$1, height: size.$2);
      final bytes = createDetailBackgroundBytesForTest(img.encodePng(source));
      expect(bytes, isNotNull);
      final output = img.decodePng(Uint8List.fromList(bytes!));
      expect(output, isNotNull);
      final scale = size.$1 > 960 || size.$2 > 960 ? 0.8 : 1.0;
      expect(output!.width, (size.$1 * scale).round());
      expect(output.height, (size.$2 * scale).round());
      expect(output.width / output.height, size.$1 / size.$2);
    });
  }

  test('派生缓存版本识别只接受 v2 路径', () {
    expect(isCurrentDetailBackground(null), isFalse);
    expect(isCurrentDetailBackground(''), isFalse);
    expect(isCurrentDetailBackground('image.detail-blur-v1.png'), isFalse);
    expect(isCurrentDetailBackground('image.detail-blur-v2.png'), isTrue);
  });

  group('详情背景缓存与迁移', () {
    late Directory root;
    late BackgroundCacheService cache;
    late AppDatabase database;
    late GameRepository repository;
    late String sourcePath;

    Future<Game> insertGame({String? background, String? detail}) async {
      final id = await repository.insert(
        GamesCompanion.insert(
          title: '测试游戏',
          exePath: p.join(root.path, 'game.exe'),
          dirPath: root.path,
          backgroundPath: Value(background),
          detailBackgroundPath: Value(detail),
        ),
      );
      return (await repository.watchById(id).first)!;
    }

    setUp(() async {
      root = await Directory.systemTemp.createTemp('blackohm_background_');
      cache = BackgroundCacheService(
        directory: Directory(p.join(root.path, 'cache')),
      );
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = GameRepository(database);
      sourcePath = p.join(root.path, 'source.png');
      await File(
        sourcePath,
      ).writeAsBytes(img.encodePng(img.Image(width: 120, height: 60)));
    });

    tearDown(() async {
      await database.close();
      await root.delete(recursive: true);
    });

    test('跨实例并发生成同一完整缓存且后续读取复用文件', () async {
      final paths = await Future.wait(
        List.generate(
          8,
          (_) => BackgroundCacheService(
            directory: Directory(p.join(root.path, 'cache')),
          ).createDetailBackground(sourcePath),
        ),
      );
      expect(paths.every((path) => path != null), isTrue);
      expect(paths.toSet(), hasLength(1));
      final target = File(paths.first!);
      expect(isCurrentDetailBackground(target.path), isTrue);
      final decoded = img.decodePng(await target.readAsBytes());
      expect(decoded!.width, 120);
      expect(decoded.height, 60);
      final modified = await target.lastModified();
      expect(await cache.createDetailBackground(sourcePath), target.path);
      expect(await target.lastModified(), modified);
      expect(await target.parent.list().length, 1);
    });

    test('不同目录的同名原图不会共用派生缓存', () async {
      final second = File(p.join(root.path, 'other', 'source.png'));
      await second.parent.create();
      await second.writeAsBytes(
        img.encodePng(img.Image(width: 60, height: 120)),
      );
      final firstPath = await cache.createDetailBackground(sourcePath);
      final secondPath = await cache.createDetailBackground(second.path);
      expect(firstPath, isNotNull);
      expect(secondPath, isNotNull);
      expect(secondPath, isNot(firstPath));
      final secondImage = img.decodePng(await File(secondPath!).readAsBytes());
      expect(secondImage!.width, 60);
      expect(secondImage.height, 120);
    });

    for (final oldDetail in [null, 'legacy.detail-blur-v1.png']) {
      test('迁移 ${oldDetail ?? '空'} 派生路径并保留原图和旧文件', () async {
        final oldPath = oldDetail == null ? null : p.join(root.path, oldDetail);
        if (oldPath != null) await File(oldPath).writeAsBytes([1, 2, 3]);
        final game = await insertGame(background: sourcePath, detail: oldPath);
        expect(
          await cache.migrateGameDetailBackground(
            game: game,
            repository: repository,
          ),
          isTrue,
        );
        final updated = (await repository.watchById(game.id).first)!;
        expect(updated.backgroundPath, sourcePath);
        expect(isCurrentDetailBackground(updated.detailBackgroundPath), isTrue);
        expect(await File(updated.detailBackgroundPath!).exists(), isTrue);
        expect(await File(sourcePath).exists(), isTrue);
        if (oldPath != null) {
          expect(await File(oldPath).readAsBytes(), [1, 2, 3]);
        }
        expect(
          await cache.migrateGameDetailBackground(
            game: updated,
            repository: repository,
          ),
          isFalse,
        );
      });
    }

    for (final invalid in ['missing', 'corrupt']) {
      test('$invalid 原图迁移失败且不写回派生路径', () async {
        if (invalid == 'missing') {
          await File(sourcePath).delete();
        } else {
          await File(sourcePath).writeAsBytes([0, 1, 2]);
        }
        final game = await insertGame(
          background: sourcePath,
          detail: 'old.detail-blur-v1.png',
        );
        expect(
          await cache.migrateGameDetailBackground(
            game: game,
            repository: repository,
          ),
          isFalse,
        );
        final unchanged = (await repository.watchById(game.id).first)!;
        expect(unchanged.backgroundPath, sourcePath);
        expect(unchanged.detailBackgroundPath, game.detailBackgroundPath);
      });
    }

    test('无原图游戏不会生成缓存', () async {
      final game = await insertGame();
      expect(
        await cache.migrateGameDetailBackground(
          game: game,
          repository: repository,
        ),
        isFalse,
      );
      expect(await Directory(p.join(root.path, 'cache')).exists(), isFalse);
    });

    test('停止条件阻止启动生成以及生成后的写回', () async {
      final game = await insertGame(background: sourcePath);
      expect(
        await cache.migrateGameDetailBackground(
          game: game,
          repository: repository,
          shouldContinue: () => false,
        ),
        isFalse,
      );
      expect(await Directory(p.join(root.path, 'cache')).exists(), isFalse);
      var checks = 0;
      expect(
        await cache.migrateGameDetailBackground(
          game: game,
          repository: repository,
          shouldContinue: () => ++checks == 1,
        ),
        isFalse,
      );
      expect(checks, 2);
      expect(
        (await repository.watchById(game.id).first)!.detailBackgroundPath,
        isNull,
      );
    });

    for (final change in ['source', 'detail', 'clear', 'delete']) {
      test('旧快照迁移不会覆盖 $change 操作', () async {
        final game = await insertGame(
          background: sourcePath,
          detail: 'old.detail-blur-v1.png',
        );
        switch (change) {
          case 'source':
            await repository.update(
              game.id,
              const GamesCompanion(backgroundPath: Value('new.png')),
            );
          case 'detail':
            await repository.update(
              game.id,
              const GamesCompanion(detailBackgroundPath: Value('chosen.png')),
            );
          case 'clear':
            await repository.update(
              game.id,
              const GamesCompanion(
                backgroundPath: Value(null),
                detailBackgroundPath: Value(null),
              ),
            );
          case 'delete':
            await repository.delete(game.id);
        }
        final before = await repository.watchById(game.id).first;
        expect(
          await cache.migrateGameDetailBackground(
            game: game,
            repository: repository,
          ),
          isFalse,
        );
        final after = await repository.watchById(game.id).first;
        expect(after?.backgroundPath, before?.backgroundPath);
        expect(after?.detailBackgroundPath, before?.detailBackgroundPath);
        if (change == 'delete') expect(after, isNull);
      });
    }

    test('空旧路径的条件写回不会覆盖后续选择的派生图', () async {
      final game = await insertGame(background: sourcePath);
      await repository.update(
        game.id,
        const GamesCompanion(detailBackgroundPath: Value('chosen.png')),
      );
      expect(
        await cache.migrateGameDetailBackground(
          game: game,
          repository: repository,
        ),
        isFalse,
      );
      expect(
        (await repository.watchById(game.id).first)!.detailBackgroundPath,
        'chosen.png',
      );
    });
  });
}
