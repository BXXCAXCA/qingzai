import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../errors/app_exception.dart';
import 'lan_transfer_service.dart';

/// TCP based LAN transfer implementation.
///
/// This class implements the file-transfer part of LAN sharing with a compact
/// newline-delimited JSON header followed by raw file bytes. mDNS advertisement
/// is kept behind the [scanDevices] stream so a platform-specific discovery
/// implementation can feed discovered devices later without changing callers.
class SocketLanTransferService implements LanTransferService {
  SocketLanTransferService({
    InternetAddress? bindAddress,
    int port = 0,
    Duration connectTimeout = const Duration(seconds: 5),
    Uuid? uuid,
    bool allowInsecureTransfers = false,
    int chunkSize = 64 * 1024,
  })  : _bindAddress = bindAddress ?? InternetAddress.anyIPv4,
        _requestedPort = port,
        _connectTimeout = connectTimeout,
        _uuid = uuid ?? const Uuid(),
        _allowInsecureTransfers = allowInsecureTransfers,
        _chunkSize = chunkSize;

  static const _protocolVersion = 1;
  static const _lineFeed = 10;

  final InternetAddress _bindAddress;
  final int _requestedPort;
  final Duration _connectTimeout;
  final Uuid _uuid;
  final bool _allowInsecureTransfers;
  final int _chunkSize;

  final _devicesController = StreamController<LanDevice>.broadcast();
  final _receivedFilesController = StreamController<ReceivedFile>.broadcast();
  final _cancellations = <String, _TransferCancellation>{};

  ServerSocket? _server;
  StreamSubscription<Socket>? _serverSubscription;
  String? _deviceName;

  bool get isRunning => _server != null;

  int? get boundPort => _server?.port;

  @override
  Future<void> startDiscovery({required String deviceName}) async {
    final normalizedName = deviceName.trim();
    if (normalizedName.isEmpty) {
      throw const ValidationException('Device name must not be empty.');
    }

    if (isRunning) {
      _deviceName = normalizedName;
      return;
    }

    _deviceName = normalizedName;
    final server = await ServerSocket.bind(_bindAddress, _requestedPort);
    _server = server;
    _serverSubscription = server.listen(
      _handleIncomingSocket,
      onError: _receivedFilesController.addError,
    );
  }

  @override
  Future<void> stopDiscovery() async {
    await _serverSubscription?.cancel();
    _serverSubscription = null;
    await _server?.close();
    _server = null;
    _deviceName = null;
  }

  @override
  Stream<LanDevice> scanDevices() {
    if (!isRunning) {
      return Stream.error(
        const TransferException('LAN discovery has not been started.'),
      );
    }
    return _devicesController.stream;
  }

  /// Adds a discovered device to the scan stream.
  ///
  /// Platform-specific mDNS discovery can call this method after resolving
  /// service records. Tests also use it to avoid depending on a real network.
  void addDiscoveredDevice(LanDevice device) {
    _validateDevice(device);
    _devicesController.add(device);
  }

  @override
  Stream<TransferProgress> sendFile({
    required LanDevice targetDevice,
    required String filePath,
    bool secure = true,
  }) async* {
    final transferId = _uuid.v4();
    final cancellation = _TransferCancellation();
    _cancellations[transferId] = cancellation;

    yield TransferProgress(
      transferId: transferId,
      bytesTransferred: 0,
      totalBytes: 0,
      status: TransferStatus.pending,
    );

    Socket? socket;

    try {
      _validateDevice(targetDevice);

      if (secure && !_allowInsecureTransfers) {
        yield TransferProgress(
          transferId: transferId,
          bytesTransferred: 0,
          totalBytes: 0,
          status: TransferStatus.failed,
          errorMessage: 'Secure LAN transfer requires TLS configuration.',
        );
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        yield TransferProgress(
          transferId: transferId,
          bytesTransferred: 0,
          totalBytes: 0,
          status: TransferStatus.failed,
          errorMessage: 'File does not exist: $filePath',
        );
        return;
      }

      final bytes = await file.readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final totalBytes = bytes.length;
      final senderId = _deviceName ?? Platform.localHostname;

      final header = jsonEncode({
        'version': _protocolVersion,
        'transferId': transferId,
        'fileName': p.basename(file.path),
        'fileSize': totalBytes,
        'senderId': senderId,
        'checksum': checksum,
        'secure': secure,
      });

      socket = await Socket.connect(
        targetDevice.ipAddress,
        targetDevice.port,
        timeout: _connectTimeout,
      );

      socket.add(utf8.encode('$header\n'));
      await socket.flush();

      var sent = 0;
      while (sent < totalBytes) {
        if (cancellation.isCancelled) {
          yield TransferProgress(
            transferId: transferId,
            bytesTransferred: sent,
            totalBytes: totalBytes,
            status: TransferStatus.cancelled,
          );
          return;
        }

        final end = min(sent + _chunkSize, totalBytes);
        socket.add(bytes.sublist(sent, end));
        await socket.flush();
        sent = end;

        yield TransferProgress(
          transferId: transferId,
          bytesTransferred: sent,
          totalBytes: totalBytes,
          status: sent == totalBytes
              ? TransferStatus.completed
              : TransferStatus.inProgress,
        );
      }
    } catch (error) {
      yield TransferProgress(
        transferId: transferId,
        bytesTransferred: 0,
        totalBytes: 0,
        status: TransferStatus.failed,
        errorMessage: error.toString(),
      );
    } finally {
      _cancellations.remove(transferId);
      socket?.destroy();
    }
  }

