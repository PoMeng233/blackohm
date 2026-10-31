/// 版本更新检测。
///
/// 每次启动静默查询 GitHub 最新 Release，与当前版本比较；
/// 有新版时由设置页「关于」在版本号旁显示提示，**不弹窗、不打断使用**。
/// 网络/代理失败一律静默忽略（返回 null），不影响启动。
library;

import 'dart:convert';
import 'dart:io';

import '../../core/network/proxy_resolver.dart';

/// GitHub API 主机与仓库（与 `kGitHubReleasesUrl` 保持一致）。
const String kGitHubApiHost = 'api.github.com';
const String kGitHubRepoSlug = 'PoMeng233/blackohm';

/// 进程内共享的代理解析器：与 Bangumi 请求一样走自适应代理。
final ProxyResolver updateProxyResolver = ProxyResolver();

/// 从 GitHub release JSON 中提取版本号（去掉 `v` 前缀）。
String? parseLatestVersionFromReleaseJson(String body) {
  if (body.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final tag = (decoded['tag_name'] ?? '').toString().trim();
    if (tag.isEmpty) return null;
    final version = tag.startsWith('v') || tag.startsWith('V')
        ? tag.substring(1)
        : tag;
    return version.isEmpty ? null : version;
  } catch (_) {
    return null;
  }
}

/// 比较 `x.y.z` 形式版本：a 更新返回正数，相同返回 0，更旧返回负数。
/// 段数不同时缺失段按 0 处理（`0.3` 等于 `0.3.0`）。
int compareVersions(String a, String b) {
  final left = _segments(a);
  final right = _segments(b);
  if (left == null || right == null) return 0;
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l > r ? 1 : -1;
  }
  return 0;
}

/// [latest] 是否比 [current] 更新；任一版本无法解析时返回 false（不误报）。
bool isNewerVersion({required String current, required String latest}) {
  final left = _segments(current);
  final right = _segments(latest);
  if (left == null || right == null) return false;
  return compareVersions(latest, current) > 0;
}

List<int>? _segments(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  // 去掉构建号（+8）与预发布后缀（-beta）。
  final core = value.split('+').first.split('-').first;
  if (core.isEmpty) return null;
  final parts = core.split('.');
  final out = <int>[];
  for (final part in parts) {
    final number = int.tryParse(part.trim());
    if (number == null) return null;
    out.add(number);
  }
  return out.isEmpty ? null : out;
}

/// 查询 GitHub 最新 Release 的版本号；失败返回 null（静默）。
Future<String?> fetchLatestReleaseVersion({
  Duration timeout = const Duration(seconds: 8),
  ProxyResolver? resolver,
}) async {
  final result = await withProxyFallback<String>(
    host: kGitHubApiHost,
    resolver: resolver ?? updateProxyResolver,
    attempt: (client) async {
      final request = await client
          .getUrl(
            Uri.parse(
              'https://$kGitHubApiHost/repos/$kGitHubRepoSlug/releases/latest',
            ),
          )
          .timeout(timeout);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'BlackOhm-Updater');
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      return (statusCode: response.statusCode, value: ok ? body : '');
    },
  );
  final body = result.value;
  if (body == null || body.isEmpty) return null;
  return parseLatestVersionFromReleaseJson(body);
}
