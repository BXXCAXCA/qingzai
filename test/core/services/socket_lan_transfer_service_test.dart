import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingzai/core/errors/app_exception.dart';
import 'package:qingzai/core/services/lan_transfer_service.dart';
import 'package:qingzai/core/services/socket_lan_transfer_service.dart';

void main() {
  group('SocketLanTransferService', () {
    late List<SocketLanTransferService> services;
    late Directory tempDir;

    setUp(() async {
      services = <SocketLanTransferService>[];
      tempDir = await Directory.systemTemp.createTemp('qingzai_lan_test_');
    });

    tearDown(() async {
      for (final service in services) {
        await service.dispose();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    SocketLanTransferService buildService({bool allowInsecureTransfers = true}) {
      final service = SocketLanTransferService(
        bindAddress: InternetAddress.loopbackIPv4,
        allowInsecureTransfers: allowInsecureTransfers,
      );
      services.add(service);
      return service;
    }

    test('startDiscovery rejects empty device names', () async {
      final service = buildService();

      await expectLater(
        service.startDiscovery(deviceName: '   '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('startDiscovery opens a local receiver port and stopDiscovery closes it', () async {
      final service = buildService();

      await service.startDiscovery(deviceName: 'Receiver');

      expect(service.isRunning, isTrue);
      expect(service.boundPort, greaterThan(0));

      await service.stopDiscovery();

      expect(service.isRunning, isFalse);
      expect(service.boundPort, isNull);
    });

    test('scanDevices emits discovered devices', () async {
      final service = buildService();
      await service.startDiscovery(deviceName: 'Scanner');

      final discovered = service.scanDevices().first;
      service.addDiscoveredDevice(
        const LanDevice(
          id: 'device-1',
          name: 'Laptop',
          ipAddress: '127.0.0.1',
          port: 9123,
          platform: 'test',
        ),
      );

      final device = await discovered.timeout(const Duration(seconds: 2));

      expect(device.id, 'device-1');
      expect(device.name, 'Laptop');
      expect(device.ipAddress, '127.0.0.1');
      expect(device.port, 9123);
    });

    test('scanDevices reports an error before discovery starts', () async {
      final service = buildService();

      await expectLater(
        service.scanDevices().first,
        throwsA(isA<TransferException>()),
      );
    });

    test('sendFile transfers bytes to a running receiver over loopback', () async {
      final receiver = buildService();
      final sender = buildService();
      await receiver.startDiscovery(deviceName: 'Receiver');
      await sender.startDiscovery(deviceName: 'Sender');

      final file = File('${tempDir.path}/document.txt');
      await file.writeAsString('hello from qingzai');

      final receivedFuture = receiver.receiveFiles().first;
      final target = LanDevice(
        id: 'receiver-id',
        name: 'Receiver',
        ipAddress: InternetAddress.loopbackIPv4.address,
        port: receiver.boundPort!,
        platform: 'test',
      );

      final progressEvents = await sender
          .sendFile(targetDevice: target, filePath: file.path, secure: false)
          .toList()
          .timeout(const Duration(seconds: 5));
      final received = await receivedFuture.timeout(const Duration(seconds: 5));

      expect(progressEvents.first.status, TransferStatus.pending);
      expect(progressEvents.last.status, TransferStatus.completed);
      expect(progressEvents.last.progress, 1);
      expect(received.fileName, 'document.txt');
      expect(received.fileSize, 'hello from qingzai'.codeUnits.length);
      expect(String.fromCharCodes(received.data), 'hello from qingzai');
      expect(received.senderId, 'Sender');
    });

    test('sendFile returns failed progress for missing files', () async {
      final sender = buildService();
      await sender.startDiscovery(deviceName: 'Sender');

      final events = await sender
          .sendFile(
            targetDevice: const LanDevice(
              id: 'receiver-id',
              name: 'Receiver',
              ipAddress: '127.0.0.1',
              port: 9,
              platform: 'test',
            ),
            filePath: '${tempDir.path}/missing.txt',
            secure: false,
          )
          .toList();

      expect(events.last.status, TransferStatus.failed);
      expect(events.last.errorMessage, contains('File does not exist'));
    });

    test('sendFile refuses secure transfer when TLS is not configured', () async {
      final sender = buildService(allowInsecureTransfers: false);
      await sender.startDiscovery(deviceName: 'Sender');

      final file = File('${tempDir.path}/document.txt');
      await file.writeAsString('secure please');

      final events = await sender
          .sendFile(
            targetDevice: const LanDevice(
              id: 'receiver-id',
              name: 'Receiver',
              ipAddress: '127.0.0.1',
              port: 9000,
              platform: 'test',
            ),
            filePath: file.path,
          )
          .toList();

      expect(events.last.status, TransferStatus.failed);
      expect(events.last.errorMessage, contains('TLS configuration'));
    });

    test('receiveFiles reports an error before receiver starts', () async {
      final service = buildService();

      await expectLater(
        service.receiveFiles().first,
        throwsA(isA<TransferException>()),
      );
    });

    test('cancelTransfer is idempotent for unknown transfer ids', () async {
      final service = buildService();

      await expectLater(service.cancelTransfer('missing'), completes);
    });
  });
}
