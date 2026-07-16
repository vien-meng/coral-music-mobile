# B5-01 三端 SQLite 可行性与列表 Schema v1

- 阶段：Batch 5 / Phase 0、1、4
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标与范围

验证 iOS、Android、OpenHarmony 共用 SQLite 依赖，建立可显式升级的 v1 schema，作为“我的列表”、收藏和历史的持久化基础。本任务先实现列表数据边界与迁移；不实现安全凭据、文件导入、备份恢复或本地媒体扫描。

## 桌面端对照

- `coral-music-desktop/src/main/worker/dbService/db.ts`：数据库打开、迁移和校验流程。
- `coral-music-desktop/src/main/worker/dbService/modules/list/statements.ts`：`my_list` 记录 id、名称、来源、来源列表 id、位置和位置更新时间。
- 确认行为：自建列表与收藏列表共用列表实体，展示顺序持久化；用户凭据不属于此表。

## 实施方案与平台差异

- 使用 OpenHarmony-SIG 适配的 `flutter_sqflite`，将 git 提交固定在锁文件中，避免随远端更新改变三端构建结果。
- 首版仅保存不含凭据的用户列表和曲目引用；曲目字段以现有 `Track` 稳定 id 作为去重键，schema 版本由 `PRAGMA user_version` 管理。
- Android/iOS 使用该依赖的原生 SQLite 后端；OpenHarmony 使用适配器注册的 ArkTS 插件。数据库文件路径和原生桥仅在数据层处理，UI 不直接访问 SQLite。

## 依赖、验收与恢复入口

- 依赖：现有 `Track` 领域模型；OpenHarmony SDK 和插件构建链。
- 本轮验证：`flutter pub get`、静态分析、Android/HAP Debug 构建。卸载重装和三端真机持久化另行补录。
- 恢复入口：`pubspec.yaml`、`lib/features/library/` 与本文件。

## 当日实施进度

- 已确认通用 `sqflite 2.4.1` 仅声明 Android/iOS/macOS；当前 Dart 3.6.2 可满足其 SDK 下限，但不能直接覆盖 OpenHarmony。
- 已确认 OpenHarmony-SIG 的适配清单列出 `sqflite 2.2.8+4` 与 `flutter_sqflite`；下一步固定仓库提交并以项目的 Flutter OHOS 工具链验证。
- 已将依赖固定为 `flutter_sqflite` 的 `0bd638a416215b9ab74f21eef98e14797827df04` 提交；解析得到 `sqflite 2.2.8+3` 与同提交的 `sqflite_common`。
- 已建立 `user_playlist` schema v1：`id`、名称、位置、创建/更新时间；不保存账号、Token 或其他凭据。
- `flutter build hap --debug` 已生成 2026-07-16 的 unsigned HAP，生成注册器包含 `SqflitePlugin`；`flutter build apk --debug` 已生成 Android Debug APK。iOS 编译与三端真机数据库读写仍待环境具备后补录。
