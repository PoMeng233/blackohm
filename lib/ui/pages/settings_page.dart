/// 设置页面：Locale Emulator 路径/参数配置、托盘行为与关于。
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_constants.dart';
import '../../features/background/background_service.dart';
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
        _sectionTitle('关于 BlackOhm · 视觉小说记录器'),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BlackOhm · Visual Novel Recorder',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
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
