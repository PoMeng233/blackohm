/// 数据库备份：导出 / 加载（合并或覆盖）/ 清空。
///
/// 实现要点：
///  * 导出前 `wal_checkpoint(TRUNCATE)`，保证复制出的文件包含全部已提交数据；
///  * 加载用 `ATTACH DATABASE` 读取备份，**不打开、不迁移备份文件本身**
///    （直接打开会因 schema 迁移而改写用户备份）；
///  * 合并 = 只导入当前库没有的 exe，已存在的游戏整款跳过；
///    覆盖 = 先清空游戏/会话/文件夹，再全量导入；
///  * 列名按交集取用，兼容旧版本备份缺列的情况；
///    所有取值都经 drift 自己的 typeMapping，避免时间/布尔编码不一致。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/database/app_database.dart';

/// 加载方式。
enum BackupLoadMode {
  /// 合并到当前数据库：只新增当前库没有的游戏。
  merge,

  /// 覆盖当前数据库：清空后全量导入备份内容。
  overwrite,
}

/// 加载结果统计。
class BackupLoadResult {
  BackupLoadResult();

  int importedGames = 0;
  int skippedGames = 0;
  int importedSessions = 0;
  int skippedSessions = 0;
  int importedFolders = 0;

  bool get isEmpty => importedGames == 0 && skippedGames == 0;
}

const String _attachName = 'blackohm_backup';

class BackupService {
  BackupService(this._db, {Future<String> Function()? databaseFile})
    : _databaseFile = databaseFile ?? _defaultDatabaseFile;

  final AppDatabase _db;
  final Future<String> Function() _databaseFile;

