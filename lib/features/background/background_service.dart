/// 本地背景缓存与 Bangumi/BGM 图片候选服务。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BangumiImageCandidate {
  const BangumiImageCandidate({
    required this.title,
    required this.subjectUrl,
    required this.imageUrl,
    this.id,
    this.score,
    this.name,
    this.nameCn,
  });

  final String title;
  final String subjectUrl;
  final String imageUrl;

  /// Bangumi Subject ID（用于回写防重复拉取）。
  final int? id;

  /// 评分（0-10，来源为 Subject 的 rating.score）。
  final double? score;

  /// 原始语言名（通常为日文原名）。
  final String? name;

  /// 中文名（可为空）。
  final String? nameCn;
}

String normalizeBangumiSearchQuery(String value) {
  var query = value.trim();
  query = query.replaceAll(
    RegExp(r'\([^)]*(?:禁|ゲーム|版|通常|限定|特典)[^)]*\)', caseSensitive: false),
    ' ',
  );
  query = query.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
  query = query.replaceAll(
    RegExp(r'(通常版|初回版|限定版|DL版|高清版|中文版)', caseSensitive: false),
    ' ',
  );
  return query.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 从受信任的 Bangumi Subject 页面链接中提取条目 ID。
/// 仅接受主条目路径，避免把剧集、人物等链接误作游戏封面。
int? parseBangumiSubjectId(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  final host = uri.host.toLowerCase();
  const hosts = {
    'bgm.tv',
    'bangumi.tv',
    'chii.in',
    'www.bgm.tv',
    'www.bangumi.tv',
    'www.chii.in',
  };
  if (!hosts.contains(host)) return null;
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.length != 2 || segments.first != 'subject') return null;
  final id = int.tryParse(segments.last);
  return id != null && id > 0 ? id : null;
}

Map<String, Object> buildBangumiSearchPayload(String query) => {
  'keyword': normalizeBangumiSearchQuery(query),
  'filter': <String, Object>{
    'type': <int>[4],
  },
  'sort': 'match',
};

class BangumiImageSearchService {
  Future<BangumiImageCandidate?> fetchSubject({
    required int subjectId,
    required String token,
  }) async {
    return (await fetchSubjectDetailed(
      subjectId: subjectId,
      token: token,
    )).candidate;
  }

  /// 返回 HTTP 状态码与候选结果的诊断封装，便于设置页自检时给出明确提示。
  Future<({int? statusCode, BangumiImageCandidate? candidate})>
  fetchSubjectDetailed({required int subjectId, required String token}) async {
    if (subjectId <= 0 || token.trim().isEmpty) {
      return (statusCode: null, candidate: null);
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(
        Uri.parse('https://api.bgm.tv/v0/subjects/$subjectId'),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'BlackOhm/0.1.0');
      final auth = token.trim();
      request.headers.set(
        HttpHeaders.authorizationHeader,
        auth.toLowerCase().startsWith('bearer ') ? auth : 'Bearer $auth',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (statusCode: response.statusCode, candidate: null);
      }
      final body = await response.transform(utf8.decoder).join();
      return (
        statusCode: response.statusCode,
        candidate: parseBangumiGameSubjectJson(body),
      );
    } catch (e) {
      return (statusCode: null, candidate: null);
    } finally {
      client.close(force: true);
    }
  }

  Future<List<BangumiImageCandidate>> search({
    required String query,
    required String token,
  }) async {
    if (query.trim().isEmpty || token.trim().isEmpty) return const [];
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(
        Uri.parse('https://api.bgm.tv/v0/search/subjects?limit=10&offset=0'),
      );
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'BlackOhm/0.1.0');
      final auth = token.trim();
      request.headers.set(
        HttpHeaders.authorizationHeader,
        auth.toLowerCase().startsWith('bearer ') ? auth : 'Bearer $auth',
      );
      request.write(jsonEncode(buildBangumiSearchPayload(query)));
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final body = await response.transform(utf8.decoder).join();
      return parseBangumiSubjectsJson(body);
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }
}

List<BangumiImageCandidate> parseBangumiSubjectsJson(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['data'] is! List) return const [];
    return (decoded['data'] as List)
        .whereType<Map>()
        .map(parseBangumiSubject)
        .whereType<BangumiImageCandidate>()
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

/// 解析单个 Subject API 响应，并限制为 Bangumi 游戏条目。
BangumiImageCandidate? parseBangumiGameSubjectJson(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['type'] != 4) return null;
    return parseBangumiSubject(decoded);
  } catch (_) {
    return null;
  }
}

