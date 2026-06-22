import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../errors/app_exception.dart';
import 'version_service.dart';

class DioVersionService implements VersionService {
  DioVersionService({
    Dio? dio,
    Uri? manifestUri,
    Directory? downloadDirectory,
  })  : _dio = dio ?? Dio(),
        _manifestUri = manifestUri,
        _downloadDirectory = downloadDirectory;

  final Dio _dio;
  final Uri? _manifestUri;
  final Directory? _downloadDirectory;

  @override
  Future<VersionInfo?> check(VersionContext context) async {
    _validateContext(context);
    final manifestUri = _manifestUri;
    if (manifestUri == null) {
      throw const UpdateException('Update manifest URI is not configured.');
    }

    final manifest = await fetchManifest(_withContextQuery(manifestUri, context));
    if (!_isNewerVersion(manifest.version, context.currentVersion)) {
      return null;
    }

    final package = _selectPackage(manifest, context);
    if (package == null) {
      throw UpdateException(
        'No update package found for ${context.platform}/${context.channel}.',
      );
    }

    final strategy = selectUpdateStrategy(context, package);
    final patches = strategy == UpdateStrategy.selfHostedPatch
        ? calculateUpdatePath(
            currentVersion: context.currentVersion,
            targetVersion: manifest.version,
            manifest: manifest,
          )
        : const <PatchInfo>[];

    return VersionInfo(
      version: manifest.version,
      notes: manifest.releaseNotes,
      size: strategy == UpdateStrategy.selfHostedPatch
          ? patches.fold<int>(0, (total, patch) => total + patch.size)
          : package.size,
      source: strategy == UpdateStrategy.storeRedirect
          ? package.storeUrl ?? package.downloadUrl
          : package.downloadUrl,
      sha256: package.sha256,
      releaseDate: manifest.releaseDate,
      strategy: strategy,
      channel: context.channel,
      platform: context.platform,
      isForceUpdate: manifest.isForceUpdate,
      patches: patches,
    );
  }

  @override
  Future<UpdateManifest> fetchManifest(Uri manifestUri) async {
    final response = await _dio.getUri<Map<String, dynamic>>(manifestUri);
    final data = response.data;
    if (data == null) {
      throw const UpdateException('Update manifest response was empty.');
    }
    return UpdateManifest.fromJson(data);
  }

