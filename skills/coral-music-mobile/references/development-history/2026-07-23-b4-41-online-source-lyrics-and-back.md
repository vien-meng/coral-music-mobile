# B4-41 在线来源、歌词与返回行为

状态：DOING

## 目标

- 让酷狗、网易云保持独立搜索；播放能力由 User API 在点播时判断。
- 保持歌词请求不经过 User API，并补齐酷狗 KRC 的逐字时间轴。
- 搜索与“我的”根页面的系统返回回到首页，首页才退到桌面。

## 已确认

- 默认搜索菜单错误按 `musicUrlSources` 过滤；公开酷狗搜索端点在 2026-07-23 可返回数据，Android 真机上的网易云旧 Web 搜索接口会返回无歌曲结构，需改用落雪同款 EAPI。
- 落雪移动端把搜索、歌词和 `getMusicUrl` 分开：搜索/歌词由各平台 SDK 完成，播放 URL 由单独 API source 负责。
- 当前酷狗歌词固定下载 LRC 且取第一个候选，丢弃了 KRC 逐字时间；网易云公开 LRC 需读取可选的 YRC 才有逐字数据。

## 验证

- `flutter test test/kugou_krc_test.dart test/netease_yrc_test.dart test/app_shell_back_test.dart test/kugou_search_parser_test.dart test/lyric_timeline_test.dart test/lyric_controller_test.dart test/search_controller_test.dart`：21 项通过。
- `flutter analyze`：通过，无诊断。
- 完整 `flutter test`：本改动相关测试通过；仓库原有 16 项失败，包括播放器重复完成断言、未初始化 sqflite 的壳页面测试和 URI 转义断言，未由本任务修改。
- Android：已构建并覆盖安装 debug APK；验证搜索页可进入。EAPI 改动后的网易云平台菜单选择与点播、酷狗点播、歌词和系统返回键仍待人工回归；任务保持 DOING。