BangumiImageCandidate? parseBangumiSubject(Map value) {
  final name = (value['name'] ?? '').toString().trim();
  final nameCn = (value['name_cn'] ?? '').toString().trim();
  // 注意：很多 R18 日文条目的 name_cn 是空字符串（而非 null），
  // 必须回退到 name，否则会把正确条目当无标题丢弃，导致“搜不到/自检误报无权限”。
  final title = nameCn.isNotEmpty ? nameCn : name;
  final id = value['id'];
  final images = value['images'];
  if (title.isEmpty || images is! Map) return null;
  final image =
      (images['large'] ??
              images['common'] ??
              images['medium'] ??
              images['small'] ??
              images['grid'])
          ?.toString();
  if (image == null || image.isEmpty) return null;
  final rating = value['rating'];
  final rawScore = rating is Map ? rating['score'] : null;
  final score = rawScore is num ? rawScore.toDouble() : null;
  return BangumiImageCandidate(
    title: title,
    imageUrl: image,
    subjectUrl: id == null ? 'https://bgm.tv' : 'https://bgm.tv/subject/$id',
    id: id is num ? id.toInt() : null,
    score: score,
    name: name.isEmpty ? null : name,
    nameCn: nameCn.isEmpty ? null : nameCn,
  );
}

/// 供后台 isolate 生成详情派生图；非法图片返回 null，不影响原背景使用。
List<int>? createDetailBackgroundBytesForTest(List<int> sourceBytes) =>
    _createDetailBackgroundBytes(sourceBytes);

List<int>? _createDetailBackgroundBytes(List<int> sourceBytes) {
  try {
    final decoded = img.decodeImage(Uint8List.fromList(sourceBytes));
    if (decoded == null) return null;

    const targetWidth = 960;
    const targetHeight = 900;
    final targetRatio = targetWidth / targetHeight;
    final sourceRatio = decoded.width / decoded.height;
    final cropWidth = sourceRatio > targetRatio
        ? (decoded.height * targetRatio).round()
        : decoded.width;
    final cropHeight = sourceRatio > targetRatio
        ? decoded.height
        : (decoded.width / targetRatio).round();
    final cropped = img.copyCrop(
      decoded,
      x: (decoded.width - cropWidth) ~/ 2,
      y: (decoded.height - cropHeight) ~/ 2,
      width: cropWidth,
      height: cropHeight,
    );
    final resized = img.copyResize(
      cropped,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );
    final blurred = img.gaussianBlur(resized, radius: 18);
    return img.encodePng(blurred, level: 6);
  } catch (_) {
    return null;
  }
}

class BackgroundCacheService {
  static const maxBytes = 12 * 1024 * 1024;

  Future<Directory> _directory() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory(p.join(base.path, 'backgrounds'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<String?> copyLocal(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists() || await source.length() > maxBytes) return null;
    final bytes = await source.readAsBytes();
    if (!_isImage(bytes)) return null;
    final directory = await _directory();
    final extension = p.extension(sourcePath).toLowerCase();
    final target = File(
      p.join(
        directory.path,
        '${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<String?> download(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final response = await (await client.getUrl(
        Uri.parse(url),
      )).close().timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final bytes = await response.fold<List<int>>([], (all, chunk) {
        if (all.length + chunk.length <= maxBytes) all.addAll(chunk);
        return all;
      });
      if (bytes.isEmpty || !_isImage(bytes)) return null;
      final directory = await _directory();
      final target = File(
        p.join(
          directory.path,
          'bgm-${DateTime.now().microsecondsSinceEpoch}.img',
        ),
      );
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// 以小尺寸派生图实现详情页模糊背景，避免打开弹窗时运行实时滤镜。
  Future<String?> createDetailBackground(String? sourcePath) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final directory = await _directory();
    final target = File(
      p.join(
        directory.path,
        '${p.basenameWithoutExtension(sourcePath)}.detail-blur-v1.png',
      ),
    );
    if (await target.exists() && await target.length() > 0) return target.path;

    try {
      final sourceBytes = await source.readAsBytes();
      final output = await Isolate.run(
        () => _createDetailBackgroundBytes(sourceBytes),
      );
      if (output == null) return null;
      await target.writeAsBytes(output, flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  bool _isImage(List<int> bytes) {
    if (bytes.length < 12) return false;
    final png =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final jpg = bytes[0] == 0xFF && bytes[1] == 0xD8;
    final webp =
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    final bmp = bytes[0] == 0x42 && bytes[1] == 0x4D;
    return png || jpg || webp || bmp;
  }
}
