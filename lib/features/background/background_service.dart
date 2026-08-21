/// 本地背景缓存与 Bangumi/BGM 图片候选服务。
library;

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BangumiImageCandidate {
  const BangumiImageCandidate({
    required this.title,
    required this.subjectUrl,
    required this.imageUrl,
  });

  final String title;
  final String subjectUrl;
  final String imageUrl;
}

class BangumiImageSearchService {
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
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('Authorization', 'Bearer ${token.trim()}');
      request.write(
        jsonEncode({
          'keyword': query.trim(),
          'filter': {
            'type': [4],
            'nsfw': false,
          },
          'sort': 'match',
        }),
      );
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

BangumiImageCandidate? parseBangumiSubject(Map value) {
  final title = (value['name_cn'] ?? value['name'] ?? '').toString().trim();
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
  return BangumiImageCandidate(
    title: title,
    imageUrl: image,
    subjectUrl: id == null ? 'https://bgm.tv' : 'https://bgm.tv/subject/$id',
  );
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
