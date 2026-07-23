# B4-45 首页酷狗、网易云榜单

状态：DONE

## 目标

- 修复网易云首页榜单的文本 JSON 解析，使用可用的详情端点。
- 接入酷狗 HTTPS 榜单页，填充首页榜单卡片和歌曲列表。

## 已确认

- 网易云 `api/playlist/detail` 当前会返回“服务器忙碌”，而 `api/v6/playlist/detail` 可返回榜单；页面仍可能以文本 JSON 返回，现有解析器只接受 `Map`。
- 酷狗 `mobilecdnbj.kugou.com` 的旧榜单 JSON 只有 HTTP，HTTPS 证书域名不匹配，Android 不能安全使用；当前服务也明确抛出“暂未接入排行榜”。
- 酷狗 HTTPS 榜单网页 `www.kugou.com/yy/rank/home/1-<id>.html` 含 `global.features` JSON，可直接取得 hash、歌手、标题、时长和大小。
- 首页“推荐歌单”区当前实际渲染当前来源的榜单卡片，榜单失败时该区和歌曲列表会一起为空。

## 验证

- 2026-07-23 网络实测：网易云 `api/v6/playlist/detail?id=19723756` 返回 HTTP 200 和 99 首曲目；酷狗 HTTPS 榜单页包含可解析的 `global.features` JSON。
- `flutter analyze`：通过，无诊断。
- `flutter test test/kugou_rank_parser_test.dart test/netease_search_assets_test.dart test/kugou_search_parser_test.dart test/search_controller_test.dart`：9 项通过。
- 已构建并覆盖安装 `build/app/outputs/flutter-apk/app-debug.apk` 到 Android 测试设备。