  @override
  Stream<ReceivedFile> receiveFiles() {
    if (!isRunning) {
      return Stream.error(
        const TransferException('LAN transfer receiver has not been started.'),
      );
    }
    return _receivedFilesController.stream;
  }

  @override
  Future<void> cancelTransfer(String transferId) async {
    _cancellations[transferId]?.cancel();
  }

  Future<void> dispose() async {
    await stopDiscovery();
    await _devicesController.close();
    await _receivedFilesController.close();
  }

  void _validateDevice(LanDevice device) {
    if (device.id.trim().isEmpty) {
      throw const ValidationException('Target device id must not be empty.');
    }
    if (device.name.trim().isEmpty) {
      throw const ValidationException('Target device name must not be empty.');
    }
    if (device.ipAddress.trim().isEmpty) {
      throw const ValidationException('Target device IP address must not be empty.');
    }
    if (device.port <= 0 || device.port > 65535) {
      throw const ValidationException('Target device port must be between 1 and 65535.');
    }
  }

  Future<void> _handleIncomingSocket(Socket socket) async {
    try {
      final received = await _readReceivedFile(socket);
      _receivedFilesController.add(received);
    } catch (error, stackTrace) {
      _receivedFilesController.addError(error, stackTrace);
    } finally {
      socket.destroy();
    }
  }

  Future<ReceivedFile> _readReceivedFile(Socket socket) async {
    final headerBuffer = <int>[];
    final dataBuffer = BytesBuilder(copy: false);
    Map<String, Object?>? header;
    var expectedSize = 0;
    var receivedBytes = 0;

    await for (final chunk in socket) {
      if (header == null) {
        headerBuffer.addAll(chunk);
        final newlineIndex = headerBuffer.indexOf(_lineFeed);
        if (newlineIndex == -1) {
          continue;
        }

        final headerBytes = headerBuffer.sublist(0, newlineIndex);
        header = _parseHeader(headerBytes);
        expectedSize = header['fileSize']! as int;

        final remaining = headerBuffer.sublist(newlineIndex + 1);
        if (remaining.isNotEmpty) {
          final accepted = _appendBodyChunk(
            dataBuffer,
            remaining,
            expectedSize,
            receivedBytes,
          );
          receivedBytes += accepted;
        }
      } else {
        final accepted = _appendBodyChunk(
          dataBuffer,
          chunk,
          expectedSize,
          receivedBytes,
        );
        receivedBytes += accepted;
      }

      if (receivedBytes >= expectedSize) {
        break;
      }
    }

    if (header == null) {
      throw const TransferException('Incoming transfer did not include a header.');
    }
    if (receivedBytes != expectedSize) {
      throw TransferException(
        'Incoming transfer size mismatch: expected $expectedSize, got $receivedBytes.',
      );
    }

    final data = dataBuffer.toBytes();
    final expectedChecksum = header['checksum']! as String;
    final actualChecksum = sha256.convert(data).toString();
    if (actualChecksum != expectedChecksum) {
      throw const TransferException('Incoming transfer checksum mismatch.');
    }

    return ReceivedFile(
      fileName: header['fileName']! as String,
      fileSize: expectedSize,
      data: data,
      senderId: header['senderId']! as String,
      receivedAt: DateTime.now(),
    );
  }

  int _appendBodyChunk(
    BytesBuilder builder,
    List<int> chunk,
    int expectedSize,
    int currentSize,
  ) {
    final remaining = expectedSize - currentSize;
    if (remaining <= 0) {
      return 0;
    }

    final accepted = min(chunk.length, remaining);
    builder.add(chunk.sublist(0, accepted));
    return accepted;
  }

  Map<String, Object?> _parseHeader(List<int> headerBytes) {
    final decoded = jsonDecode(utf8.decode(headerBytes));
    if (decoded is! Map<String, Object?>) {
      throw const TransferException('Incoming transfer header is not an object.');
    }

    final version = decoded['version'];
    final fileName = decoded['fileName'];
    final fileSize = decoded['fileSize'];
    final senderId = decoded['senderId'];
    final checksum = decoded['checksum'];

    if (version != _protocolVersion) {
      throw TransferException('Unsupported LAN transfer protocol version: $version.');
    }
    if (fileName is! String || fileName.trim().isEmpty) {
      throw const TransferException('Incoming transfer header has an invalid file name.');
    }
    if (fileSize is! int || fileSize < 0) {
      throw const TransferException('Incoming transfer header has an invalid file size.');
    }
    if (senderId is! String || senderId.trim().isEmpty) {
      throw const TransferException('Incoming transfer header has an invalid sender id.');
    }
    if (checksum is! String || checksum.trim().isEmpty) {
      throw const TransferException('Incoming transfer header has an invalid checksum.');
    }

    return decoded;
  }
}

final class _TransferCancellation {
  var _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}
