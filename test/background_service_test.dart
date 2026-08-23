import 'package:blackohm/features/background/background_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
