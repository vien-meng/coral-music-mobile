# B4-27 iOS 受限 User API 运行时

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-17
- 完成时间：未完成

## 目标、范围与依赖

为 iOS 补齐与 Android 一致的 `coral_music/user_api` MethodChannel：会话内加载 LX 音源脚本、识别 `musicUrl`/`lyric` 能力、受限 HTTPS 请求、取链、歌词与清理。依赖既有 Dart `UserApiRunner` 协议和 B4-12 的脚本管理界面。

不做内容：脚本持久化、任意 WebView 导航、HTTP 出口、Cookie/本地存储、文件访问、商店版动态脚本政策结论、iOS 真机验收。iOS Platform Runtime 尚未安装，不能把本次实现标记为跨端验收完成。

## 桌面端对照与行为

- 对照：`coral-music-desktop/src/renderer-react/services/musicSdkRuntime.ts` 的 User API `musicUrl` 与 `lyric` 请求协议。
- 移动端行为：保留 Android 的 256 KiB 脚本上限、20 秒脚本/取链超时、HTTPS-only、GET/POST、64 KiB 请求体与 1 MiB 响应上限；原始脚本不写入磁盘和日志。

## 实施方案

- 在 `ios/Runner` 新增 `UserApiRunner.swift`，使用不可见 `WKWebView` 执行脚本；仅通过 `WKScriptMessageHandler` 暴露最小 `lx`/`coral` bridge，只允许内部 `localhost.invalid` 空文档导航。
- 原生 `URLSession` 执行脚本请求，并将结果异步回送给 JS；页面本身不拥有网络导航权限。
- `AppDelegate` 注册既有 channel 的 `load`、`clear`、`resolveMusicUrl`、`resolveLyric`；桌面/Android 与 Dart 接口不分叉。

## 恢复入口、风险与下一步

- 关键风险：真实 LX 脚本是否依赖 iOS 12 WebKit 未覆盖的 Web API，尤其是其是否依赖同步 MD5 能力。
- 下一步：完成最小桥接并执行 iOS 无签名构建；待 iOS Platform Runtime 和真机配置完成后导入用户指定的 LX HTTPS 地址，验证取链、播放和歌词。

## 2026-07-17 实施与构建验证

- 已新增 `ios/Runner/UserApiRunner.swift`，以临时 `WKWebView` 实现 Android 同名 channel 的 `load`、`clear`、`resolveMusicUrl`、`resolveLyric`；加载和请求均为 20 秒超时，返回地址仍须为 HTTP(S)，且把脚本返回的实际 `type` 原样交还 Dart。
- WebKit 使用非持久站点数据；CSP 与运行时替换同时禁止 `fetch`/XHR，导航只允许 `localhost.invalid` 空文档。脚本网络请求改由原生无 Cookie `URLSession` 发出，只允许 HTTPS、GET/POST、无重定向，并执行 64 KiB 请求体、1 MiB 流式响应上限。
- `ios/Runner/AppDelegate.swift` 已注册现有 `coral_music/user_api` channel。Dart、Android 和业务页面均未复制或分叉协议。`ios/Podfile.lock` 由首次可见 CocoaPods 的 `pod install` 补齐项目现有的 `audio_service`、`sqflite` iOS pods。
- 验证通过：`flutter build ios --no-codesign`，产物存在于 `build/ios/iphoneos/Runner.app`；`git diff --check` 通过。该构建只验证编译，不等价于 iPhone 运行时验收。
- 已知限制：iOS WebKit 无法同步回调原生 MD5；为避免伪造兼容性，当前 bridge 对同步 `lx.utils.crypto.md5` 明确报不支持。真实 LX 脚本是否走到此能力，须待 iPhone 导入用户指定地址后决定是否值得加入紧凑、可审计的 JS MD5 实现。

## 当前状态与下一步

- 状态保持 `DOING`：iOS Platform Runtime/真机尚未验收，鸿蒙仍无对应运行时。不能因此将 B4-12 或 P0-09 标记为三端完成。
- 恢复入口：在配置好 iPhone 后，从“我的 → 设置/音源管理”导入 `https://raw.githubusercontent.com/pdone/lx-music-source/main/lx/latest.js`，依次验证能力详情、酷我取链/播放、歌词和切换/移除后缓存失效。

