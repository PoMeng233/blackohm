import 'package:blackohm/core/database/app_database.dart';
import 'package:blackohm/features/background/background_service.dart';
import 'package:blackohm/features/background/bangumi_title_matcher.dart';
import 'package:blackohm/features/bangumi/bangumi_enrichment_service.dart';
import 'package:flutter_test/flutter_test.dart';

Game _game({
  required int id,
  required String title,
  required String exePath,
  required String dirPath,
}) => Game(
  id: id,
  title: title,
  exePath: exePath,
  dirPath: dirPath,
  backgroundBlurAmount: 0,
  launchArgs: '',
  useLocaleEmulator: false,
  leProfile: '',
  createdAt: DateTime(2026, 1, 1),
  totalPlaySeconds: 0,
  favorite: false,
  launchCount: 0,
);

BangumiImageCandidate _c(
  String title, {
  int? id,
  String? name,
  String? nameCn,
}) => BangumiImageCandidate(
  title: title,
  subjectUrl: id == null ? 'https://bgm.tv' : 'https://bgm.tv/subject/$id',
  imageUrl: 'https://img/x.jpg',
  id: id,
  name: name,
  nameCn: nameCn,
);

void main() {
  group('Bangumi 标题匹配器', () {
    test('唯一且完全正确的候选会被采用', () {
      final full = [_c('愛娘という名の玩具', id: 265113, name: '愛娘という名の玩具')];
      final picked = BangumiTitleMatcher.pickBest(full, '愛娘という名の玩具');
      expect(picked!.id, 265113);
    });

    test('唯一搜索结果名称完全不对时绝不采用（爱娘验收）', () {
      final wrong = [_c('別の全く無関係なタイトル', id: 484413, name: '別の全く無関係なタイトル')];
      expect(BangumiTitleMatcher.pickBest(wrong, '愛娘という名の玩具'), isNull);
    });

    test('键隠すカゴのトリ不会匹配到「100门挑战」', () {
      final wrong = [_c('100门挑战 - 找到厕所的钥匙', id: 999, nameCn: '100门挑战 - 找到厕所的钥匙')];
      expect(BangumiTitleMatcher.pickBest(wrong, '鍵を隠したカゴのトリ'), isNull);
    });

    test('多候选时取唯一可信的那个', () {
      final list = [
        _c('無関係なゲーム', id: 100, name: '無関係なゲーム'),
        _c('愛娘という名の玩具', id: 265113, name: '愛娘という名の玩具'),
      ];
      final picked = BangumiTitleMatcher.pickBest(list, '愛娘という名の玩具');
      expect(picked!.id, 265113);
    });

    test('多候选都不可信时不猜测', () {
      final list = [
        _c('宝石心', id: 100, nameCn: '宝石心'),
        _c('花吻', id: 200, nameCn: '花吻'),
      ];
      expect(BangumiTitleMatcher.pickBest(list, '无关查询'), isNull);
    });
  });

  group('搜索词回退', () {
    test('标题为引擎/exe名时用文件夹名搜索', () {
      final g = _game(
        id: 1,
        title: 'ExHIBIT',
        exePath: r'g:\galgame\kagotori\ExHIBIT.exe',
        dirPath: r'g:\galgame\kagotori',
      );
      expect(BangumiEnrichmentCoordinator.searchQueryForGame(g), 'kagotori');
    });

    test('标题已是真实游戏名时直接用标题', () {
      final g = _game(
        id: 2,
        title: '愛娘という名の玩具',
        exePath: r'g:\galgame\aimusume\game.exe',
        dirPath: r'g:\galgame\aimusume',
      );
      expect(
        BangumiEnrichmentCoordinator.searchQueryForGame(g),
        '愛娘という名の玩具',
      );
    });
  });

  group('BangumiEnrichmentCoordinator.pickUnique', () {
    test('委托给匹配器：单个错误结果返回 null', () {
      final wrong = [_c('別のゲーム', id: 484413, name: '別のゲーム')];
      expect(
        BangumiEnrichmentCoordinator.pickUnique(wrong, '愛娘という名の玩具'),
        isNull,
      );
    });
  });
}
