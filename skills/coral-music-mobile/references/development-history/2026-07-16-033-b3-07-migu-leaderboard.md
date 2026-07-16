# B3-07 迁移咪咕排行榜

- 阶段：Batch 3 / Phase 2
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标、范围、不做内容与依赖

将桌面端咪咕固定榜单目录和 HTTPS 榜单详情迁移到现有排行榜入口，规范化为共享 `Track`。

依赖 B1-05、B2-03、B2-04。不实现咪咕搜索、歌单、评论、歌词或播放取链；User API 是否支持 `mg` 由现有受限音源能力决定。

## 桌面端基线与确认行为

对照 `coral-music-desktop/src/renderer-react/services/musicSdk/sdk/mg/leaderboard.js` 和 `musicInfo.js`。桌面端固定榜单元数据，请求 `querycontentbyId.do` 并从 `columnInfo.contents[].objectInfo` 提取歌曲及 PQ/HQ/SQ/ZQ 质量。

## 实施方案、关键接口、数据与平台差异

- 添加一个 `MiguCatalogService` 实现现有 `OnlineCatalogService`，复用 MultiSource 分派、Dio 和错误映射；不改接口。
- 使用 HTTPS、桌面端同一榜单 ID；质量、歌手、封面和时长在服务边界归一化。
- 仅将已实际接入的咪咕项加入排行榜来源选择器。

## 验收、风险与恢复入口

- 收口时补桌面响应 fixture 解析契约和 Android HTTPS 真机验证；单一来源失败必须不影响酷我/QQ。
- 恢复入口为 `lib/features/leaderboard/data/migu_catalog_service.dart`。

关联 P2-02、P2-05 和排行榜功能矩阵。

## 当日实施进度

- 已新增 `MiguCatalogService`，迁移固定榜单、HTTPS 详情请求及 PQ/HQ/SQ/ZQ 质量映射，并接入现有多来源服务和排行榜来源选择器。
- 待批次收口时以桌面响应 fixture 和 Android HTTPS 真机完成契约验证；未接入的咪咕能力仍明确报不支持。
