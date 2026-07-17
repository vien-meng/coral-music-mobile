# UI-07 音源 URL 导入优先与详情卡片

- 阶段：高保真 UI 重构 / 音源管理增量
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-17
- 完成时间：2026-07-17

## 目标、范围与依赖

将 HTTPS URL 音源导入提升为页面首要操作；将手动脚本粘贴收进明确标注的高级/调试区，避免大文本框遮蔽正常用户流程。导入成功后用可读的音源详情卡替换“音源 1”和来源代号直出，展示脚本声明的名称、版本、作者、主页、描述和经过翻译的支持能力。

依赖 B4-12、B4-20、UI-05 既有受限 User API 管理、HTTPS 下载及 Android WebView 运行时。不改变脚本仅在会话内存、仅 HTTPS 下载、256 KiB 限制、受限网络和单一活动脚本的安全边界；不添加脚本持久化、文件导入或商店动态脚本放行。

## 桌面基线、实施方案与验收

对照桌面 User API 运行时收到的 `inited` API 信息：除来源能力外，保留脚本自身 `info` 中可公开展示的元数据。移动端扩展 `UserApiManifest` 和 Android `ready` 通道返回值，仅传递长度受限的普通文本字段；Flutter 状态保存该详情，UI 将来源 ID 映射为音乐服务名称与功能标签。

验收：真实 LX HTTPS 地址导入后，页面顶部显示已启用音源详情与支持平台，而不是通用序号；手动脚本仅在用户展开“高级导入”后显示；URL 仍走现有验证/启用链路。

## 进行中

- 已复查 UI-05 现状：URL 输入框位于完整脚本文本框之后，且导入结果只保存 `musicUrlSources`/`lyricSources`，无法呈现脚本身份信息。
- 实际采用脚本顶部的公开 JSDoc 声明而非扩展平台桥接：`@name`、`@description`、`@version`、`@author`、`@homepage`/`@repository` 由共享 Dart 层只读解析。这样 iOS/Android/鸿蒙可以得到同一详情，并且不执行或持久化任何额外脚本内容。

## 实际修改、验证与完成结论

- `lib/features/player/state/user_api_debug_controller.dart`：新增会话内 `UserApiSourceInfo`，导入时解析公开头部元数据；URL 导入保留来源地址；没有名称声明时显示“未命名音源”，不再生成“音源 N”。
- `lib/features/player/view/user_api_debug_page.dart`：将 URL 卡片移到页首；粘贴脚本和播放调试改为折叠的“高级导入”“播放调试”；导入结果展示名称、描述、版本、作者、主页、来源地址，以及“酷我音乐 · 播放”等中文能力标签。
- 自动验证：`flutter test test/user_api_debug_controller_test.dart -r compact` 通过 2 项（包含 LX 头部元数据解析）；`flutter analyze`、`flutter build apk --debug` 和 `git diff --check` 通过。
- 真机验收：Samsung SM-N986U / Android 13 覆盖安装 Debug APK 后，用用户指定 LX URL 从顶部入口真实导入。页面显示 `[独家音源]`、描述“音源更新，关注微信公众号：洛雪科技”、版本 `4`、作者、GitHub 仓库、完整导入地址，以及酷狗/酷我/本地/咪咕/QQ/网易云的中文能力卡；高级脚本与调试入口保持收起。
- 本任务状态为 `DONE`。仍未实现的脚本持久化、文件导入和商店动态脚本门控继续由 B4-12/B4-20 的既定范围承接。
