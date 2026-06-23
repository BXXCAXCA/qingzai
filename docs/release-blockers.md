# 发布前阻塞 Issue 索引

更新时间：2026-06-23

以下 Issue 用于跟踪正式发布前必须完成的人工验证和真实环境验证工作。

## 阻塞项

- #1 Release blocker: run CI and confirm analyze/test/integration_test pass
- #2 Release blocker: generate platform projects and run device smoke tests
- #3 Release blocker: validate real WebDAV encrypted sync
- #4 Release blocker: validate LAN discovery and transfer on real devices
- #5 Release blocker: validate HTTPS update manifest and package integrity
- #6 Release blocker: validate HarmonyOS SDK and platform behavior

## 当前建议

在以上 Issue 全部关闭前，项目状态保持为：内部开发预览，不建议作为生产版本发布。
