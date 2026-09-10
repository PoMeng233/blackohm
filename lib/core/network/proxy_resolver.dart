/// Bangumi API 的代理自适应解析与回退。
///
/// 背景：Dart 的 `HttpClient` 默认只读 `http_proxy` / `https_proxy` / `no_proxy`
/// 环境变量，**不读 Windows 系统代理注册表**；且 `findProxy` 只接受
/// `PROXY host:port` 与 `DIRECT`（见 dart-sdk `_http/http_impl.dart` 的
/// `_ProxyConfiguration`），**不支持 SOCKS5**。
///
/// 因此这里把各类来源整理成有序候选，逐个尝试直到拿到 HTTP 响应：
///   系统代理 → 环境变量 → 本机常见代理端口 → 直连。
/// 常见本机端口覆盖 hysteria2 / clash / v2ray 等的默认监听端口。
library;

import 'dart:io';

import 'windows_proxy_registry.dart';

/// 一个代理候选。
class ProxyCandidate {
  const ProxyCandidate({required this.label, required this.findProxy});

  /// 展示用来源说明（系统代理 / 环境变量 / 本机端口 / 直连）。
  final String label;

  /// 传给 `HttpClient.findProxy` 的字符串。
  final String findProxy;

  @override
  String toString() => '$label ($findProxy)';
}

/// 常见本机代理端口（hysteria2 为 2080，clash 为 7890，v2ray 为 10808 等）。
const List<int> kCommonLocalProxyPorts = <int>[
  2080,
  7890,
  7891,
  1080,
  10808,
  10809,
  20171,
  20172,
  8889,
  8080,
];

const String kDirectProxy = 'DIRECT';

/// 解析 Windows 注册表 `ProxyServer` 值。
///
/// 支持裸 `host:port` 与 `http=host:port;https=host:port` 分段形式。
String? parseWindowsProxyServer(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  if (!value.contains('=')) return _normalizeHostPort(value);

  String? httpValue;
  for (final segment in value.split(';')) {
    final part = segment.trim();
    if (part.isEmpty) continue;
    final eq = part.indexOf('=');
    if (eq <= 0) continue;
    final scheme = part.substring(0, eq).trim().toLowerCase();
    final hostPort = part.substring(eq + 1).trim();
    if (scheme == 'https') return _normalizeHostPort(hostPort);
    if (scheme == 'http') httpValue ??= hostPort;
  }
  return _normalizeHostPort(httpValue);
}

/// 把 `host:port`（可带 http/https scheme）规范化为 Dart findProxy 字符串。
/// Dart 不支持的协议（SOCKS/SOCKS5 等）返回 null。
String? toFindProxyValue(String? hostPort) {
  final normalized = _normalizeHostPort(hostPort);
  return normalized == null ? null : 'PROXY $normalized';
}

String? _normalizeHostPort(String? raw) {
  var value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  if (value.toLowerCase().startsWith('socks')) return null;

  final schemeIndex = value.indexOf('://');
  if (schemeIndex >= 0) {
    final scheme = value.substring(0, schemeIndex).toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    value = value.substring(schemeIndex + 3);
  }
  value = value.split('/').first.trim();

  final colon = value.lastIndexOf(':');
  if (colon <= 0 || colon == value.length - 1) return null;
  final host = value.substring(0, colon).trim();
  final port = int.tryParse(value.substring(colon + 1).trim());
  if (host.isEmpty || port == null || port <= 0 || port > 65535) return null;
  return '$host:$port';
}

/// `no_proxy` / `NO_PROXY` 是否覆盖目标主机。
bool isNoProxyHost(String? noProxy, String host) {
  final raw = noProxy?.trim() ?? '';
  if (raw.isEmpty || host.isEmpty) return false;
  final target = host.toLowerCase();
  for (final entry in raw.split(',')) {
    final rule = entry.trim().toLowerCase();
    if (rule.isEmpty) continue;
    if (rule == '*') return true;
    if (target == rule || target.endsWith(rule)) return true;
  }
  return false;
}

