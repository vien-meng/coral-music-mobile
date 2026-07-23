# B4-49 歌单详情兼容与补图

状态：DOING

## 目标

- 修复酷狗歌单详情脚本格式变化造成的歌曲缺失。
- 补齐咪咕歌单详情的专辑封面字段。
- 避免酷我从一张歌单切换到另一张时，旧补图任务阻塞新歌单。
- 确认可用的 QQ 歌单详情兼容路径。

## 已确认

- 酷狗当前详情将曲目写为 `var data=[…];`，而现有解析只接受后面紧接 `, var` 的旧写法。
- 咪咕详情的曲目响应可能仅含 `albumImgs[0].img`，桌面端会读取该字段；移动端漏读。
- 酷我补图任务单例在跨歌单快速切换时会复用上一张歌单的 Future，导致新详情不启动补图。
- QQ 旧详情端点当前返回 `subcode: 4000, check privacy error`；需验证兼容入口后再替换，不把空响应伪装成格式异常。

## 实现与验证

- 酷狗详情解析接受 `var data=[…];` 与旧逗号形式，不再依赖后续变量名；2026-07-23 已在 Android 真机打开公开歌单并确认加载 30 首及曲目封面。
- 咪咕曲目封面按桌面端顺序读取 `img3/img2/img1/albumImgs[].img`，并兼容协议相对 URL。
- 酷我补图任务按详情修订隔离；切换或关闭歌单后旧任务不能占用或回写新详情。
- QQ 详情切至官方分享页使用的 Musicu `music.srfDissInfo.aiDissInfo.uniform_get_Dissinfo`，保留旧 `cdlist` 响应解析兼容；实测公开歌单返回 66 首曲目，且真机可打开详情。QQ 曲目封面尚未在真机确认，不能标记完成。
- 网易云优先封面字段为空时继续回退 `picUrl`，而不是将空字符串解析为无封面。
- `flutter analyze`：通过，无诊断。
- `flutter test test/netease_search_assets_test.dart test/kugou_playlist_service_test.dart test/migu_playlist_service_test.dart test/kuwo_playlist_service_test.dart test/qq_playlist_service_test.dart test/song_list_controller_test.dart`：27 项通过。
- `flutter build apk --debug`：通过，已覆盖安装 `build/app/outputs/flutter-apk/app-debug.apk` 到 Android 测试设备。
