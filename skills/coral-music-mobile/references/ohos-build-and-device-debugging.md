# 鸿蒙构建与真机调试流程（2026-07-24）

本文记录珊瑚音乐在 macOS 上使用 DevEco Studio 构建、签名、安装和调试 HarmonyOS HAP 的完整可复现流程。

当前结论：Debug HAP 可以稳定构建并覆盖安装到已连接设备；本地 FLAC 已手工播放成功。受限音源 WebView、取链和鸿蒙播放器已完成代码接入，在线点播仍需在解锁设备上完成最终人工回归，不能据此标记为全量真机验收完成。

## 1. 版本选择

- IDE：选择 **DevEco Studio 6.1.1 Release**，不使用 `2026 Beta 1` 作为当前项目的日常构建环境。
- 本机 SDK：`/Applications/DevEco-Studio.app/Contents/sdk`，本次构建使用 `default` OpenHarmony SDK（本机可见 API 24）。
- Flutter：使用项目 `ohos/local.properties` 中配置的 OpenHarmony Flutter 发行版；本次实际环境为 Flutter 3.27.5 OpenHarmony 分支、Dart 3.6.2。
- 真机：本次设备为 OpenHarmony 6.1 / API 23，已开启开发者选项和 USB/网络调试。

IDE/SDK 的 `6.1.1` 不是应用的 `targetSdkVersion`。当前项目产品配置保持：

```json5
"compatibleSdkVersion": "5.0.0(12)",
"targetSdkVersion": "5.0.0(12)"
```

它位于 `ohos/build-profile.json5`。不要为了匹配 IDE 版本把 target SDK 直接改成 `6.1.1`；升级 target 前必须先确认 Flutter OpenHarmony 分支及所有 ArkTS 插件兼容该 API。

## 2. 初始配置

1. 安装 DevEco Studio 6.1.1 Release，并在 SDK Manager 安装默认 OpenHarmony SDK、ohpm 和 hvigor。
2. 在 DevEco 配置调试签名。签名材料仅保留在本机，不写入文档、日志或 Git。
3. 确认 `ohos/local.properties` 指向本机 SDK 和 OpenHarmony Flutter：

```properties
hwsdk.dir=/Applications/DevEco-Studio.app/Contents/sdk
flutter.sdk=/absolute/path/to/flutter_flutter
```

4. 将鸿蒙手机接入 DevEco 的调试服务。当前会话的 HDC 服务地址为 `127.0.0.1:8710`；不同机器可使用自己的服务地址和设备序列号。

可通过 DevEco 的 Open File 打开 ArkTS 文件。macOS 命令行需要使用实际 App 路径，而不是不存在的 `DevEco Studio` App 名称：

```bash
open -a /Applications/DevEco-Studio.app \
  /absolute/path/to/file.ets
```

## 3. 依赖与 API 兼容修复

### 3.1 不直接修改 Pub 缓存

DevEco 6.1.1 的 ArkTS API 要求 `media.MediaSource` 实现 `enableOfflineCache`。上游 `just_audio_harmonyos 0.0.1` 缺少此方法时会报：

```text
Property 'enableOfflineCache' is missing in type 'MediaSource'
```

不要只改 `~/.pub-cache`，否则下一次 `flutter pub get` 或换机器会丢失修复。项目将插件固化到：

```text
third_party/just_audio_harmonyos/
```

并在 `pubspec.yaml` 使用 path 依赖：

```yaml
just_audio_harmonyos:
  path: third_party/just_audio_harmonyos
```

兼容方法位于 `third_party/just_audio_harmonyos/ohos/src/main/ets/MediaSource.ets`：

```ts
enableOfflineCache(enable: boolean): void {}
```

同样，鸿蒙安全存储使用工程内 `third_party/flutter_secure_storage_ohos`，避免依赖本机 Pub 缓存的临时改动。

### 3.2 鸿蒙平台桥接

本次新增/维护的鸿蒙桥接代码如下：

- `ohos/entry/src/main/ets/plugins/CoralFilePickerPlugin.ets`：音频、文档选择和系统文档保存。
- `ohos/entry/src/main/ets/plugins/OhosUserApiPlugin.ets`：受限 ArkWeb 音源脚本运行时及原生 HTTP 代理。
- `ohos/entry/src/main/ets/pages/Index.ets`：承载隐藏的用户音源 WebView。
- `third_party/just_audio_harmonyos/ohos/src/main/ets/MediaAvPlayer.ets`：鸿蒙系统播放器适配。

鸿蒙手机不提供 Android 式的任意目录长期授权，因此下载写入应用私有目录；完成后可用系统文档保存器导出。列表页仅显示鸿蒙支持的音频/文档选择入口，不伪造文件夹授权能力。

## 4. 构建步骤

在仓库根目录执行：

```bash
flutter pub get
flutter test test/user_api_runner_test.dart
flutter build hap --debug
```

在 Codex 或其他有 Flutter 锁的环境中，可显式设置：

```bash
FLUTTER_ALREADY_LOCKED=true flutter build hap --debug
```

成功后产物固定在：

```text
build/ohos/hap/entry-default-signed.hap
```

建议在构建前后执行：

```bash
git diff --check
```

本次已验证：

```text
flutter test test/user_api_runner_test.dart  # 3 passed
flutter build hap --debug                    # passed
git diff --check                             # passed
```

## 5. 连接设备、安装和启动

