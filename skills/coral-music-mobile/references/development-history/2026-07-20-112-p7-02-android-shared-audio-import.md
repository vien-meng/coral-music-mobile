# P7-02 Android 系统分享音频导入

- 阶段：Batch 8 / Phase 7
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：-

## 目标、范围与依赖

接收 Android `ACTION_SEND`/`ACTION_SEND_MULTIPLE` 音频 URI，将临时可读内容复制到应用缓存目录，再复用现有本地扫描和用户列表导入流程。

不申请全盘存储权限，不处理非音频分享，不把外部 URI 永久作为可播放路径；iOS/OpenHarmony 等价实现另行按平台 API 验证。

## 实施记录

- 2026-07-20：开始原生 URI 接收、缓存副本和 Flutter 侧入列表衔接。
- Android `MainActivity` 已注册 `audio/*` 的 `ACTION_SEND` 和 `ACTION_SEND_MULTIPLE`，接收时仅复制被临时授予读取权限的 URI 到应用私有 files 目录；不请求媒体库/全盘权限。最初使用 cache 目录会被系统清理而导致列表失效，已在同日改为私有持久目录。
- Flutter 启动和热启动均通过 `coral_music/shared_audio` 接收缓存路径；进入“我的列表”后自动创建或复用“分享导入”列表，再复用 `LocalAudioScanner` 和既有去重入库逻辑。
- 首次 Kotlin 构建发现可变 channel 智能转换和表达式函数提前返回错误，已修正；`flutter analyze` 与 Android Debug APK 构建通过。
- 尚未在解锁真机从外部文件管理器真实分享音频，任务保持 DOING；iOS/OpenHarmony 分享桥接也待各平台原生验证。
- 同日补充：外部分享副本限制为 2 GB，超限或复制失败会删除部分文件；Android Debug APK 已再次构建通过。
