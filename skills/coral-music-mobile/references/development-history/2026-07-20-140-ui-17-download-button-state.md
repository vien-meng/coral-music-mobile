# UI-17 下载按钮即时状态

- 阶段：高保真 UI / 下载
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20

## 目标与根因

点击单曲下载后立即显示下载中状态，任务完成后显示勾选状态。推荐、搜索、歌单、播放队列和播放详情使用同一状态按钮。

共享列表按钮此前会等待下载控制器完成启动恢复后才出现任务状态，首次点击期间没有视觉反馈；播放详情仍使用独立的一次性下载动作，不订阅下载队列。

## 验证要求

- 点击后首帧显示加载状态并阻止重复提交。
- `queued/downloading` 显示下载中，`paused` 显示暂停，`completed` 显示勾。
- 播放详情和歌曲列表复用同一按钮，成功加入仍提供“查看”入口。

## 实施与验证

- `DownloadTrackButton` 改为带本地提交态的共享状态按钮，不等待下载控制器启动恢复即可立即显示加载动画，并在提交期间阻止重复点击。
- `queued/downloading` 显示加载动画，`paused` 显示暂停图标，`completed` 显示勾；播放详情同时显示“下载中/已暂停/已下载”文字。
- 删除播放详情独立的 `enqueuePlayerDownload`，播放详情、推荐、搜索、歌单和播放队列统一观察 `downloadProvider`；成功加入继续提供“查看”入口。
- 加入任务异常会退出加载态并显示失败提示，不会永久转圈。
- `test/app_shell_test.dart` 增加点击首帧出现加载动画的断言；`dart format`、针对性 `dart analyze` 和 `git diff --check` 通过。
- Samsung SM-N986U / Android 13 已完成 Debug APK 构建、安装和首帧启动。
- `flutter test test/app_shell_test.dart` 受工作区外 Flutter SDK 缓存锁限制，提权审批服务返回 503，测试未执行，因此任务保持 `DOING`。