HDC 位于 DevEco SDK：

```text
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
```

使用以下命令模板。将 `<server>` 和 `<device-id>` 替换为实际值；本次会话分别为 `127.0.0.1:8710` 和已连接设备序列号。

```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc \
  -s <server> -t <device-id> install -r \
  build/ohos/hap/entry-default-signed.hap
```

`-r` 表示替换安装并保留应用数据。安装成功后启动：

```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc \
  -s <server> -t <device-id> shell aa start \
  -b com.coral.music.mobile -a EntryAbility
```

如果设备锁屏，启动会返回 `10106102`。开发者模式下 HDC 不能自动解锁，必须先在手机上人工解锁，再重新执行启动命令或手工点击应用图标。

## 6. 常见报错与处理

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `enableOfflineCache is missing` | 新 SDK 的 `MediaSource` 接口新增必需成员 | 使用工程内 `just_audio_harmonyos` 副本并补齐空实现；不要修改 Pub 缓存。 |
| `install already exist` | 设备已安装同 bundle | 使用 `hdc ... install -r <hap>` 覆盖安装。 |
| `bm install ... install file path invalid` | `bm install` 只能读取设备内路径，不能直接读取 Mac 上的 HAP | 直接使用 `hdc install -r <本地-hap>`；它会负责推送和安装。 |
| `ohpm ... SymLink Dir Failed ... EPERM` | 受限沙箱禁止向 Pub 缓存创建符号链接 | 在本机终端/获授权环境重跑同一条 `flutter build hap --debug`，不要删除依赖或重置工作区。 |
| `failed to start ability ... 10106102` | 手机锁屏且开发者模式禁止自动解锁 | 人工解锁手机后重新启动。 |
| `open -a "DevEco Studio"` 找不到应用 | macOS 应用显示名与实际包路径不一致 | 使用 `/Applications/DevEco-Studio.app` 的绝对路径。 |

## 7. 在线音源与播放加载链路

Android、iOS 和鸿蒙共享 Dart 侧的加载入口：

```text
PlayerController -> PlaybackResolver -> UserApiRunner
                 -> AudioEngine -> AudioSource.uri(url, headers)
```

Android/iOS 由各自标准 `just_audio` 系统播放器消费该 `AudioSource`。鸿蒙的区别只在最后一段，需要将相同 URL 和 headers 转换为 `media.createMediaSourceWithUrl`，再交给 `AVPlayer`。

本次鸿蒙播放器修复包括：

- 远端 URL（含 headers）统一走 `loadAssent -> loadUri -> setMediaSource`，删除旧的“带 headers 时绕过状态机”的加载分支。
- `.m3u8` 地址显式标记为 `APPLICATION_M3U8`，避免 HLS 被按普通短文件处理。
- 音量和倍速仅在 `prepared` 后实际下发；加载/重置期间先缓存，避免 `5400102`（播放器未准备好却设置音量）并消除每个时间回调重复设置倍速的问题。
- AVPlayer I/O 失败回传 Flutter 错误流，由现有 Dart 音质降级逻辑处理；插件不再自行重复加载当前曲目导致“加载中后自动跳下一首”。
- ArkWeb 异步取链和 HTTP 请求通过回调桥返回；原生侧与 Android/iOS 一样归一化 `{url}` 与 `{data: {url}}`，仅向 Dart 返回 `url` 和字符串 `type`。

运行时不记录音源完整 URL、请求头、Cookie、响应体或签名字段。

## 8. 真机回归清单

在解锁设备上执行以下顺序：

1. 覆盖安装最新 HAP，确认应用能启动且原有数据仍在。
2. 从“音源管理”导入 JS 文件，确认列表名称来自脚本声明而不是临时文件名。
3. 使用 URL 导入音源，确认受限 WebView 初始化完成且来源能力正常显示。
4. 搜索并播放同一首在线歌曲，确认不再长期停在“正在加载”、不自动跳下一首，进度和时长合理。
5. 依次切换音质、暂停/继续、上一首/下一首，确认不会再次出现 `5400102`。
6. 导入本地 FLAC，确认本地播放不受在线修复影响。
7. 下载音乐后确认文件位于应用目录，并验证“导出”能打开系统文档保存器。

只在需要定位原生播放器状态时读取已过滤日志：

```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc \
  -s <server> -t <device-id> shell pidof com.coral.music.mobile

/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc \
  -s <server> -t <device-id> shell hilog -x \
  -P <pid> -T JSAPP -L I,W,E
```

不要使用未过滤的全局日志，也不要将日志中的 URL、headers 或响应内容发到 issue、聊天或 Git。

## 9. 维护规则

- 任何鸿蒙插件修复先写入 `third_party/`，再通过 `pubspec.yaml` 的 path 依赖生效。
- Dart 共享层保持平台无关；仅 `ohos/` 和 `third_party/*_harmonyos/ohos/` 调用 ArkTS/系统 API。
- 在修改播放器前先对照 Android/iOS 的共享 Dart 调用契约，避免为鸿蒙增加第二套业务加载逻辑。
- 每次修改均至少执行对应 Dart 单测、`git diff --check` 和 `flutter build hap --debug`；涉及设备行为时，再执行覆盖安装和本节回归清单。
- 调试签名、证书、私钥、密码、设备序列号、音源 URL 和认证头均属于本机敏感信息，不提交、不写入本说明文档。
