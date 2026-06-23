# 集成测试指南

本指南对应实施计划任务 19：集成测试和端到端测试。

## 测试分层

轻载当前集成测试分为两层：

1. **服务级集成测试**：位于 `test/integration/`，可通过普通 Flutter 测试运行，不依赖真实 WebDAV、真实 LAN 或真实更新服务器。
2. **应用冒烟测试**：位于 `integration_test/`，用于在真机、模拟器或桌面目标上验证应用壳和主导航。

## 服务级集成测试

运行：

```bash
flutter test test/integration
```

当前覆盖：

- `full_sync_flow_integration_test.dart`
  - 模拟设备 A -> WebDAV -> 设备 B -> WebDAV -> 设备 A 的完整同步链路。
  - 验证 gzip 加密同步文件、ETag、Lamport clock 和最终一致性。
- `lan_transfer_end_to_end_test.dart`
  - 使用 loopback TCP 模拟两台局域网设备。
  - 验证文件发送、接收、进度和字节一致性。
- `update_flow_integration_test.dart`
  - 使用内存版更新服务模拟自托管更新。
  - 验证检查、下载、SHA-256 校验和校验失败删除文件。
- `platform_compatibility_contract_test.dart`
  - 验证 Android、iOS、Windows、HarmonyOS phone/tablet/watch 的平台映射和能力开关。

## 应用冒烟测试

运行：

```bash
flutter test integration_test
```

当前覆盖：

- `app_smoke_test.dart`
  - 启动 `QingZaiApp`。
  - 验证 Dashboard 和主导航入口可渲染。

## 真实环境待补测试

以下仍需要具备真实环境后补齐或手动验证：

- 真实 WebDAV 服务端：坚果云、Nextcloud、NAS WebDAV 等。
- 真实局域网设备发现：mDNS 广播、跨设备接收、文件大小边界。
- 自托管更新：HTTPS manifest、真实安装包、失败回滚。
- 平台构建：Android、iOS、Windows、HarmonyOS SDK。

## CI 建议

当前基础 CI 执行：

```bash
flutter pub get
flutter analyze
flutter test
```

由于 `test/integration/` 位于普通测试目录下，`flutter test` 会覆盖服务级集成测试。`integration_test/` 需要在具备目标平台运行环境时单独触发。
