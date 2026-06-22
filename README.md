# 轻载 Qing Zai

轻载是一个基于 Flutter 的跨平台生产力应用骨架，目标支持 Android、iOS、Windows、鸿蒙手机、鸿蒙平板和鸿蒙手表。

## 当前状态

本仓库已初始化 Flutter 工程化源码骨架，包含：

- Material Design 3 应用入口
- Riverpod 依赖接入
- 首页与核心功能占位页面
- 基础主题与深色模式
- 分层目录结构
- 核心异常类型
- 可同步模型基础接口与 tombstone 占位
- Todo / Clipboard / Note / Pomodoro / Memo 核心数据模型
- Storage / WebDAV / Encryption / LAN Transfer / Platform / Version 服务接口
- AES-256-GCM 加密服务实现（PBKDF2-HMAC-SHA256 派生密钥、随机 IV、认证标签校验、SHA-256 哈希）
- SyncResult、SyncManager 接口与确定性冲突解析器
- Riverpod 服务注入入口
- Flutter CI 工作流
- 基础 Widget 测试、模型序列化测试与加密服务测试

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
    errors/            # 统一异常类型
    models/            # 通用模型接口、校验工具、tombstone
    providers/         # 全局 Riverpod Provider
    services/          # 服务接口与基础实现
    sync/              # 同步结果与冲突解析
    theme/             # Material 3 主题
  features/
    clipboard/models/  # 剪切板数据模型
    memos/models/      # 备忘录数据模型
    notes/models/      # 笔记数据模型
    pomodoro/models/   # 番茄钟会话模型
    todos/models/      # 待办事项模型
test/
  core/services/       # 核心服务测试
  features/models/     # 数据模型测试
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
