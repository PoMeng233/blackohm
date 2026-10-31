import 'package:blackohm/features/update/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLatestVersionFromReleaseJson', () {
    test('从 GitHub release JSON 提取 tag_name 并去掉 v 前缀', () {
      expect(
        parseLatestVersionFromReleaseJson('{"tag_name":"v0.2.7"}'),
        '0.2.7',
      );
    });

    test('tag 没有 v 前缀时同样可用', () {
      expect(
        parseLatestVersionFromReleaseJson('{"tag_name":"0.2.7"}'),
        '0.2.7',
      );
    });

    test('缺少 tag_name 返回 null', () {
      expect(parseLatestVersionFromReleaseJson('{"name":"foo"}'), isNull);
    });

    test('非 JSON 或空内容返回 null', () {
      expect(parseLatestVersionFromReleaseJson('not json'), isNull);
      expect(parseLatestVersionFromReleaseJson(''), isNull);
    });
  });

  group('compareVersions', () {
    test('补零后逐段比较', () {
      expect(compareVersions('0.2.7', '0.2.6'), greaterThan(0));
      expect(compareVersions('0.2.6', '0.2.7'), lessThan(0));
      expect(compareVersions('0.2.6', '0.2.6'), 0);
    });

    test('按数值而非字典序比较多位数段', () {
      expect(compareVersions('0.2.10', '0.2.9'), greaterThan(0));
    });

    test('主版本号优先', () {
      expect(compareVersions('1.0.0', '0.9.9'), greaterThan(0));
    });

    test('段数不同时缺失段视为 0', () {
      expect(compareVersions('0.3', '0.3.0'), 0);
      expect(compareVersions('0.3.1', '0.3'), greaterThan(0));
    });
  });

  group('isNewerVersion', () {
    test('远端更高时为真', () {
      expect(isNewerVersion(current: '0.2.6', latest: '0.2.7'), isTrue);
    });

    test('相同版本为假', () {
      expect(isNewerVersion(current: '0.2.6', latest: '0.2.6'), isFalse);
    });

    test('远端更低（本地为预发布或更新）为假', () {
      expect(isNewerVersion(current: '0.2.7', latest: '0.2.6'), isFalse);
    });

    test('无法解析的版本号一律视为无更新', () {
      expect(isNewerVersion(current: 'dev', latest: '0.2.7'), isFalse);
      expect(isNewerVersion(current: '0.2.6', latest: 'unknown'), isFalse);
    });
  });
}
