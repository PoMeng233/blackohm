# Third-Party Notices / 第三方素材与依赖声明

本项目基于 MIT License 发布。以下列出随项目分发的第三方素材与运行时依赖及其授权。

## 内嵌字体

### MiSans Regular（assets/fonts/MiSans-Regular.otf）

- 版权方：小米科技有限责任公司（Xiaomi），与汉仪字库、蒙纳字库联合设计。
- 来源：<https://hyperos.mi.com/font>
- 授权：《MiSans 字体知识产权许可协议》——全球范围免费商用，允许作为嵌入式字体集成到软件中分发，无需支付版税。
- 合规说明：依协议第 1 条，BlackOhm 特此注明：**本软件内嵌并使用了 MiSans 字体**。
- 限制：字体文件本身不得单独转售或二次修改后分发；该限制不约束使用本字体创作的软件作品（即 BlackOhm 本体）的分发。

## 运行时依赖（pubspec.yaml）

| 包 | 许可证 |
| --- | --- |
| flutter_riverpod / riverpod | MIT |
| drift | MIT |
| sqlite3_flutter_libs / sqlite3 | MIT（捆绑的 SQLite 3 为 Public Domain） |
| path_provider（及平台实现） | BSD-3-Clause（Flutter Authors） |
| path | BSD-3-Clause（Dart 项目作者） |
| image | MIT（部分组件 Apache-2.0 / BSD） |
| ffi | BSD-3-Clause（Dart 项目作者） |
| window_manager | MIT |
| tray_manager | MIT |
| desktop_drop | Apache-2.0 |
| file_picker | MIT |
| url_launcher（及平台实现） | BSD-3-Clause（Flutter Authors） |
| package_info_plus | BSD-3-Clause（Chromium Authors） |

以上均为宽松许可证（MIT / BSD / Apache-2.0），与本项目的 MIT 授权兼容。
各依赖的完整许可证文本可在对应源码仓库或 pub.dev 包页面查阅；
Flutter 构建产物中的 `NOTICES.Z` 也自动汇总了传递依赖声明。

## 外部服务（可选，用户自行配置）

- Bangumi API（api.bgm.tv）：仅当用户在设置中主动填写 Access Token 后，
  用于按标题检索游戏封面/评分。应用本体不内置任何凭证。

## 项目图标

`assets/icon_source.png`、`assets/tray.ico`、`windows/runner/resources/app_icon.ico`
均由仓库内脚本（tool/gen_icon_source.py、tool/generate_app_icons.py）程序化生成，
为本项目原创内容，随 MIT License 一并授权。
