---
name: coral-music-mobile
description: Project-specific architecture, feature-parity map, and phased delivery workflow for 珊瑚音乐/coral-music-mobile. Use when planning, implementing, testing, or reviewing the Flutter app for iOS, Android, and HarmonyOS, especially for desktop feature parity, playback, online sources, local music, lists, downloads, WebDAV, User API, settings, platform bridges, or store release readiness.
---

# 珊瑚音乐移动端

把桌面端 `coral-music-desktop` 作为行为基线，用一套 Flutter/Dart 业务代码实现 iOS、Android、鸿蒙三端。复刻用户能力，不照搬 Electron 布局或桌面操作方式。

## 工作流

1. 开始任务前检查桌面端当前实现；参考文件是地图，不替代源码。
2. 读取 `references/feature-parity.md`，确认目标能力、优先级、平台等价方案和验收场景。
3. 读取 `references/architecture.md`，沿既定领域模型、数据边界和平台桥接实现；不要在功能代码中直接写平台判断。
4. 读取 `references/development-plan.md`，按依赖顺序领取最小可验收任务，并更新其中的状态表。
5. 写代码前在 `references/development-history/` 创建该任务的独立历史文件并标记 `DOING`。
6. 先实现贯穿 UI、状态、数据、平台能力的纵向切片，再扩展同类功能。
7. 每个非平凡行为至少留下一个可运行检查；涉及音频、后台、文件或权限时必须补真机验证记录。
8. 完成时回写任务历史、`development-plan.md` 和 `feature-parity.md`；没有历史或验证证据的任务不得标记 `DONE`。

## 不变量

- 保持搜索、歌单、排行榜、我的列表、收藏、音乐分类、下载、WebDAV、设置九个产品入口的行为对等。
- 默认进入排行榜；歌单或榜单“播放全部”替换队列并播放当前页第一首；跨页面保留已加载状态。
- 在线、本地、已下载、WebDAV 是四种独立来源。本地和 WebDAV 不进入 User API、在线取链或在线音质降级。
- 保持 LX User API 协议兼容，但所有动态脚本必须运行在受限沙箱；商店政策高于动态导入完整度。
- 同目录本地歌词优先于在线歌词，按“同名、歌手 - 歌名、歌名 - 歌手、歌名、模糊匹配”查找。
- 账号密码、Token 和 User API 密钥只进入系统安全存储，日志、SQLite、崩溃信息不得包含明文。
- 共享 Dart 层不依赖 UIKit、Android SDK 或 ArkTS；仅平台桥接层可以调用系统 API。
- 三端同步验收。某个平台只有占位实现时，不得把对应功能标记完成。

## 简化原则

- 优先 Flutter、Dart 标准能力和系统媒体能力；只有验证缺口后才引入插件。
- 不使用代码生成框架，不创建只有一个实现且没有测试价值的接口。
- 只为音频、媒体会话、后台下载、动态脚本和安全存储保留平台边界。
- 不建设项目自有的服务器存储、跨设备同步或局域网服务；WebDAV 仅连接用户自行配置的远程文件源，备份仅为本地文件导入/导出。
- 不复制 Electron IPC、窗口、托盘、WASAPI 或 React 组件；实现其移动端用户目标。

## 验证顺序

1. `dart format --output=none --set-exit-if-changed .`
2. `flutter analyze`
3. `flutter test`
4. `flutter build hap --debug`
5. 环境具备后执行 `flutter build apk --debug` 与 `flutter build ios --debug --no-codesign`
6. 音频、后台、媒体按键、Range seek、文件导入和安全存储必须在三端真机复验。

## 参考资料

- `references/feature-parity.md`：桌面功能基线、优先级、平台等价和验收矩阵。
- `references/architecture.md`：Flutter 分层、类型、存储、平台接口、数据流和安全要求。
- `references/development-plan.md`：Phase 0–7 任务、依赖、门槛、人员、工期和当前状态。
- `references/development-history/`：每份计划与开发任务的实施、决策、验证、阻塞和恢复记录。
