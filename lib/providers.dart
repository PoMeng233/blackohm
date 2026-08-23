/// Riverpod 装配层：数据库 / 仓库 / 引擎 / 设置的依赖注入与生命周期。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_constants.dart';
import 'core/database/app_database.dart';
import 'data/folder_repository.dart';
import 'data/game_repository.dart';
import 'data/session_repository.dart';
import 'data/settings_repository.dart';
import 'features/background/background_service.dart';
import 'features/bangumi/bangumi_enrichment_service.dart';
import 'features/memory/memory_trim_service.dart';
import 'features/tracking/tracking_engine.dart';
import 'ui/theme.dart';

// ── 数据层 ────────────────────────────────────────────────────
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final gameRepoProvider = Provider<GameRepository>(
  (ref) => GameRepository(ref.watch(databaseProvider)),
);

final sessionRepoProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);

final settingsRepoProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final folderRepoProvider = Provider<FolderRepository>(
  (ref) => FolderRepository(ref.watch(databaseProvider)),
);

// ── 游戏库视图 ────────────────────────────────────────────────
final gameListProvider = StreamProvider<List<Game>>(
  (ref) => ref.watch(gameRepoProvider).watchAll(),
);

final folderListProvider = StreamProvider<List<GameFolder>>(
  (ref) => ref.watch(folderRepoProvider).watchAll(),
);

final recentGamesProvider = StreamProvider<List<Game>>(
  (ref) => ref.watch(gameRepoProvider).watchRecent(),
);

// ── 焦点计时引擎 ──────────────────────────────────────────────
final trackingEngineProvider = Provider<TrackingEngine>((ref) {
  final engine = TrackingEngine(sessions: ref.watch(sessionRepoProvider));

  // 库变化 → 重建 exePath 命中索引（入库即生效，无需重启引擎）。
  ref.listen(gameListProvider, (_, next) {
    engine.rebuildIndex(next.value ?? const <Game>[]);
  }, fireImmediately: true);

  ref.onDispose(() => unawaited(engine.stop()));
  unawaited(engine.start());
  return engine;
});

/// 当前活跃会话状态（驱动呼吸光效卡片与实时秒表）。
final trackingStateProvider = StreamProvider<TrackingPublicState>(
  (ref) => ref.watch(trackingEngineProvider).states,
);

// ── 窗口可见性 ────────────────────────────────────────────────
/// 主窗口是否可见（AppShell 在 show/hide/minimize/restore 时同步）。
/// 隐藏时暂停 UI 动画与秒表推送，空闲态 CPU 趋近于零。
final windowVisibleProvider = StateProvider<bool>((ref) => true);

/// 当前正在浏览的具体文件夹 ID（null 表示全部游戏/未分类/非库页）。
/// 用于外部拖拽或“添加游戏”时，把新入库的游戏直接加入当前文件夹。
final currentBrowsingFolderIdProvider = StateProvider<int?>((ref) => null);

// ── 游戏图标按需加载 ──────────────────────────────────────────
/// 列表查询不再携带 iconPng blob；卡片可见时按 gameId 惰性取一次，
/// 结果由 FutureProvider 缓存，避免 100+ 游戏的图标字节常驻内存。
final gameIconProvider = FutureProvider.family<Uint8List?, int>((ref, id) {
  return ref.watch(gameRepoProvider).loadIcon(id);
});

// ── 内存治理 ──────────────────────────────────────────────────
/// 托盘/空闲态工作集修剪。AppShell 在 show/hide 时同步 windowVisible。
final memoryTrimProvider = Provider<MemoryTrimService>((ref) {
  final service = MemoryTrimService(
    isTrackingActive: () => ref.read(trackingEngineProvider).current.isActive,
  );
  ref.onDispose(service.dispose);
  service.start();
  return service;
});

// ── 设置 ──────────────────────────────────────────────────────
class AppSettingsState {
  const AppSettingsState({
    this.leProcPath = '',
    this.leArgsTemplate = kDefaultLeArgsTemplate,
    this.leProfile = '',
    this.startHidden = false,
    this.closeToTray = true,
    this.trackingPaused = false,
    this.bangumiToken = '',
    this.shellBackgroundPath = '',
    this.themePalette = ThemePalette.obsidian,
  });

  final String leProcPath;
  final String leArgsTemplate;
  final String leProfile;
  final bool startHidden;
  final bool closeToTray;
  final bool trackingPaused;
  final String bangumiToken;
  final String shellBackgroundPath;
  final ThemePalette themePalette;