  @override
  Stream<VersionProgress> load(VersionInfo info) async* {
    if (info.strategy == UpdateStrategy.storeRedirect) {
      yield VersionProgress(
        done: 0,
        total: 0,
        localPath: info.source,
        status: VersionProgressStatus.redirect,
      );
      return;
    }

    final sourceUri = Uri.tryParse(info.source);
    if (sourceUri == null || !sourceUri.hasScheme) {
      yield VersionProgress(
        done: 0,
        total: info.size,
        status: VersionProgressStatus.failed,
      );
      return;
    }

    final directory = _downloadDirectory ?? await Directory.systemTemp.createTemp('qingzai_update_');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final fileName = sourceUri.pathSegments.isEmpty || sourceUri.pathSegments.last.isEmpty
        ? 'qingzai-${info.version}.update'
        : sourceUri.pathSegments.last;
    final localPath = info.localPath ?? p.join(directory.path, fileName);
    final file = File(localPath);

    final startedAt = DateTime.now();
    var downloaded = 0;
    IOSink? sink;

    try {
      final response = await _dio.getUri<ResponseBody>(
        sourceUri,
        options: Options(responseType: ResponseType.stream),
      );
      final stream = response.data;
      if (stream == null) {
        throw const UpdateException('Update download response was empty.');
      }

      final headerTotal = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );
      final total = headerTotal ?? info.size;
      sink = file.openWrite();

      yield VersionProgress(
        done: 0,
        total: total,
        localPath: localPath,
        status: VersionProgressStatus.pending,
      );

      await for (final chunk in stream.stream) {
        downloaded += chunk.length;
        sink.add(chunk);
        final elapsedSeconds = max(
          DateTime.now().difference(startedAt).inMilliseconds / 1000,
          0.001,
        );
        yield VersionProgress(
          done: downloaded,
          total: total,
          speedBytesPerSecond: downloaded / elapsedSeconds,
          localPath: localPath,
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      yield VersionProgress(
        done: downloaded,
        total: total,
        localPath: localPath,
        status: VersionProgressStatus.completed,
      );
    } catch (_) {
      await sink?.close();
      yield VersionProgress(
        done: downloaded,
        total: info.size,
        localPath: localPath,
        status: VersionProgressStatus.failed,
      );
    }
  }

  @override
  Future<bool> verifyLocalFile(String localPath, String sha256Value) async {
    final file = File(localPath);
    if (!await file.exists()) {
      return false;
    }

    final expected = sha256Value.trim().toLowerCase();
    if (expected.isEmpty) {
      throw const ValidationException('Expected SHA-256 checksum must not be empty.');
    }

    final actual = sha256.convert(await file.readAsBytes()).toString();
    return actual == expected;
  }

  @override
  UpdateStrategy selectUpdateStrategy(VersionContext context, UpdatePackage package) {
    final platform = context.platform.toLowerCase();
    final channel = context.channel.toLowerCase();
    if (platform == 'ios' || (platform == 'android' && channel == 'store')) {
      return UpdateStrategy.storeRedirect;
    }
    if (package.supportsPatch) {
      return UpdateStrategy.selfHostedPatch;
    }
    return UpdateStrategy.selfHostedFullPackage;
  }

  @override
  List<PatchInfo> calculateUpdatePath({
    required String currentVersion,
    required String targetVersion,
    required UpdateManifest manifest,
  }) {
    if (currentVersion == targetVersion) {
      return const [];
    }

    final graph = <String, List<PatchInfo>>{};
    final versions = <String>{currentVersion, targetVersion};
    for (final patch in manifest.patches) {
      graph.putIfAbsent(patch.fromVersion, () => <PatchInfo>[]).add(patch);
      versions.add(patch.fromVersion);
      versions.add(patch.toVersion);
    }

    final distances = <String, int>{currentVersion: 0};
    final previous = <String, PatchInfo>{};
    final unvisited = versions.toSet();

    while (unvisited.isNotEmpty) {
      String? current;
      var minDistance = _infiniteDistance;
      for (final version in unvisited) {
        final distance = distances[version] ?? _infiniteDistance;
        if (distance < minDistance) {
          minDistance = distance;
          current = version;
        }
      }

      if (current == null || minDistance == _infiniteDistance) {
        break;
      }
      if (current == targetVersion) {
        break;
      }

      unvisited.remove(current);
      for (final patch in graph[current] ?? const <PatchInfo>[]) {
        final candidate = (distances[current] ?? _infiniteDistance) + patch.size;
        if (candidate < (distances[patch.toVersion] ?? _infiniteDistance)) {
          distances[patch.toVersion] = candidate;
          previous[patch.toVersion] = patch;
        }
      }
    }

    if (!previous.containsKey(targetVersion)) {
      return const [];
    }

    final path = <PatchInfo>[];
    var cursor = targetVersion;
    while (cursor != currentVersion) {
      final patch = previous[cursor];
      if (patch == null) {
        return const [];
      }
      path.insert(0, patch);
      cursor = patch.fromVersion;
    }

    return path;
  }

  static const _infiniteDistance = 1 << 62;

  void _validateContext(VersionContext context) {
    if (context.currentVersion.trim().isEmpty) {
      throw const ValidationException('Current version must not be empty.');
    }
    if (context.platform.trim().isEmpty) {
      throw const ValidationException('Platform must not be empty.');
    }
    if (context.channel.trim().isEmpty) {
      throw const ValidationException('Channel must not be empty.');
    }
  }

  Uri _withContextQuery(Uri uri, VersionContext context) {
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'currentVersion': context.currentVersion,
        'platform': context.platform,
        'channel': context.channel,
      },
    );
  }

  UpdatePackage? _selectPackage(UpdateManifest manifest, VersionContext context) {
    final exactKey = '${context.platform}/${context.channel}'.toLowerCase();
    final platformKey = context.platform.toLowerCase();

    for (final entry in manifest.packages.entries) {
      if (entry.key.toLowerCase() == exactKey) {
        return entry.value;
      }
    }
    for (final entry in manifest.packages.entries) {
      if (entry.key.toLowerCase() == platformKey) {
        return entry.value;
      }
    }
    for (final package in manifest.packages.values) {
      if (package.platform.toLowerCase() == context.platform.toLowerCase() &&
          package.channel.toLowerCase() == context.channel.toLowerCase()) {
        return package;
      }
    }
    for (final package in manifest.packages.values) {
      if (package.platform.toLowerCase() == context.platform.toLowerCase()) {
        return package;
      }
    }
    return null;
  }

  bool _isNewerVersion(String candidate, String current) {
    final candidateParts = _parseVersion(candidate);
    final currentParts = _parseVersion(current);
    final length = max(candidateParts.length, currentParts.length);
    for (var i = 0; i < length; i++) {
      final left = i < candidateParts.length ? candidateParts[i] : 0;
      final right = i < currentParts.length ? currentParts[i] : 0;
      if (left != right) {
        return left > right;
      }
    }
    return false;
  }

  List<int> _parseVersion(String version) {
    return version
        .split(RegExp(r'[.+-]'))
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }
}
