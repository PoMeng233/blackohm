/// Riverpod 装配层：数据库 / 仓库 / 引擎 / 设置的依赖注入与生命周期。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_constants.dart';
import 'core/database/app_database.dart';
import 'data/game_repository.dart';
import 'data/session_repository.dart';
import 'data/settings_repository.dart';
import 'features/memory/memory_trim_service.dart';
import 'features/tracking/tracking_engine.dart';
import 'ui/theme.dart';

final themePaletteProvider = StateProvider<ThemePalette>(
  (ref) => ThemePalette.obsidian,
);

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

// ── 游戏库视图 ────────────────────────────────────────────────
final gameListProvider = StreamProvider<List<Game>>(
  (ref) => ref.watch(gameRepoProvider).watchAll(),
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

// ── 内存治理 ──────────────────────────────────────────────────
/// 托盘/空闲态工作集修剪。AppShell 在 show/hide 时同步 windowVisible。
final memoryTrimProvider = Provider<MemoryTrimService>((ref) {
  final service = MemoryTrimService();
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
  });

  final String leProcPath;
  final String leArgsTemplate;
  final String leProfile;
  final bool startHidden;
  final bool closeToTray;
  final bool trackingPaused;
  final String bangumiToken;

  AppSettingsState copyWith({
    String? leProcPath,
    String? leArgsTemplate,
    String? leProfile,
    bool? startHidden,
    bool? closeToTray,
    bool? trackingPaused,
    String? bangumiToken,
  }) => AppSettingsState(
    leProcPath: leProcPath ?? this.leProcPath,
    leArgsTemplate: leArgsTemplate ?? this.leArgsTemplate,
    leProfile: leProfile ?? this.leProfile,
    startHidden: startHidden ?? this.startHidden,
    closeToTray: closeToTray ?? this.closeToTray,
    trackingPaused: trackingPaused ?? this.trackingPaused,
    bangumiToken: bangumiToken ?? this.bangumiToken,
  );
}

class SettingsController extends StateNotifier<AppSettingsState> {
  SettingsController(this._repo, this._engine)
    : super(const AppSettingsState()) {
    _load();
  }

  final SettingsRepository _repo;
  final TrackingEngine _engine;

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
    state = AppSettingsState(
      leProcPath: lePath,
      leArgsTemplate: leArgs,
      leProfile: leProfile,
      startHidden: startHidden,
      closeToTray: closeToTray,
      trackingPaused: paused,
      bangumiToken: bangumiToken,
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
    state = state.copyWith(bangumiToken: v);
    await _repo.set(SettingsKeys.bangumiToken, v.trim());
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettingsState>(
      (ref) => SettingsController(
        ref.watch(settingsRepoProvider),
        ref.watch(trackingEngineProvider),
      ),
    );
