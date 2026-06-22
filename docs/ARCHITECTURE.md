# 架构说明

轻载采用分层架构，当前仓库先建立源码骨架，后续按实施计划逐层填充。

## 分层

```text
lib/
  app/                 应用入口、导航壳、全局配置
  core/                跨功能基础能力，例如主题、平台服务、同步契约
  features/            按业务功能拆分的页面、状态和领域逻辑
  shared/              共享组件和工具
```

## 目标架构

- 表现层：Material Design 3 UI 和跨平台适配
- 业务逻辑层：Riverpod Provider
- 服务层：本地存储、WebDAV、加密、局域网传输、更新服务
- 数据层：Hive、本地文件、WebDAV 远端目录、局域网设备

## 同步原则

- 所有可同步实体必须包含 `id`、`deviceId`、`lamportClock`、`isDeleted`、`lastModified`
- 删除使用 tombstone，不做纯本地硬删除
- 冲突解决遵循 delete-wins，然后比较逻辑时钟，最后使用 deviceId 稳定 tie-breaker

## 平台策略

- Android / iOS / Windows 平台工程通过 Flutter 官方工具生成
- 鸿蒙平台需先验证 Flutter-HarmonyOS SDK，再补齐平台工程和权限
- iOS 和商店托管 Android 使用商店跳转更新
- Windows 和企业自托管渠道可实现应用内补丁更新