  AppSettingsState copyWith({
    String? leProcPath,
    String? leArgsTemplate,
    String? leProfile,
    bool? startHidden,
    bool? closeToTray,
    bool? trackingPaused,
    String? bangumiToken,
    String? shellBackgroundPath,
    ThemePalette? themePalette,
  }) => AppSettingsState(
    leProcPath: leProcPath ?? this.leProcPath,
    leArgsTemplate: leArgsTemplate ?? this.leArgsTemplate,
    leProfile: leProfile ?? this.leProfile,
    startHidden: startHidden ?? this.startHidden,
    closeToTray: closeToTray ?? this.closeToTray,
    trackingPaused: trackingPaused ?? this.trackingPaused,
    bangumiToken: bangumiToken ?? this.bangumiToken,
    shellBackgroundPath: shellBackgroundPath ?? this.shellBackgroundPath,
    themePalette: themePalette ?? this.themePalette,
  );
}

class SettingsController extends StateNotifier<AppSettingsState> {
  SettingsController(this._repo, this._engine)
    : super(const AppSettingsState()) {
    loadFuture = _load();
  }

  final SettingsRepository _repo;
  final TrackingEngine _engine;
  late final Future<void> loadFuture;

  Future<void> _load() async {
    final lePath = await _repo.get(SettingsKeys.leProcPath);
    final leArgs = await _repo.get(
      SettingsKeys.leArgsTemplate,
      defaultValue: kDefaultLeArgsTemplate,
    );
    final leProfile = await _repo.get(SettingsKeys.leProfile);
    final startHidden = await _repo.getBool(SettingsKeys.startHidden);
    final closeToTray = await _repo.getBool(
      SettingsKeys.closeToTray,
      defaultValue: true,
    );
    final paused = await _repo.getBool(SettingsKeys.trackingPaused);
    final bangumiToken = await _repo.get(SettingsKeys.bangumiToken);
    final shellBackgroundPath = await _repo.get(
      SettingsKeys.shellBackgroundPath,
    );
    final paletteName = await _repo.get(SettingsKeys.themePalette);
    final themePalette = ThemePalette.values
        .where((p) => p.name == paletteName)
        .firstOrNull;
    state = AppSettingsState(
      leProcPath: lePath,
      leArgsTemplate: leArgs,
      leProfile: leProfile,
      startHidden: startHidden,
      closeToTray: closeToTray,
      trackingPaused: paused,
      bangumiToken: bangumiToken,
      shellBackgroundPath: shellBackgroundPath,
      themePalette: themePalette ?? ThemePalette.obsidian,
    );
    _engine.setPaused(paused);
  }

  Future<void> setLeProcPath(String v) async {
    state = state.copyWith(leProcPath: v);
    await _repo.set(SettingsKeys.leProcPath, v);
  }

  Future<void> setLeArgsTemplate(String v) async {
    state = state.copyWith(leArgsTemplate: v);
    await _repo.set(SettingsKeys.leArgsTemplate, v);
  }

  Future<void> setLeProfile(String v) async {
    state = state.copyWith(leProfile: v);
    await _repo.set(SettingsKeys.leProfile, v);
  }

  Future<void> setStartHidden(bool v) async {
    state = state.copyWith(startHidden: v);
    await _repo.setBool(SettingsKeys.startHidden, v);
  }

  Future<void> setCloseToTray(bool v) async {
    state = state.copyWith(closeToTray: v);
    await _repo.setBool(SettingsKeys.closeToTray, v);
  }

  Future<void> setTrackingPaused(bool v) async {
    state = state.copyWith(trackingPaused: v);
    await _repo.setBool(SettingsKeys.trackingPaused, v);
    _engine.setPaused(v);
  }

  Future<void> setBangumiToken(String v) async {
    final trimmed = v.trim();
    state = state.copyWith(bangumiToken: trimmed);
    await _repo.set(SettingsKeys.bangumiToken, trimmed);
  }

  Future<void> setShellBackgroundPath(String v) async {
    state = state.copyWith(shellBackgroundPath: v);
    await _repo.set(SettingsKeys.shellBackgroundPath, v);
  }

  Future<void> setThemePalette(ThemePalette v) async {
    state = state.copyWith(themePalette: v);
    await _repo.set(SettingsKeys.themePalette, v.name);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettingsState>(
      (ref) => SettingsController(
        ref.watch(settingsRepoProvider),
        ref.watch(trackingEngineProvider),
      ),
    );

// ── Bangumi 自动富化 ──────────────────────────────────────────
/// 新增游戏后异步拉取评分与封面：只在候选唯一/标题精确时写回，
/// 网络失败静默跳过；用 Set 幂等，避免每次库变更重复联网。
final bangumiEnrichmentProvider = Provider<BangumiEnrichmentCoordinator>((ref) {
  final coordinator = BangumiEnrichmentCoordinator(
    games: ref.watch(gameRepoProvider),
    cache: BackgroundCacheService(),
    search: BangumiImageSearchService(),
  );
  String token = ref.read(settingsProvider).bangumiToken;
  ref.listen(settingsProvider, (_, next) => token = next.bangumiToken);
  ref.listen(gameListProvider, (_, next) {
    coordinator.onGames(next.value ?? const <Game>[], token);
  }, fireImmediately: true);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