  static Future<String> _defaultDatabaseFile() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'blackohm.db');
  }

  /// 导出到 [targetPath]；当前库不受影响。
  Future<void> exportTo(String targetPath) async {
    final sourcePath = await _databaseFile();
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('数据库文件不存在：$sourcePath');
    }
    // WAL 中已提交但未回写的数据必须先落盘，否则备份会缺数据。
    await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final target = File(targetPath);
    await target.parent.create(recursive: true);
    await source.copy(target.path);
  }

  /// 校验目标文件是否为可用备份（含 games 表）。
  Future<bool> validateBackup(String sourcePath) async {
    if (!await File(sourcePath).exists()) return false;
    try {
      await _db.customStatement('ATTACH DATABASE ? AS $_attachName', [
        sourcePath,
      ]);
    } catch (_) {
      return false;
    }
    try {
      final rows = await _db
          .customSelect(
            "SELECT name FROM $_attachName.sqlite_master "
            "WHERE type = 'table' AND name = 'games'",
          )
          .get();
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    } finally {
      await _detach();
    }
  }

  /// 从备份加载。
  ///
  /// ATTACH 不能在事务内执行，因此顺序为：ATTACH → TRANSACTION → DETACH。
  Future<BackupLoadResult> loadFrom(
    String sourcePath, {
    required BackupLoadMode mode,
  }) async {
    final result = BackupLoadResult();
    await _db.customStatement('ATTACH DATABASE ? AS $_attachName', [
      sourcePath,
    ]);
    try {
      await _db.transaction(() async {
        if (mode == BackupLoadMode.overwrite) {
          // 级联删除：会话随游戏一并清除。
          await _db.delete(_db.playSessions).go();
          await _db.delete(_db.games).go();
          await _db.delete(_db.gameFolders).go();
        }

        final folderNames = await _importFolders(result);
        final gameIds = await _importGames(
          result,
          skipExisting: mode == BackupLoadMode.merge,
          backupFolderNames: folderNames,
        );
        await _importSessions(result, gameIds);
      });
    } finally {
      await _detach();
    }
    return result;
  }

  /// 清空游戏与游玩记录；保留设置与文件夹分组。
  Future<int> clearGames() async {
    var removed = 0;
    await _db.transaction(() async {
      removed = await _db.delete(_db.games).go();
    });
    return removed;
  }

  Future<void> _detach() async {
    try {
      await _db.customStatement('DETACH DATABASE $_attachName');
    } catch (_) {
      // 已分离或连接异常：忽略。
    }
  }

  /// 导入文件夹，返回「备份文件夹 id → 名称」映射。
  Future<Map<int, String>> _importFolders(BackupLoadResult result) async {
    if (!await _hasTable('game_folders')) return const <int, String>{};
    final rows = await _db
        .customSelect('SELECT * FROM $_attachName.game_folders')
        .get();
    final existing = <String, int>{
      for (final f in await _db.select(_db.gameFolders).get()) f.name: f.id,
    };
    final backupNames = <int, String>{};
    for (final row in rows) {
      final data = row.data;
      final id = data['id'];
      final name = _read(DriftSqlType.string, data['name']);
      if (id is! int || name == null || name.isEmpty) continue;
      backupNames[id] = name;
      if (existing.containsKey(name)) continue;
      final newId = await _db
          .into(_db.gameFolders)
          .insert(
            GameFoldersCompanion.insert(
              name: name,
              sortOrder: Value(
                _read(DriftSqlType.int, data['sort_order']) ?? 0,
              ),
              showOnHome: Value(
                _read(DriftSqlType.bool, data['show_on_home']) ?? true,
              ),
            ),
          );
      existing[name] = newId;
    }
    // 名称 → id 映射，供游戏归属使用。
    return <int, String>{
      for (final entry in backupNames.entries) entry.key: entry.value,
    };
  }

  /// 导入游戏，返回「备份游戏 id → 新游戏 id」映射。
  Future<Map<int, int>> _importGames(
    BackupLoadResult result, {
    required bool skipExisting,
    required Map<int, String> backupFolderNames,
  }) async {
    final existingExe = <String>{};
    if (skipExisting) {
      for (final g in await _db.select(_db.games).get()) {
        existingExe.add(g.exePath);
      }
    }
    final folderIdByName = <String, int>{
      for (final f in await _db.select(_db.gameFolders).get()) f.name: f.id,
    };

    final rows = await _db
        .customSelect('SELECT * FROM $_attachName.games')
        .get();
    final idMap = <int, int>{};
    for (final row in rows) {
      final data = row.data;
      final exePath = _read(DriftSqlType.string, data['exe_path']);
      if (exePath == null || exePath.isEmpty) continue;
      if (skipExisting && existingExe.contains(exePath)) {
        result.skippedGames++;
        continue;
      }
      final backupFolderId = data['folder_id'];
      final folderName = backupFolderId is int
          ? backupFolderNames[backupFolderId]
          : null;
      final newId = await _db
          .into(_db.games)
          .insert(
            GamesCompanion.insert(
              title: _read(DriftSqlType.string, data['title']) ?? '未命名',
              exePath: exePath,
              dirPath: _read(DriftSqlType.string, data['dir_path']) ?? '',
              iconPng: _blob(data['icon_png']),
              backgroundPath: _textNullable(data['background_path']),
              detailBackgroundPath: _textNullable(
                data['detail_background_path'],
              ),
              backgroundBlurAmount:
                  _real(data['background_blur_amount']) ??
                  const Value<double>.absent(),
              launchArgs:
                  _text(data['launch_args']) ?? const Value<String>.absent(),
              useLocaleEmulator:
                  _bool(data['use_locale_emulator']) ??
                  const Value<bool>.absent(),
              leProfile:
                  _text(data['le_profile']) ?? const Value<String>.absent(),
              createdAt:
                  _date(data['created_at']) ?? const Value<DateTime>.absent(),
              lastPlayedAt: _dateNullable(data['last_played_at']),
              totalPlaySeconds:
                  _int(data['total_play_seconds']) ?? const Value<int>.absent(),
              favorite: _bool(data['favorite']) ?? const Value<bool>.absent(),
              folderId: Value(
                folderName == null ? null : folderIdByName[folderName],
              ),
              launchCount:
                  _int(data['launch_count']) ?? const Value<int>.absent(),
              bangumiSubjectId: _intNullable(data['bangumi_subject_id']),
              bangumiScore: _realNullable(data['bangumi_score']),
            ),
          );
      final backupId = data['id'];
      if (backupId is int) idMap[backupId] = newId;
      result.importedGames++;
    }
    return idMap;
  }

  Future<void> _importSessions(
    BackupLoadResult result,
    Map<int, int> gameIdMap,
  ) async {
    if (!await _hasTable('play_sessions')) return;
    final rows = await _db
        .customSelect('SELECT * FROM $_attachName.play_sessions')
        .get();
    for (final row in rows) {
      final data = row.data;
      final backupGameId = data['game_id'];
      final newGameId = backupGameId is int ? gameIdMap[backupGameId] : null;
      if (newGameId == null) {
        result.skippedSessions++;
        continue;
      }
      final startedAt = _read(DriftSqlType.dateTime, data['started_at']);
      if (startedAt == null) {
        result.skippedSessions++;
        continue;
      }
      await _db
          .into(_db.playSessions)
          .insert(
            PlaySessionsCompanion.insert(
              gameId: Value(newGameId),
              startedAt: startedAt,
              endedAt: Value(_read(DriftSqlType.dateTime, data['ended_at'])),
              durationSeconds: Value(
                _read(DriftSqlType.int, data['duration_seconds']) ?? 0,
              ),
            ),
          );
      result.importedSessions++;
    }
  }

  Future<bool> _hasTable(String name) async {
    final rows = await _db
        .customSelect(
          "SELECT name FROM $_attachName.sqlite_master "
          "WHERE type = 'table' AND name = ?",
          variables: [Variable<String>(name)],
        )
        .get();
    return rows.isNotEmpty;
  }

  // ── 取值助手：统一走 drift 的 typeMapping，保证编码一致 ──────────

  T? _read<T extends Object>(DriftSqlType<T> type, Object? raw) =>
      raw == null ? null : _db.typeMapping.read(type, raw);

  Value<String>? _text(Object? raw) {
    final value = _read(DriftSqlType.string, raw);
    return value == null ? null : Value(value);
  }

  Value<int>? _int(Object? raw) {
    final value = _read(DriftSqlType.int, raw);
    return value == null ? null : Value(value);
  }

  Value<double>? _real(Object? raw) {
    final value = _read(DriftSqlType.double, raw);
    return value == null ? null : Value(value);
  }

  Value<bool>? _bool(Object? raw) {
    final value = _read(DriftSqlType.bool, raw);
    return value == null ? null : Value(value);
  }

  Value<DateTime>? _date(Object? raw) {
    final value = _read(DriftSqlType.dateTime, raw);
    return value == null ? null : Value(value);
  }

  Value<DateTime?> _dateNullable(Object? raw) =>
      Value(_read(DriftSqlType.dateTime, raw));

  Value<String?> _textNullable(Object? raw) =>
      Value(_read(DriftSqlType.string, raw));

  Value<int?> _intNullable(Object? raw) => Value(_read(DriftSqlType.int, raw));

  Value<double?> _realNullable(Object? raw) =>
      Value(_read(DriftSqlType.double, raw));

  Value<Uint8List?> _blob(Object? raw) => Value(_read(DriftSqlType.blob, raw));
}
