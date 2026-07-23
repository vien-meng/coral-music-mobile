# B4-43 酷狗文本 JSON 搜索响应

状态：DONE

## 目标

- 让酷狗歌曲搜索正确解析服务端标记为 `text/plain` 的 JSON 响应。

## 已确认

- `songsearch.kugou.com/song_search_v2` 在 2026-07-23 返回 HTTP 200、有效 JSON，但响应头是 `Content-Type: text/plain; charset=utf-8`。
- Dio 只在 JSON Content-Type 时自动解码；当前解析器仅接受 `Map`，所以真机收到字符串后报“酷狗音乐搜索数据格式异常”。
- 项目已有 `decodeJsonMap`，已兼容 JSON/JSONP 字符串；复用它即可，无需改端点、增加签名或新依赖。

## 验证

- 2026-07-23 公开端点实测：HTTP 200，响应头为 `Content-Type: text/plain; charset=utf-8`，正文为有效 JSON 且含歌曲列表。
- `flutter analyze`：通过，无诊断。
- `flutter test test/kugou_search_parser_test.dart test/search_controller_test.dart`：5 项通过，新增字符串 JSON 解析回归断言。
- 已构建并覆盖安装 `build/app/outputs/flutter-apk/app-debug.apk` 到 Android 测试设备。
