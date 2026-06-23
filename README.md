# 轻载 Qing Zai

轻载是一个基于 Flutter 的跨平台生产力应用骨架，目标支持 Android、iOS、Windows、鸿蒙手机、鸿蒙平板和鸿蒙手表。

## 当前状态

本仓库已初始化 Flutter 工程化源码骨架，包含：

- Material Design 3 应用入口
- Riverpod 依赖接入
- 首页与核心功能页面
- 基础主题与深色模式
- 分层目录结构
- 核心异常类型与用户友好错误文案
- 可同步模型基础接口与 tombstone 占位
- Todo / Clipboard / Note / Pomodoro / Memo 核心数据模型
- Storage / WebDAV / Encryption / LAN Transfer / Platform / Version 服务接口
- Hive 本地存储实现（按需打开盒子、分页读取、按 ID 批量读取、Lamport clock 变更索引、批量保存、变化监听）
- AES-256-GCM 加密服务实现（PBKDF2-HMAC-SHA256 派生密钥、主密码强度策略、随机 IV、认证标签校验、SHA-256 哈希）
- Dio WebDAV 服务实现（HTTPS 校验、Basic Auth、相对路径约束、同源 href 过滤、PROPFIND、PUT、GET、HEAD、DELETE、MKCOL、ETag/元数据解析）
- SyncManager 核心流程实现（本地变更识别、gzip 压缩加密上传、远程 ETag 比较、受限并发下载/上传、下载解密合并、确定性冲突解析、同步元数据记录）
- 离线支持骨架（网络状态监听、离线同步队列、指数退避重试、恢复在线后队列重放、存储空间健康检查）
- Socket LAN 传输服务实现（本机接收端口、设备扫描流、TCP 文件发送/接收、进度流、取消标记、SHA-256 校验）
- Dio Version 更新服务实现（manifest 检查、商店跳转策略、自托管下载进度、SHA-256 校验、补丁最短路径计算）
- 安全加固工具（敏感信息脱敏、强主密码策略、SecureVersionService HTTPS/校验和包装器、设置页错误脱敏）
- Default Platform 服务实现（平台检测、设备 ID 安全持久化、设备名、平台能力开关、鸿蒙 phone/tablet/watch 映射）
- Todo / Clipboard / Notes / Pomodoro / Memo 业务 Provider 实现（Riverpod StateNotifier、CRUD、状态排序、tombstone 删除）
- Todo / Clipboard / Notes / Memo / Pomodoro / LAN Transfer / Settings 表现层 UI 雏形（列表、表单、状态操作、设置入口）
- 性能基准工具（样本记录、P95 计算、阈值判定、设备/系统/网络条件元数据）
- Riverpod 服务注入入口
- Flutter CI 工作流
- 基础 Widget 测试、模型序列化测试、加密服务测试、Hive 存储服务测试、WebDAV 服务测试、同步管理器测试、LAN 传输服务测试、更新服务测试、业务 Provider 测试、离线支持测试、平台服务测试、性能指标测试与安全加固测试

## 计划模块

- 待办事项
- 剪切板同步
- 桌面笔记
- 番茄钟
- 备忘录
- WebDAV 加密同步
- 局域网文件传输
- 分平台更新

## 目录结构

```text
lib/
  app/                 # 应用入口、导航壳
  core/
    errors/            # 统一异常类型与错误文案
    models/            # 通用模型接口、校验工具、tombstone
    offline/           # 离线队列、网络状态、重试、存储空间健康
    performance/       # P95 性能基准与结果记录工具
    providers/         # 全局 Riverpod Provider
    security/          # 主密码策略与敏感信息脱敏
    services/          # 服务接口与基础实现
    sync/              # 同步结果、同步管理器与冲突解析
    theme/             # Material 3 主题
  features/
    clipboard/models/      # 剪切板数据模型
    clipboard/providers/   # 剪切板业务状态
    clipboard/presentation/# 剪切板 UI
    memos/models/          # 备忘录数据模型
    memos/providers/       # 备忘录业务状态
    memos/presentation/    # 备忘录 UI
    notes/models/          # 笔记数据模型
    notes/providers/       # 笔记业务状态
    notes/presentation/    # 笔记 UI
    pomodoro/models/       # 番茄钟会话模型
    pomodoro/providers/    # 番茄钟业务状态
    pomodoro/presentation/ # 番茄钟 UI
    todos/models/          # 待办事项模型
    todos/providers/       # 待办事项业务状态
    todos/presentation/    # 待办事项 UI
test/
  core/offline/        # 离线支持测试
  core/performance/    # 性能指标测试
  core/security/       # 安全加固测试
  core/services/       # 核心服务测试
  core/sync/           # 同步管理器测试
  features/models/     # 数据模型测试
  features/providers/  # 业务 Provider 测试
```

## 本地开发

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

如果本地缺少平台工程目录，可先执行：

```bash
flutter create . --platforms=android,ios,windows
```

鸿蒙平台需要在立项阶段完成 Flutter-HarmonyOS SDK 可用性验证后再补齐平台工程。
