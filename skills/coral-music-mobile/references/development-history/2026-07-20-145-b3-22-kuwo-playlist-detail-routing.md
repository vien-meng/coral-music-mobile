# B3-22 酷我歌单详情 ID 路由

- 阶段：Batch 3 / Phase 2
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20

## 根因

酷我歌单广场返回 `digest-<type>__<id>`。桌面端仅对 `digest-8` 直接请求 `nplserver`；`digest-5` 和默认类型先通过 `qukudata` 将节点 ID 解析为真实 `sourceid`。移动端此前统一截取 `__` 后的 ID 直接请求，导致列表可显示但部分歌单详情返回 `result != ok`，页面显示“歌单详情响应异常”。

## 验证要求

- `digest-8` 继续直接请求详情，不增加网络跳转。
- 其它 digest 先解析真实 PID，再请求详情。
- PID 解析失败返回可读错误，不发送空 PID 请求。
- 留下无网络单测证明两条 ID 路由。

## 实施与验证

- `KuwoPlaylistService.getPlaylistDetail()` 对 `digest-8` 直接请求 `nplserver`；其它 `digest-*` 先调用桌面端同款 `qukudata/q.k?cont=ninfo`，将节点 ID 解析为 `sourceid` 后再请求详情。
- 详情请求仍复用现有 `nplserver` 解析器和错误归一化，页面无需按来源增加分支。
- `test/kuwo_playlist_service_test.dart` 使用 Dio 拦截器覆盖 digest-5 两步路由和 digest-8 直达路由；`dart analyze` 与 `git diff --check` 通过。
- `flutter test test/kuwo_playlist_service_test.dart test/song_list_controller_test.dart` 因外部审批服务返回 HTTP 503 未启动；真实接口和真机点击回归待重新构建后执行，任务保持 `DOING`。
