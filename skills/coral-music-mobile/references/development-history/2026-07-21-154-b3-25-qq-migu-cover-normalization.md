# B3-25 QQ 与咪咕封面地址归一化

- 阶段：Batch 3 / Phase 2
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-21

## 根因与目标

QQ 歌曲列表将相册/歌手 MID 放在 CDN 尺寸片段之前，生成的 `y.gtimg.cn` 地址无效；QQ 歌单使用的 `qpic.y.qq.com` 缺少来源页请求头。咪咕搜索会返回相对图片路径，移动端只接受带主机的 URL，导致封面被丢弃。

修正现有解析器和统一图片请求头，不增加网络依赖或额外封面服务。

## 验证口径

- QQ 榜单和搜索按桌面端 `T002R500x500M000{albumMid}.jpg` 或 `T001R500x500M000{singerMid}.jpg` 生成封面。
- QQ 歌单 `qpic.y.qq.com` 请求携带 QQ Referer。
- 咪咕搜索相对 `img1`-`img3` 路径补全为 `d.musicapp.migu.cn` HTTPS 地址。

## 实施与验证

- QQ 榜单、搜索和歌单详情统一改为桌面端使用的 `T002R500x500M000{albumMid}.jpg` / `T001R500x500M000{singerMid}.jpg`，不再把 MID 插到尺寸片段前；QQ 歌单 CDN 的 `qpic.y.qq.com` 复用 QQ Referer。
- 咪咕搜索的 `img1`-`img3` 与 `imgItems` 保持优先顺序；相对路径补全为 `https://d.musicapp.migu.cn/...`。
- 已新增 QQ URL、QQ CDN Referer、咪咕相对路径的回归用例，并通过 `dart format`、定向 `dart analyze` 和 `git diff --check`。
- 2026-07-21 已在 SM-N986U 构建、安装并启动 Debug APK，无启动崩溃。设备屏幕和过滤日志读取的审批服务返回 HTTP 503，无法在本轮自动确认视觉加载结果；任务保持 `DOING`，等待手动进入 QQ 榜单/歌单及 QQ/咪咕搜索页确认。
