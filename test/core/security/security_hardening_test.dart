import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzai/core/errors/app_exception.dart';
import 'package:qingzai/core/security/security.dart';
import 'package:qingzai/core/services/dio_webdav_service.dart';
import 'package:qingzai/core/services/secure_version_service.dart';
import 'package:qingzai/core/services/version_service.dart';
import 'package:qingzai/core/services/webdav_service.dart';

void main() {
  group('PasswordPolicy', () {
    test('rejects weak master passwords and accepts strong ones', () {
      const policy = PasswordPolicy();

      expect(policy.evaluate('password').isAcceptable, isFalse);
      expect(policy.evaluate('Correct-Horse-42-Staple!').isAcceptable, isTrue);
    });
  });

  group('SensitiveValueRedactor', () {
    test('redacts tokens, passwords, authorization headers, and URL credentials', () {
      const redactor = SensitiveValueRedactor();

      final redacted = redactor.redact(
        'Authorization: Bearer abc123 password=hunter2 '
        'https://user:secret@example.com/dav?token=abc',
      );

      expect(redacted, isNot(contains('abc123')));
      expect(redacted, isNot(contains('hunter2')));
      expect(redacted, isNot(contains('user:secret')));
      expect(redacted, contains(SensitiveValueRedactor.redacted));
    });
  });

  group('SecureVersionService', () {
    test('rejects insecure self-hosted update URLs', () async {
      final service = SecureVersionService(_FakeVersionService());

      await expectLater(
        service
            .load(
              VersionInfo(
                version: '1.2.0',
                notes: 'Release',
                size: 10,
                source: 'http://updates.example.com/qingzai.zip',
                sha256: '0' * 64,
                releaseDate: DateTime(2026),
                strategy: UpdateStrategy.selfHostedFullPackage,
              ),
            )
            .toList(),
        throwsA(isA<ValidationException>()),
      );
    });

    test('turns a completed download into failed progress when checksum mismatches', () async {
      final file = await File('${Directory.systemTemp.path}/qingzai-bad-update.bin').create();
      await file.writeAsString('tampered');
      final service = SecureVersionService(
        _FakeVersionService(
          progress: VersionProgress(
            done: 8,
            total: 8,
            localPath: file.path,
            status: VersionProgressStatus.completed,
          ),
          verifyResult: false,
        ),
      );

      final events = await service
          .load(
            VersionInfo(
              version: '1.2.0',
              notes: 'Release',
              size: 8,
              source: 'https://updates.example.com/qingzai.zip',
              sha256: sha256.convert(utf8.encode('expected')).toString(),
              releaseDate: DateTime(2026),
              strategy: UpdateStrategy.selfHostedFullPackage,
            ),
          )
          .toList();

      expect(events.last.status, VersionProgressStatus.failed);
      expect(await file.exists(), isFalse);
    });
  });

  group('DioWebDavService security', () {
    const config = WebDavConfig(
      serverUrl: 'https://example.com/dav',
      username: 'user@example.com',
      secret: 'Strong-Token-42!',
    );

    Dio buildDio(_RecordingHttpClientAdapter adapter) {
      return Dio()..httpClientAdapter = adapter;
    }

    test('rejects absolute remote paths before sending credentials', () async {
      final adapter = _RecordingHttpClientAdapter((request, body) {
        return ResponseBody.fromString(_emptyMultiStatusXml, 207);
      });
      final service = DioWebDavService(dio: buildDio(adapter));
      await service.connect(config);

      await expectLater(
        service.fileExists('https://evil.example.com/stolen.enc'),
        throwsA(isA<ValidationException>()),
      );

      expect(adapter.requests, hasLength(1));
    });

    test('ignores multistatus hrefs outside the configured WebDAV origin', () async {
      final adapter = _RecordingHttpClientAdapter((request, body) {
        if (request.method == 'PROPFIND' && request.uri.path.endsWith('/dav/')) {
          return ResponseBody.fromString(_emptyMultiStatusXml, 207);
        }
        return ResponseBody.fromString(_mixedOriginMultiStatusXml, 207);
      });
      final service = DioWebDavService(dio: buildDio(adapter));
      await service.connect(config);

      final files = await service.listDirectory('todos');

      expect(files.map((file) => file.path), ['todos/local.enc']);
    });
  });
}

class _FakeVersionService implements VersionService {
  _FakeVersionService({this.progress, this.verifyResult = true});

  final VersionProgress? progress;
  final bool verifyResult;

  @override
  Future<VersionInfo?> check(VersionContext context) async => null;

  @override
  Stream<VersionProgress> load(VersionInfo info) async* {
    if (progress != null) {
      yield progress!;
    }
  }

  @override
  Future<bool> verifyLocalFile(String localPath, String sha256) async => verifyResult;

  @override
  Future<UpdateManifest> fetchManifest(Uri manifestUri) {
    throw UnimplementedError();
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

const _emptyMultiStatusXml = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
</d:multistatus>''';

const _mixedOriginMultiStatusXml = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>https://example.com/dav/todos/local.enc</d:href>
    <d:propstat><d:prop><d:getetag>"safe"</d:getetag><d:getcontentlength>1</d:getcontentlength></d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>https://evil.example.com/dav/todos/evil.enc</d:href>
    <d:propstat><d:prop><d:getetag>"evil"</d:getetag><d:getcontentlength>1</d:getcontentlength></d:prop></d:propstat>
  </d:response>
</d:multistatus>''';
