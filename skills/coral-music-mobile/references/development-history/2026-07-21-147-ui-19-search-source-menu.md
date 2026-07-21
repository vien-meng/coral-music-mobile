# UI-19 搜索页音乐平台菜单统一

- 阶段：高保真 UI / 在线发现
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-21

## 目标

搜索页仍使用系统默认 `PopupMenuButton`，与首页的主题化 `MenuAnchor` 在圆角、描边、图标和选中态上不一致。复用首页菜单视觉，保留搜索页独有的综合搜索和全部搜索来源。

## 验证要求

- 首页和搜索页的平台菜单使用同一表面、描边、圆角、图标及勾选态。
- 搜索页选择综合搜索或单一来源仍调用既有搜索控制器。

## 实施与验证

- 提取 `OnlineSourceMenu`，首页和搜索页共用菜单表面、标题、图标、固定宽度和当前项勾选态；首页通知菜单复用同一表面样式。
- 搜索页保留综合搜索、酷狗及其余五个搜索来源，继续分别调用 `SearchController.selectCombined()` 和 `selectSource()`。
- `test/online_source_menu_test.dart` 覆盖菜单打开后的选中态和来源回调。
- `dart format`、定向 `dart analyze` 与 `git diff --check` 通过。
- Flutter 测试未运行：本轮已知工作区外 Flutter SDK 缓存锁的审批服务返回 HTTP 503，待服务恢复后执行 `flutter test test/online_source_menu_test.dart`，任务保持 `DOING`。
