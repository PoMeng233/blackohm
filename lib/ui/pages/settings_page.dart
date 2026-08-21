/// 设置页面：Locale Emulator 路径/参数配置、托盘行为与关于。
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
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

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _lePathCtrl = TextEditingController(text: s.leProcPath);
    _leArgsCtrl = TextEditingController(text: s.leArgsTemplate);
    _leProfileCtrl = TextEditingController(text: s.leProfile);
  }

  @override
  void dispose() {
    _lePathCtrl.dispose();
    _leArgsCtrl.dispose();
    _leProfileCtrl.dispose();
    super.dispose();
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
        _sectionTitle('系统与生命周期'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('点击关闭按钮时隐藏到托盘'),
                subtitle: const Text('保持后台精准前台计时守护，避免误关闭'),
                value: settings.closeToTray,
                activeThumbColor: AppColors.accent,
                onChanged: notifier.setCloseToTray,
              ),
              const Divider(height: 1, color: AppColors.border),
              SwitchListTile(
                title: const Text('开机/启动时静默最小化到托盘'),
                subtitle: const Text('启动时不展示主窗口，直接常驻后台捕获'),
                value: settings.startHidden,
                activeThumbColor: AppColors.accent,
                onChanged: notifier.setStartHidden,
              ),
              const Divider(height: 1, color: AppColors.border),
              SwitchListTile(
                title: const Text('全局暂停前台计时统计'),
                subtitle: const Text('开启后前台焦点引擎将冻结时长累加（同托盘右键选项）'),
                value: settings.trackingPaused,
                activeThumbColor: AppColors.accent,
                onChanged: notifier.setTrackingPaused,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('关于 BlackOhm'),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BlackOhm v0.1.0 (Windows Native AOT)',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '超轻量视觉小说资产管理与前台焦点游玩记录器。\n'
                  '• 事件驱动 SetWinEventHook 前台捕获，后台 CPU 占用 < 0.1%\n'
                  '• 3 秒防抖合并、锁屏/睡眠即停、60 秒批量落盘\n'
                  '• 纯本地 SQLite 3 WAL 存储，零网络强依赖',
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
