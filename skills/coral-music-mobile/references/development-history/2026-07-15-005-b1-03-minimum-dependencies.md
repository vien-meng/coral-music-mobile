# B1-03 接入最小依赖

- 阶段：Batch 1
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-15
- 完成时间：2026-07-15

## 目标与范围

加入 Riverpod、`go_router` 和 Dio，分别服务状态、路由和真实网络请求。依赖 B1-01；不加入 SQLite、代码生成或平台插件。

## 方案与平台差异

版本由当前 Flutter/Dart 兼容解析结果锁定到 `pubspec.lock`。共享 Dart 使用相同依赖，鸿蒙兼容性通过后续构建验证确认。

## 实际修改与验证

- `flutter_riverpod 2.6.1`、`go_router 14.8.1`、`dio 5.9.0` 已锁定。
- 酷我真实协议的直接调用方需要 AES/MD5，补充纯 Dart `pointycastle 3.9.1` 与 `crypto 3.0.7`。
- 未加入 SQLite、代码生成、音频或原生平台插件。
- `flutter pub get`、静态分析、测试和 Android Debug 构建通过。
- `flutter build hap --debug` 已完成共享代码编译并到达 DevEco 签名门槛；当前仍需配置调试签名，未标记鸿蒙平台验收完成。

## 风险、阻塞与后续

鸿蒙构建留到环境恢复后复验；所有新增依赖均为共享 Dart。关联 B1-05、B1-06、B2-02。
