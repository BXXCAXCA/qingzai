import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzai/core/errors/app_exception.dart';
import 'package:qingzai/core/services/dio_version_service.dart';
import 'package:qingzai/core/services/version_service.dart';

void main() {
  group('DioVersionService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qingzai_update_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Dio buildDio(_RecordingHttpClientAdapter adapter) {
      return Dio()..httpClientAdapter = adapter;
    }

    test('check throws when manifest URI is not configured', () async {
      final service = DioVersionService();

      await expectLater(
        service.check(
          const VersionContext(
            currentVersion: '1.0.0',
            platform: 'windows',
            channel: 'stable',
          ),
        ),
        throwsA(isA<UpdateException>()),
      );
    });

    test('check returns null when manifest version is not newer', () async {
      final adapter = _RecordingHttpClientAdapter((request, body) {
        return ResponseBody.fromString(
          jsonEncode(_manifestJson(version: '1.0.0')),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      final service = DioVersionService(
        dio: buildDio(adapter),
        manifestUri: Uri.parse('https://updates.example.com/manifest.json'),
      );

      final info = await service.check(
        const VersionContext(
          currentVersion: '1.0.0',
          platform: 'windows',
          channel: 'stable',
        ),
      );

      expect(info, isNull);
      expect(adapter.requests.single.options.uri.queryParameters, containsPair('platform', 'windows'));
    });

    test('check selects self-hosted patch strategy and shortest patch path', () async {
      final adapter = _RecordingHttpClientAdapter((request, body) {
        return ResponseBody.fromString(
          jsonEncode(_manifestJson()),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      final service = DioVersionService(
        dio: buildDio(adapter),
        manifestUri: Uri.parse('https://updates.example.com/manifest.json'),
      );

      final info = await service.check(
        const VersionContext(
          currentVersion: '1.0.0',
          platform: 'windows',
          channel: 'stable',
        ),
      );

      expect(info, isNotNull);
      expect(info!.version, '1.2.0');
      expect(info.strategy, UpdateStrategy.selfHostedPatch);
      expect(info.size, 20);
      expect(info.patches.map((patch) => patch.toVersion), ['1.1.0', '1.2.0']);
    });

    test('check selects store redirect strategy for iOS', () async {
      final adapter = _RecordingHttpClientAdapter((request, body) {
        return ResponseBody.fromString(
          jsonEncode(_manifestJson()),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      final service = DioVersionService(
        dio: buildDio(adapter),
        manifestUri: Uri.parse('https://updates.example.com/manifest.json'),
      );

      final info = await service.check(
        const VersionContext(
          currentVersion: '1.0.0',
          platform: 'ios',
          channel: 'stable',
        ),
      );

      expect(info, isNotNull);
      expect(info!.strategy, UpdateStrategy.storeRedirect);
      expect(info.source, 'https://apps.apple.com/app/qingzai');
    });

    test('calculateUpdatePath returns an empty list when no path exists', () {
      final service = DioVersionService();
      final manifest = UpdateManifest(
        version: '2.0.0',
        releaseNotes: 'Release',
        releaseDate: DateTime(2026),
        packages: const {},
        patches: const [
          PatchInfo(
            fromVersion: '1.5.0',
            toVersion: '2.0.0',
            patchUrl: 'https://updates.example.com/patch.bin',
            sha256: 'abc',
            size: 1,
          ),
        ],
      );

      final path = service.calculateUpdatePath(
        currentVersion: '1.0.0',
        targetVersion: '2.0.0',
        manifest: manifest,
      );

      expect(path, isEmpty);
    });

    test('verifyLocalFile validates SHA-256 checksums', () async {
      final service = DioVersionService();
      final file = File('${tempDir.path}/package.bin');
      await file.writeAsString('update package');
      final digest = sha256.convert(await file.readAsBytes()).toString();

      expect(await service.verifyLocalFile(file.path, digest), isTrue);
      expect(await service.verifyLocalFile(file.path, '00$digest'), isFalse);
      expect(await service.verifyLocalFile('${tempDir.path}/missing.bin', digest), isFalse);
    });

    test('load downloads update bytes and reports completed progress', () async {
      final bytes = utf8.encode('downloaded update package');
      final adapter = _RecordingHttpClientAdapter((request, body) {
        return ResponseBody.fromBytes(
          bytes,
          200,
          headers: {
            Headers.contentLengthHeader: [bytes.length.toString()],
          },
        );
      });
      final service = DioVersionService(
        dio: buildDio(adapter),
        downloadDirectory: tempDir,
      );

      final events = await service
          .load(
            VersionInfo(
              version: '1.2.0',
              notes: 'Release',
              size: bytes.length,
              source: 'https://updates.example.com/qingzai-1.2.0.zip',
              sha256: sha256.convert(bytes).toString(),
              releaseDate: DateTime(2026),
              strategy: UpdateStrategy.selfHostedFullPackage,
            ),
          )
          .toList();

      expect(events.first.status, VersionProgressStatus.pending);
      expect(events.last.status, VersionProgressStatus.completed);
      expect(events.last.done, bytes.length);
      expect(events.last.progress, 1);
      final downloaded = File(events.last.localPath!);
      expect(await downloaded.exists(), isTrue);
      expect(await downloaded.readAsBytes(), bytes);
    });
  });
}

class _RecordedRequest {
  const _RecordedRequest(this.options, this.body);

  final RequestOptions options;
  final List<int> body;
}

class _RecordingHttpClientAdapter implements HttpClientAdapter {
  _RecordingHttpClientAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions request, List<int> body) handler;
  final List<_RecordedRequest> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        body.addAll(chunk);
      }
    }
    requests.add(_RecordedRequest(options, body));
    return handler(options, body);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _manifestJson({String version = '1.2.0'}) {
  return {
    'version': version,
    'releaseNotes': 'Release notes',
    'releaseDate': '2026-06-23T00:00:00.000Z',
    'isForceUpdate': false,
    'packages': {
      'windows/stable': {
        'platform': 'windows',
        'channel': 'stable',
        'downloadUrl': 'https://updates.example.com/qingzai-windows.zip',
        'sha256': 'abc123',
        'size': 100,
        'supportsPatch': true,
      },
      'ios/stable': {
        'platform': 'ios',
        'channel': 'stable',
        'downloadUrl': '',
        'storeUrl': 'https://apps.apple.com/app/qingzai',
        'sha256': '',
        'size': 0,
      },
    },
    'patches': [
      {
        'fromVersion': '1.0.0',
        'toVersion': '1.1.0',
        'patchUrl': 'https://updates.example.com/1.0.0-1.1.0.patch',
        'sha256': 'p1',
        'size': 10,
      },
      {
        'fromVersion': '1.1.0',
        'toVersion': '1.2.0',
        'patchUrl': 'https://updates.example.com/1.1.0-1.2.0.patch',
        'sha256': 'p2',
        'size': 10,
      },
      {
        'fromVersion': '1.0.0',
        'toVersion': '1.2.0',
        'patchUrl': 'https://updates.example.com/1.0.0-1.2.0.patch',
        'sha256': 'p3',
        'size': 25,
      },
    ],
  };
}
