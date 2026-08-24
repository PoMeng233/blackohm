# 贡献指南

感谢关注 BlackOhm！欢迎以 Issue 反馈问题、以 Pull Request 提交改进。

## 提交 Issue

- **Bug**：请附上 Windows 版本、复现步骤、期望与实际行为；涉及计时不准时，
  尽量说明游戏的启动方式（直接双击 / Locale Emulator / 外部启动器）。
- **功能建议**：先说明使用场景，避免与"纯本地、被动记录"的项目定位冲突。

## 开发流程

```bash
git checkout -b feat/your-change
flutter pub get
flutter analyze        # 必须零告警
flutter test           # 必须全部通过
```

提交信息遵循 Conventional Commit 风格：

```text
feat(scope): 简短描述
fix(scope): 简短描述
```

## 代码约定

- Windows 平台交互一律通过 `lib/features/tracking/watcher/win32_bindings.dart`
  的手写 FFI 绑定，不引入 win32 包装库。
- UI 文案使用中文，代码标识符使用英文。
- 不新增网络请求：本项目坚持"本地优先"，唯一的例外是用户主动配置的
  Bangumi API（见 lib/features/background/）。

## Pull Request 要求

1. 关联对应 Issue（如有）。
2. 为可测的纯逻辑补充单元测试（参考 test/ 下现有风格）。
3. 涉及 Drift 表结构变更时，执行 `dart run build_runner build`
   并一并提交生成的 `app_database.g.dart`。
4. 保持 CHANGELOG.md 的更新。

## 许可

提交即表示同意你的贡献以 [MIT License](LICENSE) 随项目分发。
