# Next Chat Recovery Prompt

Copy the following prompt into a new ChatGPT conversation when continuing Qing Zai development.

```text
你将继续开发 GitHub 仓库 BXXCAXCA/qingzai。

请先阅读并理解以下文件：

- README.md
- docs/context/README.md
- docs/context/project-context.md
- docs/context/source-docs-summary.md
- docs/context/conversation-log.md
- docs/preview-builds.md
- docs/final-verification-report.md
- docs/release-blockers.md

当前已知状态：

- PR #7 已合并，源码通过 flutter analyze 和 flutter test。
- PR #8 已合并，Build Preview Artifacts 已能产出 Android debug APK、Linux preview bundle、Windows preview bundle。
- 当前项目级别是内部开发预览，不是生产发布就绪。
- 真实设备冒烟、真实 WebDAV、真实 LAN、iOS、HarmonyOS、真实更新包验证仍需要继续做。

继续工作时请优先：

1. 检查 GitHub Actions 最新 main 构建产物。
2. 下载 Android APK、Windows zip、Linux tar.gz 进行真实运行验证。
3. 修复安装/运行时问题。
4. 更新 release blocker issues 和 docs/context/conversation-log.md。
5. 不要声称生产可发布，除非真实设备和真实服务验证完成。
```

## Minimal English recovery prompt

```text
Continue work on BXXCAXCA/qingzai. First read docs/context/README.md, docs/context/project-context.md, docs/context/source-docs-summary.md, docs/context/conversation-log.md, and docs/context/next-chat-prompt.md. The repo is at internal preview status: analyze/test passed, preview artifacts were produced for Android/Linux/Windows, but real device, WebDAV, LAN, iOS, HarmonyOS, and update package validation still remain.
```
