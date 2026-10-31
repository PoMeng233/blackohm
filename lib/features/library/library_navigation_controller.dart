/// 游戏库浏览选择：启动恢复、失效回退与顺序持久化。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../data/folder_repository.dart';
import '../../data/settings_repository.dart';

class LibraryNavigationController extends StateNotifier<int?> {
  LibraryNavigationController(this._settings, this._folders) : super(null) {
    loadFuture = _load();
  }

  final SettingsRepository _settings;
  final FolderRepository _folders;
  late final Future<void> loadFuture;
  StreamSubscription<List<GameFolder>>? _subscription;
  Future<void> _pendingSave = Future.value();
  List<GameFolder>? _knownFolders;
  bool _selectedDuringLoad = false;
  bool _loaded = false;

  static String encode(int? selection) => switch (selection) {
    null => 'all',
    -1 => 'uncategorized',
    _ => 'folder:$selection',
  };

  static int? decode(String value) {
    if (value == 'uncategorized') return -1;
    if (!value.startsWith('folder:')) return null;
    final id = int.tryParse(value.substring(7));
    return id != null && id > 0 ? id : null;
  }

  int? _validated(int? selection) {
    if (selection == null || selection == -1) return selection;
    if (selection <= 0) return null;
    final folders = _knownFolders;
    return folders == null || folders.any((folder) => folder.id == selection)
        ? selection
        : null;
  }

  Future<void> _load() async {
    try {
      final saved = await _settings.get(SettingsKeys.librarySelectedFolder);
      final folders = await _folders.getAll();
      if (!mounted) return;
      _knownFolders = folders;
      state = _validated(_selectedDuringLoad ? state : decode(saved));
      if (saved != encode(state)) _save(state);
    } catch (error) {
      debugPrint('无法恢复游戏库文件夹，使用安全默认选择：$error');
      if (!mounted) return;
      // 读取失败不覆盖加载期间的用户选择，也不阻断后续保存和退出。
      state = _validated(_selectedDuringLoad ? state : null);
    }
    _loaded = true;
    _subscription = _folders.watchAll().listen(
      (folders) {
        if (!mounted) return;
        _knownFolders = folders;
        final selection = _validated(state);
        if (selection != state) select(selection);
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('无法校验游戏库文件夹：$error');
      },
    );
  }

  void select(int? selection) {
    if (!_loaded) _selectedDuringLoad = true;
    state = _validated(selection);
    _save(state);
  }

  void _save(int? selection) {
    final value = encode(selection);
    // 快速切换产生的写入必须依次完成，不能让旧选择最后覆盖新选择。
    _pendingSave = _pendingSave.then((_) async {
      try {
        await _settings.set(SettingsKeys.librarySelectedFolder, value);
      } catch (error) {
        debugPrint('无法保存游戏库文件夹：$error');
      }
    });
  }

  Future<void> flush() async {
    await loadFuture;
    _save(state);
    while (true) {
      final pending = _pendingSave;
      await pending;
      if (identical(pending, _pendingSave)) return;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
