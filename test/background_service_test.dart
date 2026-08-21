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
}
