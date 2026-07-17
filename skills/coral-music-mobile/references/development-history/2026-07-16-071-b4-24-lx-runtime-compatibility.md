# B4-24 LX 音源运行时兼容与真机闭环

- 阶段：Batch 4 / Phase 3
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：2026-07-16

## 目标与范围

用用户提供的公开 LX 脚本地址完成 Android 真机的“HTTPS 地址导入、初始化、取链、实际播放”闭环，并把移动端 WebView 桥接行为与桌面端 `src/main/modules/userApi/renderer/preload.js` 的必要协议对齐。

范围只包括受限 WebView 的初始化诊断与协议兼容；不持久化脚本、不内置该脚本、不放宽 HTTPS/请求/响应大小限制，也不把任何凭据写入日志或数据库。

依赖：B4-12 音源运行时管理、B4-20 HTTPS 地址导入、B4-22 后台媒体服务。

## 桌面基线与现状

- 桌面基线：`coral-music-desktop/src/main/modules/userApi/renderer/preload.js`。它公开 `lx/coral` 的 `EVENT_NAMES`、`on('request')`、`send('inited')`、`utils` 和 `currentScriptInfo`，并把脚本同步异常与未处理 Promise 拒绝返回初始化状态。
- 真机：Samsung SM-N986U / Android 13，Flutter Debug APK 已安装且会话已连接。
- 2026-07-16：在“导入音源”页输入用户提供的 `https://raw.githubusercontent.com/pdone/lx-music-source/main/lx/latest.js`，网络下载与 `UserApiRunner.load()` 已实际执行；界面在 20 秒后显示“音源脚本初始化超时”。未将脚本内容写入项目或应用默认配置。
- 同一公开地址响应为 UTF-8 文本、`content-length: 114852`，未触发 256 KiB 脚本上限。因此先定位运行时协议/脚本异常，而非扩大限制。

## 实施方案

1. 在受限 WebView 捕获同步脚本错误和未处理拒绝，并仅将截断后的错误状态返回导入页。
2. 补齐桌面基线所需的最小桥接字段；不实现未被真实脚本调用的能力。
3. 使用同一地址重新导入，成功后从真实在线歌曲进行取链、播放和 Android 媒体会话检查。

## 2026-07-16 真机诊断结果

- 新 Debug APK 已覆盖安装到同一 Samsung SM-N986U / Android 13。构建通过；Harmony Flutter 构建命令须显式补上 DevEco 的 Node/ohpm/hvigor `PATH` 和 `HOS_SDK_HOME`，否则工具会在 Android 构建前因找不到 `npm` 退出。
- 同一 URL 第二次实际导入不再只给出超时；界面精确返回 `Cannot read properties of undefined (reading 'crypto')`。这与桌面 `preload.js` 提供 `lx.utils.crypto` 的行为一致，确认协议缺口而非 URL、大小上限或网络下载失败。
- 下一步补齐 `utils` 的协议形状，并仅实现安全的 MD5/随机字节；AES、RSA、zlib 仍明确拒绝，待真实取链调用证明需要后再以受限原生实现补齐。

## 2026-07-16 导入成功与取链决策

- 补齐桥接后，同一 LX URL 在真机导入成功并自动启用；能力展示为 `kw、kg、tx、wy、mg、local` 取链及 `local` 歌词。说明初始化、协议注册与大小限制均已通过。
- 随后从首页点击真实在线曲目，脚本确实返回了播放结果，但移动端以“未返回安全的 HTTPS 播放地址”拒绝。桌面端基线对 `musicUrl` 接受 `http` 与 `https`，而移动端此前额外收紧为 HTTPS，导致与已导入的真实 LX 源不兼容。
- 按桌面行为将**播放结果**改为只接受有主机名、长度不超过 8192 的 `http/https`；脚本下载和脚本发起的受限请求仍仅允许 HTTPS，未放宽动态脚本的网络出口。新增 Dart 通道回归测试固定该兼容规则。

## 2026-07-16 播放服务阻断与恢复方案

- 真机点播日志表明，失败发生在 `AudioService.init`：`Unable to bind to AudioService`。根因是此前为消除空闲媒体会话将 Android service 默认设为 disabled；`AudioServiceActivity` 在 Flutter 插件附着期就连接该 service，后续首次播放才启用已无法重新建立连接。
- 为恢复真实播放，service 恢复为 manifest 默认启用，并在 `MainActivity.onCreate`、插件附着前强制恢复启用状态；按需开关只保留媒体按钮 receiver。这样会重新出现空闲媒体 service/session 的平台行为，属于 B4-22 的待收口项，不能用功能不可播放换取空闲会话指标。
- 同时把 User API 返回错误和“非字符串结果”准确回传到 UI，避免把脚本自身的取链错误误报为 URL 安全校验失败。下一轮真机点播以该精确错误继续判断是否需要补齐 AES/RSA/zlib。