## 2026-07-17 同步 MD5 兼容（DOING）

- Android bridge 已公开同步 `lx.utils.crypto.md5`，而 iOS `WKScriptMessageHandler` 是异步通信，不能直接同步回传原生哈希；保留“不支持”会导致要求请求签名的真实来源在 iOS 运行时失败。
- 将在受限 JavaScript bridge 内加入小型、确定性的 MD5 计算，只接受字符串并返回十六进制摘要；不调用网络、文件、Cookie 或额外原生 API。其正确性将在下一次 iOS 无签名构建与真机脚本导入中验证。

## 2026-07-17 同步 MD5 兼容（编译完成）

- 已在受限 bridge 内加入字符串 MD5；它使用 `TextEncoder`、固定 MD5 轮函数和 UTF-8 字节，不经 `WKScriptMessageHandler` 进入原生层，因此保留桌面/Android `lx.utils.crypto.md5()` 的同步返回语义。
- `randomBytes` 继续只使用 WebKit 的 `crypto.getRandomValues`，AES/RSA/zlib 仍明确拒绝，网络、导航、存储与 Cookie 限制不变。
- 统一 `flutter build ios --no-codesign` 已通过，仍需 iPhone 使用指定 LX URL 的真实签名请求来确认脚本侧兼容性；B4-27 保持 `DOING`。

## 2026-07-17 User API JSON 请求体兼容（DOING）

- 桌面 `lx.request` 协议允许 POST `body` 为对象；Android 当前 `JSONObject.optString` 会把对象降为空体，iOS 仅接受 `String`。这会让部分真实来源的签名 POST 失败，尽管其 URL/请求头正确。
- 将在两端受限网络桥内只增加 JSON 对象/数组到 UTF-8 body 的序列化；不开放 PUT/DELETE、HTTP、重定向、Cookie 或更大请求体。

## 2026-07-17 User API JSON 请求体兼容（实现完成）

- Android `JSONObject`/`JSONArray` body 现使用原 JSON 文本写入 POST；iOS 对 `String` 直接 UTF-8 写入，对可序列化对象/数组使用 `JSONSerialization`。其它 body 类型继续按空体处理，和原 bridge 的最小兼容策略一致。
- 两端均仍只在 POST 中写入非空 body，并在写入前执行既有 64 KiB 限制；请求方法、HTTPS-only、无 Cookie、无重定向、响应限制均未变化。
- 后续使用真实 LX 的非酷我来源 POST 取链集中验收；本轮先继续主任务开发，不拆分反复真机测试。

## 2026-07-17 URL 编码表单请求（DOING）

- 进一步对照桌面 `src/main/modules/userApi/renderer/preload.js`：其 `lx.request` 允许 `body`、`form` 与 `formData`。常规 `form` 由桌面 request 库按 URL 编码发送；移动端若忽略它仍会使部分来源取链失败。
- 将支持平面对象 `form` 的 `application/x-www-form-urlencoded`，并只在脚本未声明 Content-Type 时补默认头。复杂 `formData`/multipart 涉及二进制与文件面，保持受限运行时明确拒绝。

## 2026-07-17 URL 编码表单请求（实现完成）

- Android 与 iOS 都会优先发送非空 `body`；否则对平面 `form` 以稳定键顺序编码为 URL form，并仅在缺少脚本自定义 Content-Type 时设置 `application/x-www-form-urlencoded; charset=UTF-8`。
- 非空 body、form 均只允许 POST 且统一应用 64 KiB 上限。`formData` 明确返回受限运行时错误，避免把文件/二进制请求静默丢弃或意外放开。
- 现进入 Android/iOS 编译验证；真实 LX 的多来源 POST 取链留待后续统一真机回归。

## 2026-07-17 表单桥编译验证

- `flutter build apk --debug` 与 `flutter build ios --no-codesign` 完成，`build/app/outputs/flutter-apk/app-debug.apk`、`build/ios/iphoneos/Runner.app` 均存在；没有安装 APK，因此不影响当前 Android 真机的会话内音源。
- `git diff --check` 发现并已清除一处 Kotlin 行尾空白；未展开完整单元/真机矩阵，符合当前以主业务实现优先的节奏。
