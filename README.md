# BlackOhm

> Windows 专用、纯本地的视觉小说资产管理与**前台焦点游玩记录器**。

BlackOhm 面向视觉小说和独立游戏库管理场景：将游戏目录或 `.exe` 拖入窗口即可扫描入库（目前尚未实现多游戏入库）；当一个已入库游戏的主窗口真正位于前台、可见且未最小化时，才累计游玩时长。它不依赖由本程序启动的子进程句柄，因此经 Locale Emulator、外部启动器或直接双击运行的游戏都可被被动捕获。

## 界面展示

<p align="center">
  <img src="https://pomeng.top/file/1787588872561_line.jpg" alt="界面截图1" width="750">
</p>

<p align="center">
  <img src="https://pomeng.top/file/1787588874198_time__analyze.jpg" alt="界面截图2" width="750">
</p>

<p align="center">
  <img src="https://pomeng.top/file/1787588869137_home.jpg" alt="界面截图3" width="750">
</p>

> **备注**：上述游戏图片及背景素材仅供界面展示之用，版权归原作者所有。

## 核心能力

- **事件驱动的精准计时**：通过 `SetWinEventHook(EVENT_SYSTEM_FOREGROUND)` 捕获焦点切换；`GetForegroundWindow → PID → QueryFullProcessImageNameW` 获得真实镜像路径并与游戏库 O(1) 匹配。
- **不会把挂机计入时长**：窗口失焦、切换到浏览器、最小化、锁屏或睡眠时停止累加；可选睡眠监测会在游戏保持前台但 30 分钟无键盘/鼠标输入时自动暂停。
- **低资源后台守护**：焦点 watcher 运行在独立 Isolate，空闲时阻塞于 `MsgWaitForMultipleObjectsEx` 内核等待；另有每秒一次的轻量心跳兜底——同窗口快速门控加镜像路径缓存，稳态 CPU 占用趋近 0%。
- **自动背景图搜索/bangumi词条匹配**：在设置里面配置好access token后即可自动匹配游戏封面以及游戏评分。
- **拖拽扫描与多 Exe 决策**：目录扫描采用深度限制 BFS 与候选数量上限，不按 exe 文件名、PE 产品名或游戏引擎过滤；单候选自动入库，多候选完整展示并标记已入库项。
- **Locale Emulator 集成**：每款游戏可选择 LE 启动；LEProc 路径、Profile 与参数模板均可配置。计时按最终游戏窗口镜像路径匹配，不受代理进程影响。
- **本地优先**：Drift + SQLite 3（WAL）存储，无账户、无网络请求、无云同步依赖。
- **Windows 托盘体验**：关闭隐藏到托盘、显示窗口、暂停统计、最近游玩快速启动和退出。
- **MiSans 字体**：内置小米 [MiSans](https://hyperos.mi.com/font/) Regular 字重作为全局 UI 字体，中文显示统一清晰，无需系统安装。

## 已验证

本仓库在 Windows 环境完成以下验证：

```text
flutter analyze                         # No issues found
flutter test                            # all tests passed
flutter build windows --release         # 成功生成 blackohm.exe
```

Release 产物：`build/windows/x64/runner/Release/blackohm.exe`。

## 快速开始

### 前置条件

- Windows 10/11 x64
- Flutter Stable（本项目以 Dart `^3.12.2` 配置）
- Visual Studio 2022 Build Tools，安装 **Desktop development with C++** 工作负载
- （可选）[Locale Emulator](https://github.com/xupefei/Locale-Emulator)；若不需要转区启动可不安装

### 开发运行

```bash
flutter pub get
dart run build_runner build
flutter run -d windows
```

> `lib/core/database/app_database.g.dart` 已纳入版本控制；只有修改 Drift 表定义后才需要重新执行 `build_runner`。

### 生成 Release 包

```bash
flutter build windows --release
```

可分发目录是：

```text
build/windows/x64/runner/Release/
├── blackohm.exe
├── data/
└── 依赖 DLL 文件
```

请分发整个 `Release` 目录，而不是只复制 `blackohm.exe`。

## 使用方式

1. 启动 BlackOhm，拖入游戏目录或 `.exe` 文件。
2. 目录中只有一个有效 `.exe` 时会自动入库；多个候选时，从决策弹窗选中主启动程序。
3. 右键游戏卡片可启动、收藏、编辑启动参数、启用 LE 或查看 Session 历史。
4. 在 **设置 → Locale Emulator** 中选择 `LEProc.exe`，设置默认 Profile 和参数模板。
5. 正常使用游戏。只要游戏的可见主窗口在前台，BlackOhm 就会记录时长；经外部启动器或 LE 运行也一样。

## Locale Emulator 参数模板

默认模板：

```text
-run "{exe}"
```

支持：

| 占位符 | 含义 |
| --- | --- |
| `{exe}` | 目标游戏的绝对路径 |
| `{profile}` | LE Profile 名或 GUID |
| `{args}` | 此游戏的附加启动参数 |

例如你的 LEProc 版本要求显式 Profile：

```text
-runas "{profile}" "{exe}" {args}
```

如果模板中 `{profile}` 或 `{args}` 对应值为空，该 token 会被跳过。

## 项目结构

```text
lib/
├── core/
│   ├── app_constants.dart                # 防抖、刷盘、扫描阈值、LE 默认模板
│   ├── path_normalizer.dart              # 运行期/入库路径同构标准化
│   └── database/
│       ├── app_database.dart             # Drift 表定义、WAL、迁移
│       └── app_database.g.dart           # Drift 生成绑定（已提交）
├── data/
│   ├── game_repository.dart
│   ├── session_repository.dart
│   └── settings_repository.dart
├── features/
│   ├── tracking/
│   │   ├── tracking_engine.dart          # 3s 防抖、60s 刷盘状态机
│   │   └── watcher/
│   │       ├── foreground_watcher.dart   # 独立 Isolate + 消息泵
│   │       ├── win32_bindings.dart       # 手写 Windows FFI
│   │       └── watcher_protocol.dart
│   ├── scanner/                          # BFS、PE 资源、PNG、入库分流
│   ├── bangumi/                          # 新增游戏后自动拉取评分/封面
│   ├── launcher/                         # 直启与 Locale Emulator
│   └── tray/                             # tray_manager 服务
├── ui/                                   # Shell、拖拽、页面、卡片、弹窗
│   └── pages/insights_page.dart           # 时长总览、近 7 日趋势、排行
├── providers.dart                        # Riverpod DI / 生命周期
└── main.dart
assets/
├── fonts/MiSans-Regular.otf                # 内置 MiSans 全局 UI 字体
├── icon_source.png                         # 当前 G 图标源图
└── tray.ico                                # 脚本生成的多尺寸托盘图标

docs/ARCHITECTURE.md                      # 数据流、性能和约束说明
tool/generate_app_icons.py                # 从 icon_source.png 生成两个 ICO
```
## 已知限制

- 游戏主进程以管理员权限运行而 BlackOhm 未提权时，`OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)` 可能拒绝访问，导致无法取得镜像路径。此时请以相同权限级别启动 BlackOhm。
- 焦点归属以 Windows 前台窗口为准。无窗口/后台渲染进程、覆盖层或多进程引擎的非主窗口进程需要实际测试。
- 扫描深度默认限制为 3 层，候选上限为 64，目的是避免误拖入磁盘根目录导致长时间 I/O。

## Git 工作流

项目使用 `main` 分支与 Conventional Commit 风格提交。建议流程：

```bash
git checkout -b feat/your-change
flutter analyze && flutter test
git add -A
git commit -m "feat(scope): 描述"
```

Drift 修改后额外执行：

```bash
dart run build_runner build
```

替换应用图标后，将源图放到 `assets/icon_source.png`，执行：

```bash
python tool/generate_app_icons.py
```

脚本会同时生成 `assets/tray.ico` 与 `windows/runner/resources/app_icon.ico`。

## License

本项目以 [MIT License](LICENSE) 发布。

第三方素材与依赖授权：内嵌的 MiSans 字体、全部 Dart 依赖及外部服务的
授权说明见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。
参与贡献前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 与
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)；安全漏洞请通过
[SECURITY.md](SECURITY.md) 描述的渠道私下报告。
