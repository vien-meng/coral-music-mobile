# UI-16 列表动作反馈与子页面返回

- 阶段：高保真 UI / 列表与应用壳
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20

## 问题与范围

推荐、搜索和歌单歌曲的下载按钮直接丢弃 `enqueue` 结果，没有加入/重复提示，也不反映已下载状态；收藏按钮无反馈且始终使用空心图标。我的列表、我的收藏、下载和设置从“我的”页使用替换式导航，页面缺少可见返回入口，系统返回也无法回到上一层。

## 实施原则

- 列表复用一个下载按钮，直接观察既有 `downloadProvider`，不新增下载状态。
- 收藏按钮继续复用 `libraryProvider`，移除无关全局加载对点击的拦截，并明确显示实心/空心状态及结果反馈。
- 壳内子页面使用 `push` 保留系统返回栈；共享返回按钮在无栈的直接进入场景回到“我的”，不改播放器进入下载页必须使用 `go` 的红屏修复。

## 实施与验证

- 2026-07-20：开始实现并补最小路由与动作回归。
- 2026-07-20：新增 `DownloadTrackButton`，推荐榜单、搜索结果、歌单详情和播放队列统一显示空闲/下载中/已下载图标，并反馈加入成功、重复任务、已下载或来源不可下载。
- 2026-07-20：`FavoriteTrackButton` 在点击时立即乐观切换实心/空心心形并阻止重复提交，收藏/取消后显示 SnackBar；移除 `LibraryController.toggleFavorite` 对无关全局加载状态的静默拒绝，事务失败时重新读取数据库状态。
- 2026-07-20：“我的”四个快捷入口统一使用 `push`；列表、收藏、下载和设置路由由 `AppBackScope` 处理系统返回，无返回栈时回到 `/more`，页面标题区使用共享 `AppBackButton`。播放器到下载仍保留 `go`，避免 UI-15 的重复导航壳回归。
- `test/more_page_test.dart` 增加快捷子页面系统返回栈回归；`test/app_shell_test.dart` 增加播放器进入下载后可见返回按钮和系统返回兜底断言。
- 本次相关文件 `dart analyze` 与 `git diff --check` 通过；`flutter run -d R5CR70B7SMA --debug` 成功构建、安装并进入首帧。
- `flutter test test/app_shell_test.dart test/more_page_test.dart` 因工作区外 Flutter SDK cache 锁文件无写权限未执行，自动提权服务返回 503；任务保持 `DOING`。
