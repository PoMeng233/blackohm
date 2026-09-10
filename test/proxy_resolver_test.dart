import 'package:blackohm/core/network/proxy_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseWindowsProxyServer', () {
    test('裸 host:port 直接返回', () {
      expect(parseWindowsProxyServer('127.0.0.1:2080'), '127.0.0.1:2080');
    });

    test('http=/https= 分段形式优先取 https', () {
      expect(
        parseWindowsProxyServer('http=1.2.3.4:8080;https=5.6.7.8:8443'),
        '5.6.7.8:8443',
      );
    });

    test('缺少 https 段时回退 http 段', () {
      expect(parseWindowsProxyServer('http=1.2.3.4:8080'), '1.2.3.4:8080');
    });

    test('空值或 null 返回 null', () {
      expect(parseWindowsProxyServer(''), isNull);
      expect(parseWindowsProxyServer(null), isNull);
    });
  });

  group('toFindProxyValue', () {
    test('规范化为 Dart findProxy 接受的 PROXY 形式', () {
      expect(toFindProxyValue('127.0.0.1:2080'), 'PROXY 127.0.0.1:2080');
    });

    test('剥离 http scheme', () {
      expect(toFindProxyValue('http://127.0.0.1:2080'), 'PROXY 127.0.0.1:2080');
    });

    test('SOCKS5 不被 Dart HttpClient 支持，返回 null', () {
      expect(toFindProxyValue('socks5://127.0.0.1:2080'), isNull);
    });

    test('缺少端口时返回 null', () {
      expect(toFindProxyValue('127.0.0.1'), isNull);
    });
  });

  group('isNoProxyHost', () {
    test('域名后缀命中', () {
      expect(isNoProxyHost('bgm.tv', 'api.bgm.tv'), isTrue);
    });

    test('未命中返回 false', () {
      expect(isNoProxyHost('example.com', 'api.bgm.tv'), isFalse);
    });

    test('空规则返回 false', () {
      expect(isNoProxyHost('', 'api.bgm.tv'), isFalse);
      expect(isNoProxyHost(null, 'api.bgm.tv'), isFalse);
    });
  });

  group('buildProxyCandidates', () {
    test('顺序为系统代理 → 环境变量 → 本机端口 → 直连', () {
      final candidates = buildProxyCandidates(
        targetHost: 'api.bgm.tv',
        windowsProxyServer: '127.0.0.1:1111',
        environment: const {'https_proxy': 'http://127.0.0.1:2222'},
        listeningLocalPorts: const [2080],
      );
      expect(candidates.map((c) => c.findProxy).toList(), <String>[
        'PROXY 127.0.0.1:1111',
        'PROXY 127.0.0.1:2222',
        'PROXY 127.0.0.1:2080',
        'DIRECT',
      ]);
    });

    test('重复地址去重且直连只保留在末尾', () {
      final candidates = buildProxyCandidates(
        targetHost: 'api.bgm.tv',
        windowsProxyServer: '127.0.0.1:2080',
        environment: const {'https_proxy': 'http://127.0.0.1:2080'},
        listeningLocalPorts: const [2080],
      );
      expect(candidates.map((c) => c.findProxy).toList(), <String>[
        'PROXY 127.0.0.1:2080',
        'DIRECT',
      ]);
    });

    test('no_proxy 覆盖目标主机时只返回直连', () {
      final candidates = buildProxyCandidates(
        targetHost: 'api.bgm.tv',
        windowsProxyServer: '127.0.0.1:2080',
        environment: const {'no_proxy': 'bgm.tv'},
      );
      expect(candidates.map((c) => c.findProxy).toList(), <String>['DIRECT']);
    });

    test('无任何代理来源时只有直连', () {
      final candidates = buildProxyCandidates(targetHost: 'api.bgm.tv');
      expect(candidates.map((c) => c.findProxy).toList(), <String>['DIRECT']);
    });

    test('SOCKS5 来源被跳过但仍保留直连兜底', () {
      final candidates = buildProxyCandidates(
        targetHost: 'api.bgm.tv',
        environment: const {'https_proxy': 'socks5://127.0.0.1:2080'},
      );
      expect(candidates.map((c) => c.findProxy).toList(), <String>['DIRECT']);
    });
  });
}
