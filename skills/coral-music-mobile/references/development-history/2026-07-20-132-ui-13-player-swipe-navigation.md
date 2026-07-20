# UI-13 播放页滑动导航

- 阶段：高保真 UI / 播放详情
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20

## 范围

播放界面左滑进入歌词，歌词界面右滑返回播放；播放界面在顶部向下拉超过阈值后退出详情页。复用 Flutter `PageView` 和滚动通知，不新增手势依赖，不让歌词纵向滚动或播放进度 Slider 触发退出。

## 实施与验证

- 播放与歌词改为同一 `PageView` 的相邻页面：左滑进入歌词，右滑返回播放；顶部标签和右侧切换按钮统一驱动同一个 `PageController`。
- 播放主控滚动视图使用 `AlwaysScrollableScrollPhysics`。页面只累计播放页顶部向下的 overscroll，松手时达到 80 px 才调用系统 `maybePop`；歌词页及非顶部滚动不会退出。
- 空播放页增加 `PageController.hasClients` 保护，避免无曲目时点击标签触发未挂载断言。
- `test/app_shell_test.dart` 新增左右 fling 和顶部下拉关闭回归，并抽取共享打开播放页 helper。
- 本次改动文件 `dart analyze` 无问题，`git diff --check` 通过。`flutter test test/app_shell_test.dart` 因工作区外 SDK 缓存授权服务返回 503 未执行，状态保持 `DOING`。
