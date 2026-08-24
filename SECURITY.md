# 安全政策

## 支持版本

| 版本 | 是否支持 |
| --- | --- |
| latest release（v0.2.4 及之后） | ✅ |
| 更早版本 | ❌ 请升级 |

## 报告漏洞

请**不要**通过公开 Issue 报告安全漏洞。

1. 使用 GitHub 的 "Report a vulnerability"（仓库 Security 标签页 → Private vulnerability reporting），
   或私信 [PoMeng233](https://github.com/PoMeng233)。
2. 描述：受影响版本、复现步骤、影响范围、可能的修复思路。

维护者会在 7 天内确认收到，并在评估后给出修复计划；
修复发布后会同步披露细节并致谢报告者（除非要求匿名）。

## 安全设计基线

BlackOhm 定位为纯本地应用，审计时可关注以下边界：

- **无遥测、无账户**：除用户主动配置 Bangumi Token 后的 api.bgm.tv 查询外，不发起任何网络请求。
- **凭证存储**：Bangumi Token 仅保存在本机 SQLite 设置表（`settings_repository.dart`），不写入日志，不上传。
- **进程访问**：watcher isolate 仅使用 `OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)`
  读取前台进程镜像路径与命令行（后者仅对临时目录内的包装壳进程读取），
  不写入目标进程内存。
- **数据库**：Drift + SQLite（WAL），全部数据位于用户应用支持目录，随应用卸载保留于本机。

若你发现上述任何一条边界被突破（例如出现未声明的网络请求、Token 泄漏路径），
请按上述流程立即报告。
