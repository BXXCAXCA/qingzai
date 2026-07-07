# Qing Zai 项目上下文

最后更新：2026-07-07

## 项目定位

Qing Zai（轻载）是一个基于 Flutter 的跨平台生产力应用，目标覆盖 Android、iOS、Windows、HarmonyOS 手机、HarmonyOS 平板和 HarmonyOS 手表。

产品定位是“轻量、离线优先、多端同步、安全加密”的个人生产力工具，核心模块包括：

- 待办事项
- 剪切板同步
- 桌面笔记
- 番茄钟
- 备忘录
- WebDAV 端到端加密同步
- 局域网文件传输
- 分平台更新能力

## 技术栈

- Flutter 3.x / Dart 3.x
- Material Design 3
- Riverpod 状态管理
- Hive 本地存储
- Dio WebDAV 客户端实现
- AES-256-GCM 加密，PBKDF2-HMAC-SHA256 派生密钥
- WebDAV 离线同步与冲突解决
- TCP Socket LAN 文件传输
- GitHub Actions CI 与预览构建产物

## 当前主分支状态

主分支已经完成 MVP 骨架和核心服务实现，并经过 CI 验证。

已确认：

- `flutter analyze` 在 PR 验证中通过。
- `flutter test` 在 PR 验证中通过。
- 服务级集成测试随 `flutter test` 执行通过。
- Build Preview Artifacts 已在 PR #8 中成功产出 Android debug APK、Linux preview bundle、Windows preview bundle。
- PR #7 已合并，修复 analyze/test 阻塞问题。
- PR #8 已合并，修复 Android/Linux/Windows 预览构建问题。

重要提交：

- `ff88f1d5e689d6f0ccb0cd77bef6511cc097aaaa`：让 MVP 通过 analyze/test 验证。
- `0d5dc44c61111d66dbe4033961c6b49977d950f6`：合入预览构建 workflow 与三端构建修复。

## 已完成的核心能力

### 应用骨架

- Material 3 应用入口。
- 自适应导航壳。
- 首页、待办、剪切板、笔记、备忘录、番茄钟、LAN 传输、设置页。
- Riverpod 服务注入入口。

### 数据模型

- TodoItem
- ClipboardItem
- NoteItem
- PomodoroSession
- MemoItem
- SyncableModel、Lamport clock、tombstone 删除标记、deviceId。

### 本地存储

- HiveStorageService。
- 按需打开 box。
- 批量保存、分页读取、按 ID 批量读取。
- syncable 变更索引。
- 测试环境显式目录初始化，避免依赖 `path_provider`。

### 加密

- AES-256-GCM。
- PBKDF2-HMAC-SHA256。
- 随机 IV。
- 认证标签校验。
- SHA-256 哈希。
- 主密码强度策略。

### WebDAV

- HTTPS URL 校验。
- Basic Auth。
- PROPFIND / PUT / GET / HEAD / DELETE / MKCOL。
- ETag 和元数据解析。
- 路径穿越防护。
- 同源 href 过滤。
- 上传改为 raw bytes，避免 Dio 将字节编码成字符串。

### 同步

- SyncManager。
- 本地变更识别。
- gzip 压缩后加密上传。
- ETag 比较。
- 受限并发下载/上传。
- 确定性冲突解决。
- 同步元数据记录。

### 离线支持

- 纯 Dart IO 网络连通性监控。
- 离线同步队列。
- 指数退避重试。
- 恢复在线后队列重放。
- 存储空间健康检查。

### LAN 传输

- TCP 文件发送/接收。
- loopback 测试。
- 进度流。
- 取消标记。
- SHA-256 校验。
- UI 支持手动 IP/端口发送。

### 更新服务

- Manifest 检查。
- 商店跳转策略。
- 自托管下载进度。
- SHA-256 校验。
- 补丁最短路径计算。
- SecureVersionService 校验 HTTPS 和 checksum。

### 平台服务

- Android/iOS/Windows/HarmonyOS phone/tablet/watch 映射。
- 设备 ID 安全持久化接口。
- 平台能力开关。

### CI 与构建

- Flutter CI：`pub get`、`analyze`、`test`。
- 设备级 `integration_test` 在没有支持设备的 GitHub runner 上会记录 warning 并跳过；真实设备测试仍需人工/设备 runner 执行。
- Build Preview Artifacts：Android debug APK、Linux tar.gz、Windows zip。
- 构建失败日志 artifact：Android/Linux/Windows build log。

## 仍未完成或不能声称完成的事项

以下事项仍然需要真实设备或真实服务验证：

- Android debug APK 安装与核心页面冒烟。
- Windows zip 解压运行冒烟。
- Linux tar.gz 解压运行冒烟。
- iOS 平台工程与真机/模拟器构建。
- HarmonyOS Flutter SDK 可行性与平台工程。
- 真实 WebDAV 服务上的端到端加密同步。
- 真实局域网多设备发现与传输。
- 真实 HTTPS update manifest 与更新包完整性验证。
- 证书固定、平台安全存储/生物识别解锁仍属于后续增强，不应误称生产级完成。

## 当前发布建议

当前可以作为“内部开发预览”使用。可以下载预览构建产物进行本地试装和冒烟测试。

不建议直接生产发布，除非 release blocker issue 全部完成并通过真实设备验证。
