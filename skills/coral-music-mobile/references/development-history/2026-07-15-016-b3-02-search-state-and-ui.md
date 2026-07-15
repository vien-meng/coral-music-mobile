# B3-02 搜索状态与界面

- 阶段：Batch 3
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-15
- 完成时间：2026-07-15

## 目标与范围

实现搜索输入、提交、分页、加载、空状态、错误重试和歌曲点击入队。依赖 B3-01 和 B2-05；不实现来源切换、歌单结果、历史或热门词。

## 桌面端基线与决策

对照 `SearchRoutePanel.tsx` 与 `searchStore.ts`。移动端使用单页搜索栏和惰性歌曲列表；请求序号隔离旧响应，不复刻桌面全局 loading 覆盖层。

## 实施、关键接口与平台差异

- 新增 `SearchController`，保存关键词、页码、分页结果、加载和错误；请求序号确保旧关键词响应不能覆盖新结果。
- `SearchPage` 提供输入提交、空状态、加载、错误重试、下拉刷新和分页；歌曲点击以 `search:<source>:<query>:<page>` 上下文替换共享内存队列。
- 路由 `/search` 从占位页切换为真实页面。搜索状态由 Riverpod provider 保留，跨底栏导航返回时无需重复请求。
- 当前仅显示固定酷我来源，符合已落地服务能力；来源切换、综合/歌单搜索、历史和热门词不在本任务范围。

## 实际修改文件与完成内容

- `lib/features/search/state/search_controller.dart`：搜索状态、分页、刷新和旧响应隔离。
- `lib/features/search/view/search_page.dart`：移动搜索界面及入队交互。
- `lib/app/app_router.dart`：挂载 `/search`。
- `test/search_controller_test.dart`：旧响应隔离。
- `test/app_shell_test.dart`：从搜索结果替换队列并更新迷你播放栏。

## 验证

- `flutter analyze`：通过，无问题。
- `flutter test`：通过；搜索解析、状态隔离和 Widget 交互均覆盖。
- `flutter build apk --debug`：通过。
- `flutter build hap --debug`：编译通过并生成 `ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`；DevEco 调试签名尚未配置，无法安装真机。
- 真机：未执行；环境阶段暂停，待 Android 真机连接后补录型号与系统版本。

## 风险、阻塞与后续

输入为空时清空结果而不请求；搜索页离开后状态保留。综合搜索和歌单搜索由后续任务单独记录。关联 P2-03、B2-05。
