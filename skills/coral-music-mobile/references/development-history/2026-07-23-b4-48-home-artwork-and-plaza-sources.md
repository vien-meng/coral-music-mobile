# B4-48 首页封面与歌单广场来源菜单

状态：DONE

## 目标

- 修复首页酷狗、网易云榜单及列表的封面数据链。
- 复核歌单广场来源菜单是否和首页同样由当前 User API 的声明能力与本页服务交集生成。

## 已确认

- 酷狗 HTTPS 榜单页的 `global.features` 只含 hash、专辑 ID、歌名和歌手，不含图片；落雪桌面端会调用 `media.store.kugou.com/v1/get_res_privilege` 补齐 `info.image`。
- 网易云 V6 榜单曲目含 `al.picUrl`；EAPI 搜索适配层重组曲目时遗漏了资源卡片图片字段。
- 歌单广场、首页均通过同一个 `supportedOnlineSources(页面服务来源, activeSource.musicUrlSources)` 生成菜单；本次将保留该动态能力约束并新增覆盖测试，避免重新写死平台集合。

## 计划

1. 在酷狗榜单请求后以一次批量资源请求补齐封面，失败仅降级为无图。
2. 保留网易云 EAPI 资源图到曲目模型。
3. 补充菜单和两条封面链路的可运行测试，执行静态检查和针对性测试。

## 实现与验证

- 酷狗榜单在 HTTPS 页面解析后，复用桌面端资源权限接口的一次批量请求补齐图片 URL；接口不可用时保留歌曲结果并显示既有无图占位。
- 网易云 EAPI 搜索保留 `uiElement.image.imageUrl`，再由既有 HTTPS 归一化落入 `Track.coverUri`。
- 歌单广场与首页继续使用相同的 `supportedOnlineSources`：页面已实现的服务来源与当前 User API 声明的 `musicUrlSources` 取交集；`kg`、`wy` 同时声明时都会显示。
- `flutter analyze`：通过，无诊断。
- `flutter test test/kugou_rank_parser_test.dart test/netease_search_assets_test.dart test/online_source_menu_test.dart test/song_list_controller_test.dart`：13 项通过。
- `flutter build apk --debug`：通过，已覆盖安装 `build/app/outputs/flutter-apk/app-debug.apk` 到 Android 测试设备。
