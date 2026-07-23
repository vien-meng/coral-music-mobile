# B4-46 来源能力菜单与酷狗歌单广场

状态：DONE

## 目标

- 所有在线页面的平台菜单只显示当前启用 User API 声明可播放、且当前页面确有数据服务的平台。
- 歌单广场补齐网易云与酷狗；酷狗使用桌面端同类公开移动站 HTTPS 数据，不使用证书不匹配的旧接口。

## 验证

- `flutter analyze`：通过，无诊断。
- `flutter test test/online_source_menu_test.dart test/kugou_playlist_service_test.dart test/netease_search_assets_test.dart test/song_list_controller_test.dart test/search_controller_test.dart`：13 项通过。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- 网络实测：网易云 `api/personalized/playlist` 返回推荐歌单；酷狗 `m.kugou.com/plist/index?json=true&page=2` 返回分页歌单，歌单详情页包含 `var data` 曲目 JSON。

## 实现

- 歌单广场、排行榜和搜索的菜单从各自注册的服务 Map 读取候选来源，再通过当前启用 User API 的 `musicUrlSources` 过滤。
- 网易云补齐推荐歌单；酷狗补齐 HTTPS 广场、详情页曲目和 User API 所需的 hash、质量元数据。
- 酷狗歌单关键词搜索仍无可验证的 HTTPS 公开端点，保留明确的“暂未接入”提示，避免使用证书域名不匹配的旧 CDN。
