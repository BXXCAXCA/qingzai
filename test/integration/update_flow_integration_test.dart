import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzai/core/services/secure_version_service.dart';
import 'package:qingzai/core/services/version_service.dart';

void main() {
  group('update flow integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qingzai_update_flow_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('checks, downloads, and verifies a self-hosted update package', () async {
      final bytes = utf8.encode('qingzai update package');
      final checksum = crypto.sha256.convert(bytes).toString();
      final delegate = _MemoryVersionService(
        downloadDirectory: tempDir,
        packageBytes: bytes,
        sha256Value: checksum,
      );
      final service = SecureVersionService(delegate);

      final info = await service.check(
        const VersionContext(
          currentVersion: '0.1.0',
          platform: 'windows',
          channel: 'stable',
        ),
      );

      expect(info, isNotNull);
      expect(info!.strategy, UpdateStrategy.selfHostedFullPackage);
      expect(info.source, startsWith('https://updates.example.com/'));

      final progress = await service.load(info).toList();

      expect(progress.first.status, VersionProgressStatus.pending);
      expect(progress.last.status, VersionProgressStatus.completed);
      expect(progress.last.localPath, isNotNull);
      expect(await File(progress.last.localPath!).readAsBytes(), bytes);
      expect(await service.verifyLocalFile(progress.last.localPath!, checksum), isTrue);
    });

    test('deletes the package and fails when checksum verification fails', () async {
      final bytes = utf8.encode('tampered package');
      final wrongChecksum = ''.padLeft(64, '0');
      final delegate = _MemoryVersionService(
        downloadDirectory: tempDir,
        packageBytes: bytes,
        sha256Value: wrongChecksum,
      );
      final service = SecureVersionService(delegate);

      final info = await service.check(
        const VersionContext(
          currentVersion: '0.1.0',
          platform: 'windows',
          channel: 'stable',
        ),
      );
      final progress = await service.load(info!).toList();

      expect(progress.last.status, VersionProgressStatus.failed);
      expect(progress.last.localPath, isNotNull);
      expect(await File(progress.last.localPath!).exists(), isFalse);
    });
  });
}

class _MemoryVersionService implements VersionService {
  _MemoryVersionService({
    required this.downloadDirectory,
    required this.packageBytes,
    required this.sha256Value,
  });

  final Directory downloadDirectory;
  final List<int> packageBytes;
  final String sha256Value;

  @override
  Future<VersionInfo?> check(VersionContext context) async {
    return VersionInfo(
      version: '0.2.0',
      notes: 'Integration update',
      size: packageBytes.length,
      source: 'https://updates.example.com/qingzai-0.2.0.zip',
      sha256: sha256Value,
      releaseDate: DateTime.utc(2026, 1, 1),
      strategy: UpdateStrategy.selfHostedFullPackage,
      channel: context.channel,
      platform: context.platform,
    );
  }

  @override
  Stream<VersionProgress> load(VersionInfo info) async* {
    final file = File('${downloadDirectory.path}/qingzai-${info.version}.zip');
    yield VersionProgress(
      done: 0,
      total: packageBytes.length,
      localPath: file.path,
      status: VersionProgressStatus.pending,
    );
    await file.writeAsBytes(packageBytes);
    yield VersionProgress(
      done: packageBytes.length,
      total: packageBytes.length,
      localPath: file.path,
      status: VersionProgressStatus.completed,
    );
  }

  @override
  Future<bool> verifyLocalFile(String localPath, String expectedSha256) async {
    final file = File(localPath);
    if (!await file.exists()) {
      return false;
    }
    return crypto.sha256.convert(await file.readAsBytes()).toString() == expectedSha256;
  }

  @override
  Future<UpdateManifest> fetchManifest(Uri manifestUri) async {
    return UpdateManifest(
      version: '0.2.0',
      releaseNotes: 'Integration update',
      releaseDate: DateTime.utc(2026, 1, 1),
      packages: {
        'windows:stable': UpdatePackage(
          platform: 'windows',
          channel: 'stable',
          downloadUrl: 'https://updates.example.com/qingzai-0.2.0.zip',
          sha256: sha256Value,
          size: packageBytes.length,
        ),
      },
    );
  }

  @override
  UpdateStrategy selectUpdateStrategy(VersionContext context, UpdatePackage package) {
    return UpdateStrategy.selfHostedFullPackage;
  }

  @override
  List<PatchInfo> calculateUpdatePath({
    required String currentVersion,
    required String targetVersion,
    required UpdateManifest manifest,
  }) {
    return const [];
  }
}
