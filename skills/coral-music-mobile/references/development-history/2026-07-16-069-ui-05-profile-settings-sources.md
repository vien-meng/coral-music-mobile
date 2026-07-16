# UI-05 我的、设置与音源入口高保真重构

- 阶段：高保真 UI 重构 / 第五任务
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标与范围

按设计稿把“我的”从纯入口列表改为用户卡片、快捷功能网格和分组设置卡；设置/User API 页面改为轻量分组表单，保留真实导入、启用、移除和播放调试功能。未实现的下载/WebDAV 继续明确显示为计划中入口，不能伪装为已完成。

## 依赖与不做事项

- 依赖已有 `MorePage`、`UserApiDebugPage`、路由和 `UserApiDebugController`。
- 本任务不新增账号系统、下载状态、WebDAV 数据或音源持久化；仅改视觉和入口组织。
- 现有 User API HTTPS 约束、错误文案、启用开关及敏感信息边界不变。

## 实施与验证

- 预期修改 `lib/app/placeholder_page.dart`、`lib/features/player/view/user_api_debug_page.dart`，并保持所有九入口可导航。
- 完成后执行 Dart format、差异检查和 skill 校验；HOS SDK 恢复后再运行全套静态/Widget 回归。

## 实际进展

- 已修改 `lib/app/placeholder_page.dart` 中的 `MorePage`：现在具备设计稿对应的“我的”顶部、无账号承诺的本地音乐 Free 卡片、真实路由快捷网格和功能/设置分组卡。所有入口仍使用既有 `go_router` 路由；下载/WebDAV 等未完成能力仍会进入其原有状态页，未伪造数据或完成状态。
- 选择暂不重写 `UserApiDebugPage` 的表单行为：它是当前真实音源导入与调试入口，先保留完整、可验证的交互，下一轮在不干扰脚本编辑/导入的前提下只调整视觉外壳。
- 已通过 Dart format、`git diff --check` 和 skill 校验。Flutter 工具链检查仍由缺失 HOS SDK 阻断，因此任务继续 `DOING`。
- 补充验证：`dart analyze lib test` 已在当前 UI 合并状态通过；Flutter Widget 和 Android 真机视觉回归尚待执行。

## 关联

- 计划：`2026-07-16-064-plan-high-fidelity-ui.md`。
- 前置：UI-01–04；后续：UI-06 三端视觉回归。
