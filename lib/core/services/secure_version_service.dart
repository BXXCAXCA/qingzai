import 'dart:io';

import '../errors/app_exception.dart';
import 'version_service.dart';

class SecureVersionService implements VersionService {
  const SecureVersionService(this._delegate);

  final VersionService _delegate;

  @override
  Future<VersionInfo?> check(VersionContext context) async {
    final info = await _delegate.check(context);
    if (info == null) {
      return null;
    }
    _validateInfo(info);
    return info;
  }

  @override
  Stream<VersionProgress> load(VersionInfo info) async* {
    _validateInfo(info);

    await for (final progress in _delegate.load(info)) {
      if (progress.status != VersionProgressStatus.completed) {
        yield progress;
        continue;
      }

      final localPath = progress.localPath;
      if (localPath == null ||
          !await _delegate.verifyLocalFile(localPath, info.sha256)) {
        if (localPath != null) {
          final file = File(localPath);
          if (await file.exists()) {
            await file.delete();
          }
        }
        yield VersionProgress(
          done: progress.done,
          total: progress.total,
          speedBytesPerSecond: progress.speedBytesPerSecond,
          localPath: localPath,
          status: VersionProgressStatus.failed,
        );
        continue;
      }

      yield progress;
    }
  }

  @override
  Future<bool> verifyLocalFile(String localPath, String sha256) async {
    _validateSha256(sha256);
    return _delegate.verifyLocalFile(localPath, sha256);
  }

  @override
  Future<UpdateManifest> fetchManifest(Uri manifestUri) {
    _validateHttpsUri(manifestUri, 'Update manifest URI');
    return _delegate.fetchManifest(manifestUri);
  }

  @override
  UpdateStrategy selectUpdateStrategy(VersionContext context, UpdatePackage package) {
    return _delegate.selectUpdateStrategy(context, package);
  }

  @override
  List<PatchInfo> calculateUpdatePath({
    required String currentVersion,
    required String targetVersion,
    required UpdateManifest manifest,
  }) {
    return _delegate.calculateUpdatePath(
      currentVersion: currentVersion,
      targetVersion: targetVersion,
      manifest: manifest,
    );
  }

  void _validateInfo(VersionInfo info) {
    if (info.strategy == UpdateStrategy.storeRedirect) {
      final uri = Uri.tryParse(info.source);
      if (uri == null || !uri.hasScheme) {
        throw const ValidationException('Store update URL is invalid.');
      }
      return;
    }

    final uri = Uri.tryParse(info.source);
    if (uri == null) {
      throw const ValidationException('Update package URL is invalid.');
    }
    _validateHttpsUri(uri, 'Update package URL');
    _validateSha256(info.sha256);
  }

  void _validateHttpsUri(Uri uri, String label) {
    if (!uri.hasScheme || uri.host.isEmpty || uri.scheme.toLowerCase() != 'https') {
      throw ValidationException('$label must use HTTPS.');
    }
    if (uri.userInfo.isNotEmpty) {
      throw ValidationException('$label must not include embedded credentials.');
    }
  }

  void _validateSha256(String value) {
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
      throw const ValidationException('SHA-256 checksum must be a 64-character hex string.');
    }
  }
}
