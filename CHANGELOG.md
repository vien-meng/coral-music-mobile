# Changelog

All notable changes to 珊瑚音乐移动端 (Coral Music Mobile) will be documented in this file.

## [0.1.0] - 2026-07-15

### 项目初始化

- 创建 iOS、Android、鸿蒙三端 Flutter 工程
- 统一包名 `com.coral.music.mobile`
- 建立 Material 3 珊瑚主题（种子色 `#ff6f61`），跟随系统明暗模式
- 配置代码格式检查、静态分析与单元测试流程
- 确立开发历史与文档制度

### 工程基础设施

- 搭建 Go Router 九入口路由与 Shell 路由架构
- 实现底部主导航栏（手机）与侧边 NavigationRail（宽屏 >=720px）
- 实现更多页面入口与占位页面体系
- 建立 Riverpod 状态管理框架
- 引入 `flutter_riverpod`、`go_router`、`dio`、`crypto`、`pointycastle` 核心依赖

### 领域模型

- 定义 `OnlineSource` 枚举：酷我、酷狗、QQ、网易云、咪咕
- 定义 `TrackSourceKind` 枚举：`online`、`local`、`download`、`webdav`
- 定义 `AudioQuality` 音质降级链路：master → atmos_plus → atmos → hires → flac24bit → flac → 320k → 192k → 128k
- 实现 `Track` 不可变歌曲实体（含 id、来源、标题、歌手、专辑、时长、封面等字段）
- 实现 `PageResult<T>` 通用分页结果类型
- 实现 `LeaderboardBoard` 榜单定义类型

### 网络层

- 建立 Dio HTTP 客户端工厂，配置移动端 User-Agent 与 15s 超时
- 实现 `mapDioException` 异常映射：cancelled / timeout / noNetwork / badResponse / invalidData / unknown
- 实现 `AppFailure` 异常类，含稳定 code、用户文案与脱敏诊断信息

### 酷我音乐 API 集成

- 实现 AES-ECB + PKCS7 请求加密与响应解密
- 实现 MD5 签名查询字符串构建

### 排行榜

- 对接酷我音乐 12 个榜单：飙升榜、新歌榜、热歌榜、抖音热歌榜、热评榜、ACG新歌榜、经典怀旧榜、华语榜、粤语榜、欧美榜、韩语榜、日语榜
- 实现榜单目录展示、榜单详情分页查询
- 实现音乐源下拉选择（当前仅酷我）
- 实现横向滑动 ChoiceChip 榜单选择器
- 实现歌曲列表展示（封面、标题、歌手、时长）
- 实现上/下翻页与下拉刷新
- 实现"播放全部"替换队列及单曲点击播放
- 使用 requestId 机制防止异步请求竞态

### 歌曲搜索

- 对接酷我音乐歌曲搜索 API
- 实现搜索结果列表与分页展示
- 实现搜索输入框与搜索按钮
- 使用 requestId 机制防止搜索请求乱序

### 播放队列

- 实现 `PlaybackQueueState` 不可变队列状态
- 实现 `PlaybackQueueController` 队列管理
- 支持 `replaceQueue`（替换队列）与 `select`（切歌）
- 支持 contextId 追踪队列来源

### 迷你播放栏

- 实现底部常驻迷你播放栏（位于内容区与导航栏之间）
- 显示当前歌曲信息或"未在播放"占位状态
- 播放按钮仅 UI 占位，音频引擎将在播放器阶段接入

### 受限 / 阻塞项

- **酷狗排行榜可行性验证 (BLOCKED)**：酷狗 HTTP 端点正常，但同主机 HTTPS 请求因证书主机名不匹配失败；保持三端安全边界，等待具备正确 TLS 证书的官方端点后再恢复
- **三端真机验证 (BLOCKED)**：Flutter doctor 仅发现 macOS 与 Chrome，未发现三端真机，平台能力不得在真机验证前标记完成
- **鸿蒙调试签名 (待配置)**：已可构建 unsigned HAP，需 DevEco 配置调试签名后安装到真机
- **iOS Platform Runtime (待安装)**：Xcode/CocoaPods 已完成，缺少 iOS 26.5 Platform Runtime
