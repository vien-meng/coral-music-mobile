# B4-47 搜索歌单与网易云封面

状态：DONE

## 目标

- 修复酷我、酷狗按歌手搜索时歌单结果为空。
- 修复网易云搜索结果封面缺失。

## 已确认

- 酷我该端点当前返回单引号对象文本，现有 JSON/JSONP 解码器会返回空 Map。
- 酷狗桌面端同款 `msearchretry.kugou.com` HTTPS 端点返回 `data.info`，包含歌单 ID、名称、封面和总数。
- 网易云 EAPI 实测歌曲和歌单搜索均返回 HTTPS 可访问的封面；解析器补齐 `pic` 与歌曲顶层 `picUrl` 备用字段，覆盖字段变体。

## 实现与验证

- `decodeJsonMap` 兼容酷我单引号对象文本；酷我歌单搜索可读取新版响应。
- 酷狗实现 HTTPS 歌单搜索与分页解析。
- `flutter analyze`：通过，无诊断。
- `flutter test test/response_json_test.dart test/kuwo_playlist_service_test.dart test/kugou_playlist_service_test.dart test/netease_search_assets_test.dart test/kugou_search_parser_test.dart test/search_controller_test.dart`：20 项通过。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- 已覆盖安装到 Android 测试设备 `R5CR70B7SMA`。
