# B6-08 有效设置入口

- 阶段：Batch 7 / Phase 6
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 范围

将“设置”与“音源管理”拆开：设置页只导航到已有真实能力（音源、下载、WebDAV、我的列表），不添加无效主题/代理开关。

## 实际修改

- `/setting` 现在是有效设置页；`/setting/source` 才是音源管理。播放器“去导入音源”直达后者。
- “我的”页增加透明 Material 根节点，修复独立页面/测试环境下 InkWell 没有 Material 祖先的问题。
- `flutter analyze`、`flutter test test/more_page_test.dart test/player_controller_test.dart`、`git diff --check` 通过。
- SM-N986U（Android 13）已重新构建、安装并启动 Debug APK；Flutter 运行时正常连接，未见 Dart/Flutter 崩溃。设备图形驱动的 Adreno/Gralloc 格式日志不属于应用异常。
- 状态：DONE；主题、语言、代理等没有真实持久化行为的设置继续后置。
