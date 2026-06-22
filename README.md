# 轻载 Qing Zai

轻载是一个基于 Flutter 的跨平台生产力应用骨架，目标支持 Android、iOS、Windows、鸿蒙手机、鸿蒙平板和鸿蒙手表。

## 当前状态

本仓库已初始化 Flutter 源码骨架，包含：

- Material Design 3 应用入口
- Riverpod 依赖接入
- 首页与核心功能占位页面
- 基础主题与深色模式
- 分层目录结构
- Flutter CI 工作流
- 基础 Widget 测试

## 计划模块

- 待办事项
- 剪切板同步
- 桌面笔记
- 番茄钟
- 备忘录
- WebDAV 加密同步
- 局域网文件传输
- 分平台更新

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
