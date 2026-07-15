# B3-03 酷狗排行榜可行性验证

- 阶段：Batch 3
- 状态：BLOCKED
- 负责人：Codex
- 开始时间：2026-07-15
- 完成时间：2026-07-15

## 目标、范围与依赖

验证桌面酷狗排行榜是否能在 iOS、Android、鸿蒙共享网络层安全迁移。依赖 B1-05、B2-02；不为单一来源增加明文网络例外、证书绕过或代理服务。

## 桌面端基线与已确认行为

对照 `src/renderer-react/services/musicSdk/sdk/kg/leaderboard.js`：固定榜单目录，歌曲列表请求为 `http://mobilecdnbj.kugou.com/api/v3/rank/song`，每页 100 首；以 `data.info` 归一歌曲、音质 hash 和时长。

## 验证、决策与阻塞原因

- HTTP 原始端点返回 `200` 和预期 `data.info` 响应。
- 同主机 HTTPS 请求因证书主机名不匹配失败，无法建立受信任连接。
- 移动端不配置 iOS ATS 例外、不关闭 Android/鸿蒙证书校验，也不引入未授权中转服务；这些做法会破坏三端安全边界与公开商店前提。

因此本任务未修改业务代码。恢复入口：找到可验证的、具备正确 TLS 证书且行为等价的酷狗官方端点后，建立 fixture、解析器和实时冒烟，再实现来源切换。

## 验证命令与结果

- `curl http://mobilecdnbj.kugou.com/api/v3/rank/song?...`：200，返回榜单 JSON。
- `curl https://mobilecdnbj.kugou.com/api/v3/rank/song?...`：失败，证书 subject 与主机名不匹配。
- 真机：不适用，未进入实现或安装阶段。

## 关联

关联 `P0-05`、`P2-02`、`P2-05`、后续酷狗来源任务；本记录不代表来源能力完成。
