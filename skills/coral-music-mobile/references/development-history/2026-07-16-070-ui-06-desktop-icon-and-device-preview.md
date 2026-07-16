# UI-06 桌面图标迁移与 Android 真机视觉预览

- 阶段：高保真 UI 重构 / 第六任务
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标、范围与依赖

将桌面端珊瑚音乐的实际应用图标迁移到移动端 iOS、Android、鸿蒙图标资源，并在已连接 Android 真机安装 Debug 包预览当前 UI。依赖桌面项目中可复用的原始图标与现有三端工程壳。

不做：重绘图标、替换桌面图标版权信息、创建商店最终图标/启动页素材、修改业务代码或播放器行为。

## 实施方案

- 先定位桌面端最高分辨率源图及其许可/构建使用位置；优先从源 PNG/ICNS 而不是截图或已缩放产物生成 Android/iOS/鸿蒙尺寸。
- 保持 Android 自适应图标前景/背景语义；若桌面仅提供单张不透明图标，则使用现有 Android launcher 位图槽位，不伪造透明前景。
- 安装到 SM-N986U / Android 13 后验证桌面图标显示、默认推荐首页、底栏、迷你播放器和播放详情入口；不把音频播放验收混入本 UI 任务。

## 验收与恢复入口

- 执行差异检查、技能校验、可用 Flutter SDK 的 Android Debug 构建与 `adb install -r`。
- 若 HOS SDK 环境仍未配置，不阻塞 Android 预览；iOS/鸿蒙图标编译留待对应工具链可用时验证。

## 实际修改与验证

- 已使用桌面端 `coral-music-desktop/resources/icons/icon.png`（1024×1024）生成并覆盖 Android `mipmap-* / ic_launcher.png`、iOS `AppIcon.appiconset` 的全部声明尺寸，以及鸿蒙 `AppScope`/`entry` 的两个 114×114 图标。
- 主图一致性已验证：桌面 `icon.png` 与 iOS 1024 图标 SHA-256 相同；Android 五档尺寸为 48/72/96/144/192，鸿蒙两处均为 114×114。图标内容已人工查看，为深紫圆角背景和淡紫色音符。
- 真机预览未完成：本会话中未找到标准 Flutter SDK 或 `adb`；项目现有 Harmony Flutter 的 `flutter build apk --debug` 在构建前因 `HOS_SDK_HOME` 未配置退出。没有安装旧 APK，也没有把旧截图作为本次 UI/图标验证。
- 精确恢复入口：配置 `HOS_SDK_HOME` 后以可用 Flutter SDK 执行 `flutter build apk --debug`，再使用实际 Android platform-tools 的 `adb install -r build/app/outputs/flutter-apk/app-debug.apk`。任务保持 `DOING`。

## 2026-07-16 重试

- 用户要求重新执行真机调试。本次先重新探测会话环境中的 Flutter、adb、`HOS_SDK_HOME` 与 Android SDK，再决定构建工具链；不沿用上一轮失败的路径假设。
- 探测结果：当前 `PATH` 不包含 Flutter 或 Android platform-tools；`HOS_SDK_HOME`、`ANDROID_HOME`、`ANDROID_SDK_ROOT` 均未设置；在用户目录的常见/深层路径检索不到可执行 `adb` 或标准 `bin/flutter`。因此不存在可连接设备或可生成新 APK 的工具，重试未能进入安装阶段。
- 阻塞保持不变：需要在当前会话可见的 Android SDK platform-tools 和标准 Flutter SDK，或提供其绝对路径；若继续使用当前 Harmony Flutter，还需要有效的 `HOS_SDK_HOME`。任务仍为 `DOING`。