## 2026-07-16 音源取链现状

- AudioService 生命周期修复后，真机可建立 `com.coral.music.mobile/media-session`，不再出现“无法绑定 AudioService”；说明播放器平台服务已可启动。
- 同一真实 LX 音源的首轮取链仍由脚本返回 `unknow error`（脚本原文错误文本），尚未产生可供播放器加载的地址。为区分受限 HTTP 桥接、上游状态和加密工具调用，下一轮只记录请求的协议、方法、HTTP 状态和异常类型，不记录 URL、响应体、脚本或任何潜在凭据。
- 脱敏日志显示首个取链请求为 HTTP 200、随后大量 HTTP 404，没有 HTTPS 拒绝记录。这说明请求可达但 LX 以错误的歌曲标识继续请求；移动端此前只传扁平字段，桌面端则把完整 `MusicInfo`（`id/name/singer/source/interval/meta.songId/...`）交给脚本。下一步按桌面对象结构补齐 `meta`，并用 MethodChannel 回归测试锁定字段映射。
- 完整 MusicInfo 映射后仍有 200/404 混合结果。继续逐行对照桌面预加载桥：桌面会把 JSON 响应解析后同时放入 `response.body` 与第三个回调参数，并将 `currentScriptInfo.rawScript` 暴露给脚本；移动端此前分别传原始字符串和空对象。现补齐这两个无权限扩张的协议差异，再进行下一轮相同真机验证。
- 继续对照桌面 `normalizeUserApiMusicUrlResult`：桌面允许音源返回字符串、`{url}` 或 `{data:{url}}`。移动端此前仅接受字符串，因此补齐这两种已经被桌面接受的返回形状；仍对最终地址执行主机名、长度和 `http/https` 校验。

## 2026-07-16 真机取链通过，播放清晰文本策略

- 最后一轮真机日志已不再出现 404：LX 取链请求均返回 200，Android media session 已显示真实歌曲元数据；说明音源导入、协议、取链与后台服务初始化均已越过。
- UI 仍显示“播放加载失败”。该失败在 `just_audio.setUrl` 之后而非音源解析阶段；LX 返回 HTTP（非 HTTPS）音频地址，Android 9+ 默认拒绝明文流量。
- 为保持桌面与该真实源的播放行为，Android application 开启 `usesCleartextTraffic`，仅作用于最终媒体地址；User API 脚本下载和脚本发起的受限请求仍维持 HTTPS 限制。发布前需要在安全/商店审查中评估商店版是否仅允许 HTTPS 签名源。

## 2026-07-16 Android 真机播放闭环通过

- 使用最新 Debug APK 在 Samsung SM-N986U / Android 13 重新导入同一 HTTPS LX 地址并点播真实在线曲目。`dumpsys media_session` 显示 `com.coral.music.mobile/media-session` 处于 `PLAYING`，元数据为《樱花草》/ Sweety /《花言乔语 (精装版)》；这不是调试样本地址。
- 连续两次读取的播放位置从 `98.451s` 到 `103.450s`（约 5 秒），说明真实音频已持续解码，而非仅成功取链或发布了伪媒体状态。随后发送 HOME 返回桌面，状态仍为 `PLAYING`，位置继续到 `105.851s`，后台播放通过本机回归。
- 通过系统 `KEYCODE_MEDIA_PLAY_PAUSE` 验证媒体按键：首次从播放变为 `PAUSED`（位置 `137.627s`），再次按键恢复为 `PLAYING`（位置 `140.229s`）。锁屏和耳机按键复用该 audio_service 路径，但仍需人工实体耳机/锁屏通知卡验收。
- 验证命令：`flutter build apk --debug`、`dart analyze lib test`、`adb install -r`、`adb shell dumpsys media_session`、`adb shell input keyevent 85`。构建与分析通过；真机为 Samsung SM-N986U / Android 13。

## 当前风险与恢复入口

- Android 原生桥接变更需要完整 Debug APK 安装，不能仅靠 Dart 热重载验证。
- 如果该脚本依赖桌面 Node 加密或压缩接口，必须根据真机报出的实际调用补齐受限等价能力，不能执行脚本于宿主 macOS。
- 后续记录真实 UI、logcat、`dumpsys media_session` 和播放结果；失败时保留精确错误文本（不记录脚本正文）。
- B4-24 的 Android 导入、取链、实际播放、后台持续与系统播放/暂停闭环均已通过。空闲会话策略、iOS/鸿蒙和实体耳机/锁屏验收由 B4-22 独立继续跟踪，不阻塞本专项结项。
