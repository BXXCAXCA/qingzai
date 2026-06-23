import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingzai/core/services/lan_transfer_service.dart';
import 'package:qingzai/core/services/socket_lan_transfer_service.dart';

void main() {
  group('LAN transfer end-to-end integration', () {
    final services = <SocketLanTransferService>[];
    Directory? tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qingzai_lan_e2e_');
    });

    tearDown(() async {
      for (final service in services) {
        await service.dispose();
      }
      services.clear();
      final dir = tempDir;
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    SocketLanTransferService buildService() {
      final service = SocketLanTransferService(
        bindAddress: InternetAddress.loopbackIPv4,
        allowInsecureTransfers: true,
      );
      services.add(service);
      return service;
    }

    test('sends a file from one local peer to another and preserves bytes', () async {
      final receiver = buildService();
      final sender = buildService();
      await receiver.startDiscovery(deviceName: 'Receiver');
      await sender.startDiscovery(deviceName: 'Sender');

      final file = File('${tempDir!.path}/payload.bin');
      final payload = List<int>.generate(4096, (index) => index % 251);
      await file.writeAsBytes(payload);

      final receivedFuture = receiver.receiveFiles().first;
      final target = LanDevice(
        id: 'receiver-device',
        name: 'Receiver',
        ipAddress: InternetAddress.loopbackIPv4.address,
        port: receiver.boundPort!,
        platform: 'test',
      );

      final progress = await sender
          .sendFile(targetDevice: target, filePath: file.path, secure: false)
          .toList()
          .timeout(const Duration(seconds: 5));
      final received = await receivedFuture.timeout(const Duration(seconds: 5));

      expect(progress.first.status, TransferStatus.pending);
      expect(progress.last.status, TransferStatus.completed);
      expect(progress.last.bytesTransferred, payload.length);
      expect(received.fileName, 'payload.bin');
      expect(received.fileSize, payload.length);
      expect(received.senderId, 'Sender');
      expect(received.data, payload);
    });
  });
}
