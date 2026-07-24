# 鸿蒙受限 User API 运行时

- 阶段：P0-09 / B4-12
- 状态：DOING
- 开始时间：2026-07-24

## 目标

为鸿蒙实现既有 `coral_music/user_api` 通道的受限 WebView 运行时，覆盖脚本加载、来源声明、`musicUrl` 取链与清理。

## 边界

仅加载本地空页面；禁止页面导航、`fetch` 与 XHR。脚本下载必须使用 HTTPS，取链请求经原生公开 HTTP/HTTPS 代理，限制 GET/POST、20 秒超时、64 KiB 请求体与 1 MiB 响应，并拒绝 DNS 解析到本机、私网、链路本地、组播和保留地址。Android/iOS 不改动。

## 验收

导入真实 LX HTTPS 音源后，能声明来源、完成酷我取链并播放；删除音源后旧运行时和请求被清理。

## 2026-07-24 补充

- 文件选择统一经 `coral_music/file_access`；鸿蒙手机保留音频/文档选择，资料备份、列表导出和下载文件导出使用系统文档保存器。
- 鸿蒙手机不支持任意目录授权，因此下载固定在应用目录；完成下载可导出到用户选择的位置。
- `just_audio_harmonyos` 将固化为工程内的最小上游副本，补齐 API 20/6.1.1 要求的 `MediaSource.enableOfflineCache`，避免依赖本机 pub 缓存的手工改动。
- 完整的本机配置、构建、安装、调试与回归流程见 [鸿蒙构建与真机调试流程](../ohos-build-and-device-debugging.md)。

## 2026-07-24 取链空结果回归（DOING）

- 鸿蒙真机已能导入并初始化公开 LX 音源，但在线播放时原生桥接显示 `Cannot read property of null or undefined`。
- 已对照桌面 `normalizeUserApiMusicUrlResult`：桌面在读取 `data` 前会验证结果为非空对象，并将 `{ url }` 与 `{ data: { url } }` 视为等价返回；当前鸿蒙实现缺少这层保护。
- 本轮只补齐该结果归一化和桌面已公开的请求回调字段，不改 Android/iOS 的运行时。脚本下载仍要求 HTTPS；取链代理与 Android 一致允许公开 HTTP/HTTPS，并在请求前解析 DNS 后拒绝回环、私网、链路本地、组播和保留地址。
- 验证：`flutter build hap --debug` 已通过，产物为 `build/ohos/hap/entry-default-signed.hap`；`flutter test test/user_api_runner_test.dart` 3 项通过；`git diff --check` 通过。Flutter 已识别并部署到鸿蒙真机 `22M0224425009013`（OpenHarmony 6.1 / API 23）；真实 LX 取链与播放仍待在设备上点播回归。
