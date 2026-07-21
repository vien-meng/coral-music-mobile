# v1.0.0 — 珊瑚音乐移动端首个正式版本

珊瑚音乐移动端首个正式版本发布。基于 Flutter 一套代码同时覆盖 **Android**、**iOS** 和 **鸿蒙 (HarmonyOS)** 三个平台，与桌面端行为对齐。

---

## 亮点

### 五源在线音乐检索

- **排行榜**：酷我、QQ、咪咕、网易云四源榜单已对接（酷狗因 TLS 证书问题暂阻塞），每日推荐按日期稳定选择榜单
- **搜索**：酷我、QQ、网易云、咪咕、酷狗五源搜索 + 综合搜索（五源并行）+ 搜索历史 + 热搜词
- **歌单广场**：酷我、咪咕歌单广场，支持标签筛选、排序、关键词搜索、滚动无限加载

### 完整播放器

- 音频引擎（`just_audio` / `just_audio_harmonyos`）+ 受限 User API 取链闭环
- 三种播放模式：列表循环、单曲循环、随机
- 歌词系统：本地 LRC 优先 → 内置来源歌词服务 → LRCLIB 独立搜索 → 会话缓存
- 支持 LRC 翻译、罗马音、LX 逐字歌词、`[offset]` 偏移、自动滚动
- 播放进度保存与恢复（每 15 秒/暂停/seek 自动保存）
- 0.5–2.0 倍速控制、音质选择与降级、音频文件信息探测（MP3/FLAC/DSD）
- 后台播放与系统媒体服务（`audio_service`），锁屏/耳机媒体键控制
- 播放队列持久化、拖动排序、去重追加、非当前项删除

### 本地媒体库（SQLite 持久化）

- **我的列表**：创建/重命名/删除/拖动排序、批量选择/删除/复制/移动/置顶、列表内搜索与来源筛选、导入导出（兼容桌面端 `playListPart_v2`）、重复检测
- **我的收藏**：歌曲收藏、歌单收藏快照、专辑收藏快照
- **音乐分类**：播放历史、艺术家、专辑、类型、年份五分类
- **本地音频导入**：文件/目录递归扫描、MP3/FLAC/M4A/Ogg/Opus/WAV/DSF/DFF 等格式元数据读取、CUE 单文件分轨播放
- **不感兴趣规则**：曲目 ID + 关键词双重过滤

### 下载管理

- 在线歌曲下载队列（Dio + Range 续传 + 原子写入）
- 歌单下载全部（快照固定、去重、单曲失败不停止）
- 下载音质展示与升级、文件系统导出
- 重启后未完成任务安全转为"已暂停"

### WebDAV 远程媒体

- PROPFIND 目录浏览、本地关键词筛选、面包屑导航
- 多账号管理、凭据安全存储
- WebDAV 下载复用、加入我的列表

### 音源管理

- 支持 LX User API 协议的 HTTPS URL 导入与脚本粘贴
- 音源详情卡（名称/版本/作者/能力标签）
- 首次启动默认加载落雪音源，无需手动配置
- 启动自动恢复已保存音源，会话内切换/移除

### 其他

- 深链 `coralmusic://` 三端注册与路由归一化
- Android 系统分享音频导入
- 主题模式持久化（system/light/dark）
- 定时停止（15/30/45/60 分钟 + 当前曲结束）
- 本机缓存管理
- 本地资料备份与恢复
- 默认播放音质设置
- GitHub Actions CI（格式/分析/测试/构建）

---

## 下载

| 平台 | 文件 | 说明 |
|------|------|------|
| Android | `coral-music-mobile-v1.0.0.apk` | Debug 签名，可直接安装 |
| iOS | 源码自行编译 | 需 Xcode 26.6+、CocoaPods 1.17.0+ |
| 鸿蒙 | 源码自行编译 | 需 OpenHarmony API 18、DevEco Studio |

> Android 最低系统版本：Android 7.0 (API 24)
> 已验证设备：Samsung SM-N986U / Android 13

---

## 技术栈

| 类别 | 方案 |
|------|------|
| 框架 | Flutter 3.27.5-ohos / Dart 3.6.2 |
| 状态管理 | Riverpod |
| 路由 | Go Router |
| HTTP | Dio |
| 音频引擎 | just_audio / just_audio_harmonyos |
| 后台播放 | audio_service 0.18.19 |
| 持久化 | flutter_sqflite（三端共用 SQLite） |
| 安全存储 | flutter_secure_storage |
| DSD 解码 | ffmpeg_kit_flutter_new_full 2.4.1（LGPL 3.0） |
| UI | Material 3 + TDesign 视觉规范 |

---

## 已知限制

- **酷狗排行榜**：HTTP 端点正常，但 HTTPS 证书主机名不匹配，暂不可用
- **iOS 真机**：编译通过，待 Platform Runtime 安装后真机验收
- **鸿蒙真机**：已生成 unsigned HAP，待 DevEco 调试签名后安装验证
- **DSD 秒播**：当前 DSF/DFF 需等待整首临时 PCM WAV 生成，流式秒播需后续原生 Media3 DataSource
- **Release APK**：当前使用 Debug 签名，正式商店发布签名待配置

---

## 安全声明

- 本应用**不内置任何版权音乐资源**，不提供资源分享、分发或下载链接服务
- 在线音乐数据来自用户自行配置的第三方 User API 来源，开发者不对用户使用该功能所访问的内容承担任何责任
- User API 脚本运行在受限 WebView 沙箱中，仅允许 HTTPS 网络请求，不持久化脚本内容，不访问文件系统/剪贴板/本地存储
- 账号密码、Token 和密钥只进入系统安全存储
- 用户应遵守相关法律法规及音乐内容版权方规定，仅播放和下载已获得合法授权的音乐内容

---

## 许可证

本项目基于 [MIT License](LICENSE) 开源。

DSD 解码使用 `ffmpeg_kit_flutter_new_full 2.4.1`（LGPL 3.0），发布版需核验 LGPL 分发声明。

---

## 致谢

- [珊瑚音乐桌面端](https://github.com/libsgh/coral-music) — 桌面端基线参考
- [落雪音乐音源](https://github.com/pdone/lx-music-source) — 默认 User API 来源
- [LRCLIB](https://lrclib.net) — 独立歌词搜索服务
- Flutter、Riverpod、just_audio、audio_service、sqflite 等开源项目
