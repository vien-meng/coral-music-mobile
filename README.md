# 珊瑚音乐移动端

基于 Flutter 的珊瑚音乐移动客户端，一套业务代码同时覆盖 **iOS**、**Android** 和 **鸿蒙 (HarmonyOS)** 三个平台。

## 当前状态

> **版本 1.0.0** | 早期开发阶段 | 2026-07-15

项目已完成核心骨架搭建（路由、主题、状态管理、网络层、领域模型），**排行榜**与**歌曲搜索**两大功能已完整对接酷我音乐 API，播放队列状态管理已就绪。其余功能模块处于占位状态，按开发计划分阶段交付。

## 技术栈

| 类别        | 方案                               |
| ----------- | ---------------------------------- |
| 框架        | Flutter (3.27.5-ohos) / Dart 3.6.2 |
| 状态管理    | Riverpod (`flutter_riverpod`)      |
| 路由        | Go Router (`go_router`)            |
| HTTP 客户端 | Dio                                |
| UI 组件     | Material 3                         |
| 主题        | 珊瑚红种子色，跟随系统明暗模式     |

## 架构

```text
lib/
  app/                  # 启动、主题、路由、应用壳
  core/                 # 基础设施：HTTP 客户端、异常定义
  domain/               # 跨功能领域模型（Track、来源、音质等）
  features/
    leaderboard/        # 排行榜（data/state/view）
    search/             # 歌曲搜索（data/state/view）
    player/             # 播放队列与迷你播放栏（state/view）
  platform/             # MethodChannel 平台桥接能力
```

每个功能模块按 `data/`（数据层）、`state/`（状态管理）、`view/`（UI 层）分层。UI 不直接访问 Dio、SQLite 或 MethodChannel。

### 领域模型

- **Track**：统一歌曲实体，支持 `online`、`local`、`download`、`webdav` 四类来源
- **AudioQuality**：master → atmos_plus → atmos → hires → flac24bit → flac → 320k → 192k → 128k 逐级降级
- **PlaybackQueue**：播放队列，支持替换、切歌、context 跟踪
- **OnlineSource**：酷我、酷狗、QQ、网易云、咪咕 五类在线音乐源

### 产品入口

九个产品入口，与桌面端行为对齐：

| 入口　　 | 优先级 | 状态　　　　　　　　　　　　　　　　 |
| -------- | ------ | ------------------------------------ |
| 排行榜　 | P0　　 | 酷我 12 个榜单已对接，其余来源待迁移 |
| 搜索　　 | P0　　 | 酷我歌曲搜索、分页已完成　　　　　　 |
| 歌单广场 | P0　　 | 已完成　　　　　　　　　　　　　　　 |
| 我的列表 | P0　　 | 已完成　　　　　　　　　　　　　　　 |
| 我的收藏 | P1　　 | 已完成　　　　　　　　　　　　　　　 |
| 音乐分类 | P1　　 | 已完成　待优化　　　　　　　　　　　 |
| 下载　　 | P1　　 | 已完成　待优化　　　　　　　　　　　 |
| 网盘资源 | P1　　 | 已完成　待优化　　　　　　　　　　　 |
| 设置　　 | P1　　 | 已完成　待优化　　　　　　　　　　　 |

## 开发环境

### 前置要求

- Flutter 3.27.5+ (鸿蒙使用 OpenHarmony Flutter 发行版)
- Dart 3.6.2+
- Android：API 35、Build Tools、NDK 26.1
- iOS：Xcode 26.6+、CocoaPods 1.17.0+
- 鸿蒙：OpenHarmony API 18、Ohpm 5.1.3、Hvigor 5.18.6、DevEco Studio

### 快速开始

```bash
# 安装依赖
flutter pub get

# 代码格式化
dart format --output=none --set-exit-if-changed .

# 静态分析
flutter analyze

# 运行单测
flutter test

# 构建
flutter build hap --debug          # 鸿蒙
flutter build apk --debug          # Android
flutter build ios --debug --no-codesign  # iOS
```

## 开发工作流

1. 核对桌面端当前实现，确认为基线
2. 读取 [功能对等矩阵](skills/coral-music-mobile/references/feature-parity.md) 确认优先级与验收场景
3. 读取 [架构文档](skills/coral-music-mobile/references/architecture.md) 沿既定分层实现
4. 读取 [开发计划](skills/coral-music-mobile/references/development-plan.md) 领取任务并更新状态
5. 实现纵向可运行切片，先贯穿 UI、状态、数据再到平台能力
6. 每个非平凡行为至少包含一个可运行检查
7. 完成时回写任务历史和计划文档

完整开发文档位于 `skills/coral-music-mobile/` 目录。

## 不变量

- 九个产品入口行为与桌面端对等
- 默认进入排行榜；"播放全部"替换队列并播放当前页第一首
- 在线、本地、已下载、WebDAV 四种独立来源；本地和 WebDAV 不进入在线取链
- 保持 LX User API 协议兼容，动态脚本运行在受限沙箱
- 同目录本地歌词优先于在线歌词
- 账号密码、Token 和密钥只进入系统安全存储
- 共享 Dart 层不依赖平台 SDK，仅桥接层调用系统 API
- 三端同步验收

## 验证命令

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build hap --debug
flutter build apk --debug
flutter build ios --debug --no-codesign
```

## 项目依赖

核心依赖：

- `flutter_riverpod` - 响应式状态管理
- `go_router` - 声明式路由
- `dio` - HTTP 网络请求
- `crypto` - 加解密支持
- `pointycastle` - 加密算法库

开发依赖：

- `flutter_test` - 单元测试
- `flutter_lints` - 代码规范检查

## 版权声明

Copyright (c) 2025-present 珊瑚音乐 (Coral Music) 及其贡献者。保留所有权利。

本项目基于 [MIT License](LICENSE) 开源。

### 免责声明

- 本应用仅提供音乐播放与本地管理能力，**不内置任何版权音乐资源**，亦不提供资源分享、分发或下载链接服务。
- 在线音乐数据来自用户自行配置的第三方来源（如 User API），开发者不对用户使用该功能所访问的内容承担任何责任。
- 用户应遵守中华人民共和国相关法律法规及音乐内容版权方规定，**仅播放和下载已获得合法授权的音乐内容**。
- 本应用不得用于任何形式的商业盈利活动，包括但不限于付费分发、内置广告、捆绑推广等。
- 开发者保留随时更新本免责声明的权利，恕不另行通知。

### 第三方依赖

本项目使用以下开源项目，对应许可证详见各项目的源仓库：

| 依赖             | 许可证       | 用途           |
| ---------------- | ------------ | -------------- |
| Flutter          | BSD-3-Clause | 跨平台 UI 框架 |
| flutter_riverpod | MIT          | 状态管理       |
| go_router        | BSD-3-Clause | 路由管理       |
| Dio              | MIT          | HTTP 网络请求  |
| crypto           | BSD-3-Clause | 加解密支持     |
| pointycastle     | MIT          | 加密算法库     |

### 贡献许可

除非另有明确声明，任何有意提交以纳入本项目的贡献均默认以 MIT 许可证授权，不附加额外条款。
