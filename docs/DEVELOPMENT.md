# 开发指南

## 环境准备

推荐使用 Flutter 3.x 与 Dart 3.x。

```bash
flutter doctor
flutter pub get
```

如果平台工程目录尚未生成：

```bash
flutter create . --platforms=android,ios,windows
```

## 常用命令

```bash
flutter analyze
flutter test
flutter run
```

## 开发顺序

1. 数据模型层：TodoItem、ClipboardItem、NoteItem、PomodoroSession、MemoItem
2. 加密服务：EncryptedData、EncryptionService、AES-256-GCM 实现
3. 本地存储：StorageService 与 HiveStorageService
4. WebDAV 服务：WebDAVService 与同步元数据
5. 同步管理：SyncManager、冲突解决、tombstone
6. 业务 Provider：按 feature 接入 Riverpod
7. UI：用真实状态替换当前占位页

## 代码约定

- 每个 feature 尽量遵循 `domain / application / infrastructure / presentation` 分层
- 可同步实体实现 `SyncEntity`
- I/O、加密和同步逻辑不得阻塞 UI 线程
- 新功能应同时补充单元测试或 Widget 测试
