# B6-14 本地资料备份与恢复预览

- 阶段：Batch 6 / Phase 6
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：2026-07-20

## 目标、范围与安全边界

提供仅本机文件的资料备份、内容预览和合并恢复。备份包含用户列表、歌曲收藏、在线歌单收藏和不感兴趣规则；恢复只追加/合并，不覆盖现有数据，并在单个 SQLite transaction 内完成。

不导出 WebDAV Authorization、User API 脚本、播放 URL、下载音频文件、网络代理或任何项目服务器数据。播放历史与下载任务本轮不恢复，避免把短期播放状态伪装成永久资料。

## 对照与依赖

- 桌面端 `backupService.ts` 使用 `allData_v2` 组合列表与设置；移动端没有桌面端的设置/服务器同步范围，采用显式移动端备份格式。
- 依赖 B5-17 的桌面曲目转换、B5-13 收藏快照、B6-13 不感兴趣规则和 `file_picker`。

## 实施记录

- 2026-07-20：开始实现纯 JSON 完整性校验、恢复预览、SQLite 原子合并与设置入口。
- 新增移动端 `coralMusicMobileBackup_v1` 文件格式：备份用户列表、歌曲收藏、在线歌单收藏和不感兴趣规则；不保存任何 URL 缓存、授权、动态脚本或下载文件。
- 新增“资料备份”设置页，支持用户选择路径导出、选择文件、8 MB 上限、恢复前统计预览和二次确认。
- 恢复在一个 SQLite transaction 内创建新列表并合并缺失的收藏/规则；任何数据库异常会回滚整个事务，现有资料不被覆盖。
- 实际修改：`library_backup_codec.dart`、`library_store.dart`、`library_controller.dart`、`library_backup_page.dart`、`settings_page.dart`、`app_router.dart`、`playlist_transfer_codec.dart`、`test/library_backup_codec_test.dart`。
- 验证：`dart format`、`flutter analyze`、`flutter test test/library_backup_codec_test.dart test/playlist_transfer_codec_test.dart test/playlist_duplicates_test.dart`、`git diff --check` 通过。

## 已知限制与下一步

- 恢复是安全合并，不是覆盖恢复；下载文件、历史位置和临时播放 URL 有时效性，因此不进入本轮资料备份。
- 文件选择/保存的 iOS、Android、鸿蒙系统行为仍须在发布阶段真机验收。
- 下一步：补齐真实可持久化的主题与语言设置，不提供无效开关。

## 2026-07-20 后续范围补充

- B6-15 已将不感兴趣关键词规则加入备份和合并恢复；格式保留 `coralMusicMobileBackup_v1`，新增字段对旧备份保持可选兼容。记录：`2026-07-20-109-b6-15-ignored-keyword-rules.md`。
