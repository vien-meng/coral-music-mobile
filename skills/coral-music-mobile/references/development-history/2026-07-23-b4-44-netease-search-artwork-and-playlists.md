# B4-44 网易云搜索封面与歌单

状态：DONE

## 目标

- 网易云歌曲搜索将封面 URL 规范为 HTTPS，供搜索列表和媒体通知共用。
- 网易云搜索的“歌单”标签返回该平台歌单，并可进入详情。

## 已确认

- EAPI 歌曲响应中的 `simpleSongData.al.picUrl` 有真实封面，但为 HTTP；曲目模型保留原 URL，媒体通知等不经 UI 图片组件的调用会被 CDN 拒绝。
- 搜索页按当前歌曲来源索引 `playlistCatalogServicesProvider`，该 Map 只有酷我、QQ、咪咕，没有网易云，故网易云的歌单标签必为空。
- 网易云公开 `api/search/get/web` 的 `type=1000` 已实测返回歌单，`api/v6/playlist/detail` 已实测返回歌单和曲目；两者均以 `text/plain` 返回 JSON。

## 验证

- 2026-07-23 公开接口实测：`api/search/get/web?type=1000` 返回歌单，`api/v6/playlist/detail` 返回曲目；均为 `text/plain` JSON。
- `flutter analyze`：通过，无诊断。
- `flutter test test/netease_search_assets_test.dart test/search_controller_test.dart test/cover_image_test.dart`：7 项通过，覆盖 HTTPS 封面和文本 JSON 歌单搜索。
- 已构建并覆盖安装 `build/app/outputs/flutter-apk/app-debug.apk` 到 Android 测试设备。
