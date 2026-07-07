# Qing Zai 项目上下文索引

本目录用于在切换 ChatGPT 对话、交接给其他开发者或重新恢复项目时快速恢复上下文。

建议新对话开始时先让模型阅读以下文件：

1. [`project-context.md`](project-context.md)：项目目标、技术方案、当前状态、已完成能力和剩余风险。
2. [`source-docs-summary.md`](source-docs-summary.md)：原始需求文档、设计文档、任务计划的浓缩版。
3. [`conversation-log.md`](conversation-log.md)：本轮对话中的开发过程、任务推进、CI/构建修复记录。
4. [`next-chat-prompt.md`](next-chat-prompt.md)：可直接复制到新对话的恢复提示词。

## 当前推荐恢复流程

在新对话中发送：

```text
请先阅读仓库中的 docs/context/README.md、docs/context/project-context.md、docs/context/source-docs-summary.md、docs/context/conversation-log.md、docs/context/next-chat-prompt.md，然后继续开发 Qing Zai。
```

如果需要继续编码，优先从以下事项开始：

- 下载并试装 Build Preview Artifacts 生成的 Android debug APK、Windows zip、Linux tar.gz。
- 在真实 Android/Windows/Linux 设备上执行冒烟测试。
- 验证真实 WebDAV 加密同步。
- 验证真实局域网设备发现与文件传输。
- 准备 iOS/HarmonyOS 平台工程和设备验证。
