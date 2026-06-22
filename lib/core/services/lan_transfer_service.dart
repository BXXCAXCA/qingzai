abstract interface class LanTransferService {
  Future<void> startDiscovery({required String deviceName});

  Future<void> stopDiscovery();

  Stream<LanDevice> scanDevices();

  Stream<TransferProgress> sendFile({
    required LanDevice targetDevice,
    required String filePath,
    bool secure = true,
  });

  Stream<ReceivedFile> receiveFiles();

  Future<void> cancelTransfer(String transferId);
}

class LanDevice {
  const LanDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.platform,
  });

  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final String platform;
}

class TransferProgress {
  const TransferProgress({
    required this.transferId,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.status,
    this.errorMessage,
  });

  final String transferId;
  final int bytesTransferred;
  final int totalBytes;
  final TransferStatus status;
  final String? errorMessage;

  double get progress => totalBytes <= 0 ? 0 : bytesTransferred / totalBytes;
}

enum TransferStatus { pending, inProgress, completed, failed, cancelled }

class ReceivedFile {
  const ReceivedFile({
    required this.fileName,
    required this.fileSize,
    required this.data,
    required this.senderId,
    required this.receivedAt,
  });

  final String fileName;
  final int fileSize;
  final List<int> data;
  final String senderId;
  final DateTime receivedAt;
}
