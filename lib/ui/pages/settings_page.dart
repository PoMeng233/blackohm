/// 设置页面：Locale Emulator 路径/参数配置、托盘行为与关于。
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_constants.dart';
import '../../data/settings_repository.dart';
import '../../features/background/background_service.dart';
import '../../features/data/backup_service.dart';
import '../../providers.dart';
import '../theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _lePathCtrl;
  late final TextEditingController _leArgsCtrl;
  late final TextEditingController _leProfileCtrl;
  late final TextEditingController _bangumiTokenCtrl;
  bool _testingToken = false;
  bool _busyData = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _lePathCtrl = TextEditingController(text: s.leProcPath);
    _leArgsCtrl = TextEditingController(text: s.leArgsTemplate);
    _leProfileCtrl = TextEditingController(text: s.leProfile);
    _bangumiTokenCtrl = TextEditingController(text: s.bangumiToken);
  }

  @override
  void dispose() {
    _lePathCtrl.dispose();
    _leArgsCtrl.dispose();
    _leProfileCtrl.dispose();
    _bangumiTokenCtrl.dispose();
    super.dispose();
  }

  void _syncControllers(AppSettingsState s) {
    if (_lePathCtrl.text != s.leProcPath) {
      _lePathCtrl.text = s.leProcPath;
    }
    if (_leArgsCtrl.text != s.leArgsTemplate) {
      _leArgsCtrl.text = s.leArgsTemplate;
    }
    if (_leProfileCtrl.text != s.leProfile) {
      _leProfileCtrl.text = s.leProfile;
    }
    if (_bangumiTokenCtrl.text != s.bangumiToken) {
      _bangumiTokenCtrl.text = s.bangumiToken;
    }
  }

  BackupService get _backupService => BackupService(ref.read(databaseProvider));

  void _notify(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  Future<void> _exportDatabase() async {
    if (_busyData) return;
    final stamp = DateTime.now();
    final name =
        'blackohm-backup-${stamp.year}'
        '${stamp.month.toString().padLeft(2, '0')}'
        '${stamp.day.toString().padLeft(2, '0')}'
        '-${stamp.hour.toString().padLeft(2, '0')}'
        '${stamp.minute.toString().padLeft(2, '0')}.db';
    final target = await FilePicker.saveFile(
      dialogTitle: '导出数据库备份',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const ['db'],
    );
    if (target == null || target.isEmpty || !mounted) return;
    setState(() => _busyData = true);
    try {
      await _backupService.exportTo(target);
      _notify('数据库已导出到 $target');
    } catch (e) {
      _notify('导出失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busyData = false);
    }
  }

  Future<void> _loadDatabase() async {
    if (_busyData) return;
    final picked = await FilePicker.pickFiles(
      dialogTitle: '选择数据库备份',
      type: FileType.custom,
      allowedExtensions: const ['db'],
    );
    final source = picked?.files.single.path;
    if (source == null || source.isEmpty || !mounted) return;

    setState(() => _busyData = true);
    try {
      final service = _backupService;
      if (!await service.validateBackup(source)) {
        _notify('该文件不是有效的 BlackOhm 数据库备份', error: true);
        return;
      }
      if (!mounted) return;
      final mode = await showDialog<BackupLoadMode>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('加载方式'),
          content: const Text(
            '合并到当前数据库：只新增当前库还没有的游戏，已有游戏整款跳过。\n\n'
            '覆盖当前数据库：先清空现有游戏与游玩记录，再完整导入备份内容。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, BackupLoadMode.merge),
              child: const Text('合并到当前数据库'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, BackupLoadMode.overwrite),
              child: const Text('覆盖当前数据库'),
            ),
          ],
        ),
      );
      if (mode == null || !mounted) return;

      if (mode == BackupLoadMode.overwrite) {
        final confirmed = await _confirm(
          title: '确认覆盖当前数据库？',
          message: '当前库中的全部游戏卡片与游玩记录将被删除，并替换为备份内容。此操作不可撤销。',
          confirmLabel: '覆盖导入',
        );
        if (!confirmed || !mounted) return;
      }

      final result = await service.loadFrom(source, mode: mode);
      _notify(
        '加载完成：新增 ${result.importedGames} 款、'
        '跳过已存在 ${result.skippedGames} 款、'
        '导入记录 ${result.importedSessions} 条',
      );
    } catch (e) {
      _notify('加载失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busyData = false);
    }
  }

  Future<void> _clearDatabase() async {
    if (_busyData) return;
    final first = await _confirm(
      title: '确认清空数据库？',
      message: '将删除全部游戏卡片与游玩记录。设置、Token、主题与文件夹分组会保留。',
      confirmLabel: '继续',
    );
    if (!first || !mounted) return;
    final second = await _confirm(
      title: '再次确认清空',
      message: '此操作不可撤销，且不会自动备份。建议先导出数据库备份。',
      confirmLabel: '确认清空',
    );
    if (!second || !mounted) return;

    setState(() => _busyData = true);
    try {
      final removed = await _backupService.clearGames();
      _notify('已清空 $removed 款游戏及其游玩记录');
    } catch (e) {
      _notify('清空失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busyData = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _testBangumiToken() async {
    // 优先使用“设置状态/持久化”里的 token（与真正请求走同一条路径），
    // 避免输入框与已保存值不一致导致的“看似填了其实没保存”问题。
    final saved = ref.read(settingsProvider).bangumiToken.trim();
    final controllerText = _bangumiTokenCtrl.text.trim();
    final token = controllerText.isNotEmpty ? controllerText : saved;
    if (token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先粘贴 Bangumi API Token')));
      return;
    }

    // 自检持久化是否与输入框一致（排查缓存/未保存问题）。
    final persisted = await ref
        .read(settingsRepoProvider)
        .get(SettingsKeys.bangumiToken);
    if (!mounted) return;
    final storageMismatch =
        persisted.trim().isNotEmpty && persisted.trim() != token;

    setState(() => _testingToken = true);
    final result = await BangumiImageSearchService().fetchSubjectDetailed(
      subjectId: 280839,
      token: token,
    );
    if (!mounted) return;
    setState(() => _testingToken = false);

    final status = result.statusCode;
    if (result.candidate != null) {
      final extra = storageMismatch ? '（注意：输入框与已保存值不一致，可能尚未保存成功）' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Token 有效：${result.candidate!.title} · 通道：${result.channel}$extra',
          ),
        ),
      );
    } else if (status == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '网络异常/超时：${result.channel}。'
            '若使用本机代理，请确认其提供 HTTP(mixed) 端口（Dart 不支持 SOCKS5）。',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            storageMismatch
                ? 'Token 无效或无 R18 权限（HTTP $status），且输入框与已保存值不一致'
                : 'Token 无效或无 R18 权限（HTTP $status）· 通道：${result.channel}',
          ),
        ),
      );
    }
  }

  Future<void> _pickShellBackground() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: '选择主界面背景图片',
      type: FileType.image,
    );
    final sourcePath = result?.files.single.path;
    if (sourcePath == null) return;
    final cached = await BackgroundCacheService().copyLocal(sourcePath);
    if (!mounted) return;
    if (cached == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片格式不支持或文件超过 12 MB')));
      return;
    }
    final previous = ref.read(settingsProvider).shellBackgroundPath;
    if (previous.isNotEmpty) await BackgroundCacheService().delete(previous);
    await ref.read(settingsProvider.notifier).setShellBackgroundPath(cached);
  }

  Future<void> _clearShellBackground() async {
    final path = ref.read(settingsProvider).shellBackgroundPath;
    await BackgroundCacheService().delete(path);
    await ref.read(settingsProvider.notifier).setShellBackgroundPath('');
  }

  Future<void> _pickLeProc() async {
    final res = await FilePicker.pickFiles(
      dialogTitle: '选择 LEProc.exe 所在路径',
      type: FileType.custom,
      allowedExtensions: ['exe'],
    );
    if (res != null && res.files.single.path != null) {
      final p = res.files.single.path!;
      _lePathCtrl.text = p;
      ref.read(settingsProvider.notifier).setLeProcPath(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppSettingsState>(
      settingsProvider,
      (prev, next) => _syncControllers(next),
    );
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle('Locale Emulator (LE) 转区配置'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lePathCtrl,
                        decoration: const InputDecoration(
                          labelText: 'LEProc.exe 绝对路径',
                          hintText: 'C:\\Tools\\Locale.Emulator\\LEProc.exe',
                        ),
                        onChanged: notifier.setLeProcPath,
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonal(
                      onPressed: _pickLeProc,
                      child: const Text('浏览...'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _leArgsCtrl,
                  decoration: const InputDecoration(
                    labelText: '启动参数模板',
                    helperText:
                        '占位符：{exe} 目标绝对路径，{profile} Profile 名，{args} 附加参数',
                  ),
                  onChanged: notifier.setLeArgsTemplate,
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _leArgsCtrl.text = kDefaultLeArgsTemplate;
                      notifier.setLeArgsTemplate(kDefaultLeArgsTemplate);
                    },
                    child: const Text(
                      '恢复默认 (-run "{exe}")',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                TextField(
                  controller: _leProfileCtrl,
                  decoration: const InputDecoration(
                    labelText: '全局默认 Profile（如 Japan / zh-CN / GUID）',
                    hintText: 'Japan',
                  ),
                  onChanged: notifier.setLeProfile,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('BGM 在线背景搜索'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _bangumiTokenCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Bangumi API Token',
                    helperText: '仅在用户主动搜索背景时使用，保存在本地设置中',
                  ),
                  onChanged: ref
                      .read(settingsProvider.notifier)
                      .setBangumiToken,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.key_rounded, size: 17),
                      label: const Text('获取 Token'),
                      onPressed: () => launchUrl(
                        Uri.parse('https://next.bgm.tv/demo/access-token'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    TextButton.icon(
                      icon: _testingToken
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_rounded, size: 17),
                      label: const Text('测试 Token'),
                      onPressed: _testingToken ? null : _testBangumiToken,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('主界面背景'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 116,
                  height: 58,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child:
                      settings.shellBackgroundPath.isNotEmpty &&
                          File(settings.shellBackgroundPath).existsSync()
                      ? Image.file(
                          File(settings.shellBackgroundPath),
                          fit: BoxFit.cover,
                          cacheWidth: 232,
                          cacheHeight: 116,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        )
                      : const Icon(
                          Icons.wallpaper_outlined,
                          color: AppColors.textMuted,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    settings.shellBackgroundPath.isEmpty
                        ? '未设置背景图片'
                        : '背景仅显示在主内容区',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _pickShellBackground,
                  icon: const Icon(Icons.image_outlined, size: 17),
                  label: const Text('选择'),
                ),
                if (settings.shellBackgroundPath.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearShellBackground,
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const Text('清除'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('Material 3 配色方案'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<ThemePalette>(
              initialValue: settings.themePalette,
              decoration: const InputDecoration(labelText: '界面配色'),
              items: ThemePalette.values
                  .map(
                    (palette) => DropdownMenuItem(
                      value: palette,
                      child: Text(paletteLabel(palette)),
                    ),
                  )
                  .toList(),
              onChanged: (palette) {
                if (palette != null) {
                  notifier.setThemePalette(palette);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('系统与生命周期'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('点击关闭按钮时隐藏到托盘'),
                subtitle: const Text('保持后台精准前台计时守护，避免误关闭'),
                value: settings.closeToTray,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: notifier.setCloseToTray,
              ),
              const Divider(height: 1, color: AppColors.border),
              SwitchListTile(
                title: const Text('开机/启动时静默最小化到托盘'),
                subtitle: const Text('启动时不展示主窗口，直接常驻后台捕获'),
                value: settings.startHidden,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: notifier.setStartHidden,
              ),
              const Divider(height: 1, color: AppColors.border),
              SwitchListTile(
                title: const Text('睡眠监测'),
                subtitle: const Text('游戏保持前台但 30 分钟没有键盘/鼠标输入时，自动暂停计时；关闭后不检测'),
                value: settings.sleepMonitoring,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: notifier.setSleepMonitoring,
              ),
              const Divider(height: 1, color: AppColors.border),
              SwitchListTile(
                title: const Text('全局暂停前台计时统计'),
                subtitle: const Text('开启后前台焦点引擎将冻结时长累加（同托盘右键选项）'),
                value: settings.trackingPaused,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: notifier.setTrackingPaused,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('数据管理'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '导出当前数据库备份；加载时可选择合并到当前库或覆盖；清空只删除游戏与游玩记录，保留设置与文件夹分组。',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busyData ? null : _exportDatabase,
                      icon: const Icon(Icons.save_alt_rounded, size: 18),
                      label: const Text('导出数据库'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busyData ? null : _loadDatabase,
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('加载数据库'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busyData ? null : _clearDatabase,
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      label: const Text(
                        '清空数据库',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('关于 BlackOhm · 视觉小说记录器'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'BlackOhm · Visual Novel Recorder',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 版本号随构建自动更新（读取 pubspec version）。
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        final v = snapshot.data;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(26),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            v == null ? '…' : 'v${v.version}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '专为视觉小说设计的本地游玩记录器。\n'
                  '• 只记录真正处于前台焦点的游玩时间\n'
                  '• 不上传游戏路径、存档或游玩记录\n'
                  '• 支持本地背景、BGM 候选和精准 Session 历史',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.rocket_launch_outlined, size: 17),
                      label: const Text('前往 Releases 检查更新'),
                      onPressed: () => launchUrl(
                        Uri.parse(kGitHubReleasesUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    ),
  );
}