/// 组装去重后的代理候选；没有任何代理来源时只返回直连。
List<ProxyCandidate> buildProxyCandidates({
  required String targetHost,
  String? windowsProxyServer,
  Map<String, String>? environment,
  Iterable<int> listeningLocalPorts = const <int>[],
}) {
  final env = environment ?? const <String, String>{};
  final noProxy = env['no_proxy'] ?? env['NO_PROXY'];
  if (isNoProxyHost(noProxy, targetHost)) {
    return const <ProxyCandidate>[
      ProxyCandidate(label: '直连', findProxy: kDirectProxy),
    ];
  }

  final candidates = <ProxyCandidate>[];
  final seen = <String>{};

  void add(String label, String? hostPort) {
    final findProxy = toFindProxyValue(hostPort);
    if (findProxy == null || !seen.add(findProxy)) return;
    candidates.add(ProxyCandidate(label: label, findProxy: findProxy));
  }

  add('系统代理', parseWindowsProxyServer(windowsProxyServer));
  add(
    '环境变量',
    env['https_proxy'] ??
        env['HTTPS_PROXY'] ??
        env['http_proxy'] ??
        env['HTTP_PROXY'] ??
        env['all_proxy'] ??
        env['ALL_PROXY'],
  );
  for (final port in listeningLocalPorts) {
    add('本机端口 $port', '127.0.0.1:$port');
  }
  candidates.add(const ProxyCandidate(label: '直连', findProxy: kDirectProxy));
  return candidates;
}

/// 探测本机正在监听的常见代理端口（TCP 连通即视为可用）。
Future<List<int>> probeLocalProxyPorts({
  Duration timeout = const Duration(milliseconds: 120),
}) async {
  final alive = <int>[];
  await Future.wait(
    kCommonLocalProxyPorts.map((port) async {
      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: timeout,
        );
        socket.destroy();
        alive.add(port);
      } catch (_) {
        // 端口未监听：忽略。
      }
    }),
  );
  alive.sort();
  return alive;
}

/// 带缓存的代理候选解析器：进程内复用，避免每次请求都探测端口。
class ProxyResolver {
  ProxyResolver({Future<List<int>> Function()? portProbe})
    : _portProbe = portProbe ?? probeLocalProxyPorts;

  final Future<List<int>> Function() _portProbe;
  List<ProxyCandidate>? _cached;
  String? _cachedHost;

  Future<List<ProxyCandidate>> candidatesFor(
    String host, {
    bool refresh = false,
  }) async {
    final cached = _cached;
    if (!refresh && cached != null && _cachedHost == host) return cached;
    final ports = await _portProbe();
    final resolved = buildProxyCandidates(
      targetHost: host,
      windowsProxyServer: readWindowsProxyServer(),
      environment: Platform.environment,
      listeningLocalPorts: ports,
    );
    _cached = resolved;
    _cachedHost = host;
    return resolved;
  }

  void invalidate() {
    _cached = null;
    _cachedHost = null;
  }
}

/// 一次网络请求的结果，附带实际生效的通道说明（用于设置页自检诊断）。
class ProxyRequestResult<T> {
  const ProxyRequestResult({
    this.value,
    this.statusCode,
    required this.channel,
    this.error,
  });

  final T? value;
  final int? statusCode;

  /// 实际生效的通道（如「系统代理」「本机端口 2080」「直连」）。
  final String channel;
  final String? error;

  bool get isSuccess => statusCode != null;
}

/// 依次尝试代理候选执行 [attempt]。
///
/// [attempt] 抛出异常（连接失败/超时等）视为该通道不可用，自动切换下一个；
/// 只要拿到 HTTP 响应就立即返回，不再尝试后续通道。
Future<ProxyRequestResult<T>> withProxyFallback<T>({
  required String host,
  required Future<({int statusCode, T value})> Function(HttpClient client)
  attempt,
  ProxyResolver? resolver,
}) async {
  final candidates = await (resolver ?? ProxyResolver()).candidatesFor(host);
  String? lastError;
  for (final candidate in candidates) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..findProxy = (uri) => candidate.findProxy;
    try {
      final result = await attempt(client);
      return ProxyRequestResult<T>(
        value: result.value,
        statusCode: result.statusCode,
        channel: candidate.label,
      );
    } catch (e) {
      lastError = e.toString();
    } finally {
      client.close(force: true);
    }
  }
  return ProxyRequestResult<T>(channel: '所有通道均不可用', error: lastError);
}
