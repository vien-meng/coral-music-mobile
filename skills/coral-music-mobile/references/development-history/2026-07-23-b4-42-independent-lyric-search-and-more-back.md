# B4-42 独立歌词检索优先级与“更多”返回

状态：DONE

## 目标

- 在线歌词先由独立 LrcLib 按歌名、歌手（可用时加专辑与时长）检索；平台歌词端点只在独立服务未命中时兜底。
- 音乐分类、歌单广场、网盘资源的系统返回回到“更多”，而非退出应用。

## 已确认

- 现有移动端虽然不调用 User API，但先按 `sourceId` 调用 QQ/酷我/网易云/咪咕/酷狗歌词端点，LrcLib 仅是失败兜底；这与“独立检索优先”的目标不符。
- 落雪移动端会用歌名、歌手、专辑、时长跨来源寻找候选；本项目已有 LrcLib 的同等独立检索与候选排序，无需新建服务。
- 三个“更多”子页未使用既有 `AppBackScope`，因而事件落到壳路由并触发根页面返回规则。

## 验证

- `flutter analyze`：通过，无诊断。
- `flutter test test/independent_lyric_service_test.dart test/lrclib_lyric_service_test.dart test/app_shell_back_test.dart`：8 项通过；新增断言确保独立服务命中时不会访问平台歌词端点。
