import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzai/core/errors/app_exception.dart';
import 'package:qingzai/core/services/dio_webdav_service.dart';
import 'package:qingzai/core/services/webdav_service.dart';

void main() {
  const config = WebDavConfig(
    serverUrl: 'https://example.com/dav',
    username: 'user@example.com',
    secret: 'password',
  );

  Dio buildDio(_RecordingHttpClientAdapter adapter) {
    return Dio()..httpClientAdapter = adapter;
  }

  group('DioWebDavService', () {
    test('rejects non-HTTPS WebDAV URLs', () async {
      final service = DioWebDavService();

      expect(
        () => service.connect(
          const WebDavConfig(
            serverUrl: 'http://example.com/dav',
            username: 'user',
            secret: 'password',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('connect sends PROPFIND with Basic auth and marks service connected', () async {
      final adapter = _RecordingHttpClientAdapter((request, body) {
        return ResponseBody.fromString(_emptyMultiStatusXml, 207);
      });
      final service = DioWebDavService(dio: buildDio(adapter));

      final connected = await service.connect(config);

      expect(connected, isTrue);
      expect(service.isConnected, isTrue);
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single.options;
      expect(request.method, 'PROPFIND');
      expect(request.uri.toString(), 'https://example.com/dav/');
      expect(request.headers['Depth'], '0');
      expect(
        request.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('user@example.com:password'))}',
      );
    });

    test('uploadFile sends PUT data and conditional ETag header', () async {
      final adapter = _RecordingHttpClientAdapter((request, body) {
        if (request.method == 'PROPFIND') {
          return ResponseBody.fromString(_emptyMultiStatusXml, 207);
        }
        return ResponseBody.fromString('', 201, headers: {
          'etag': ['"remote-etag"'],
        });
      });
      final service = DioWebDavService(dio: buildDio(adapter));
      await service.connect(config);

      final result = await service.uploadFile(
        remotePath: 'todos/item.enc',
        data: const [1, 2, 3],
        etag: 'local-etag',
      );

      expect(result.success, isTrue);
      expect(result.etag, '"remote-etag"');
      final upload = adapter.requests.last;
      expect(upload.options.method, 'PUT');
      expect(upload.options.uri.toString(), 'https://example.com/dav/todos/item.enc');
      expect(upload.options.headers['If-Match'], 'local-etag');
      expect(upload.body, [1, 2, 3]);
    });

    test('downloadFile returns bytes and response metadata', () async {
      final adapter = _RecordingHttpClientAdapter((request, body) {
        if (request.method == 'PROPFIND') {
          return ResponseBody.fromString(_emptyMultiStatusXml, 207);
        }
        return ResponseBody.fromBytes([4, 5, 6], 200, headers: {
          'etag': ['"abc"'],
          'content-length': ['3'],
          'last-modified': ['Wed, 21 Oct 2015 07:28:00 GMT'],
        });
      });
      final service = DioWebDavService(dio: buildDio(adapter));
      await service.connect(config);

      final result = await service.downloadFile('notes/a.enc');

      expect(result.data, [4, 5, 6]);
      expect(result.metadata.path, 'notes/a.enc');
      expect(result.metadata.etag, 'abc');
      expect(result.metadata.size, 3);
      expect(result.metadata.isDirectory, isFalse);
    });

    test('listDirectory parses multistatus file and directory metadata', () async {
      final adapter = _RecordingHttpClientAdapter((request, body) {
        if (request.headers['Depth'] == '0') {
          return ResponseBody.fromString(_emptyMultiStatusXml, 207);
        }
        return ResponseBody.fromString(_directoryMultiStatusXml, 207);
      });
      final service = DioWebDavService(dio: buildDio(adapter));
      await service.connect(config);

      final files = await service.listDirectory('todos');

      expect(files, hasLength(2));
      expect(files[0].path, 'todos/item.enc');
      expect(files[0].etag, 'etag-item');
      expect(files[0].size, 42);
      expect(files[0].isDirectory, isFalse);
      expect(files[1].path, 'todos/archive/');
      expect(files[1].isDirectory, isTrue);
    });

    test('fileExists and deleteFile convert 404 responses to false', () async {
      final adapter = _RecordingHttpClientAdapter((request, body) {
        if (request.method == 'PROPFIND') {
          return ResponseBody.fromString(_emptyMultiStatusXml, 207);
        }
        return ResponseBody.fromString('', 404);
      });
      final service = DioWebDavService(dio: buildDio(adapter));
      await service.connect(config);

      expect(await service.fileExists('missing.enc'), isFalse);
      expect(await service.deleteFile('missing.enc'), isFalse);
    });

    test('rejects traversal paths before making a request', () async {
      final adapter = _RecordingHttpClientAdapter((request, body) {
        return ResponseBody.fromString(_emptyMultiStatusXml, 207);
      });
      final service = DioWebDavService(dio: buildDio(adapter));
      await service.connect(config);

      expect(
        () => service.downloadFile('../secret.enc'),
        throwsA(isA<ValidationException>()),
      );
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

const _emptyMultiStatusXml = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:" />
''';

const _directoryMultiStatusXml = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/todos/</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype><d:collection /></d:resourcetype>
      </d:prop>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/todos/item.enc</d:href>
    <d:propstat>
      <d:prop>
        <d:getetag>"etag-item"</d:getetag>
        <d:getcontentlength>42</d:getcontentlength>
        <d:getlastmodified>Wed, 21 Oct 2015 07:28:00 GMT</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/todos/archive/</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype><d:collection /></d:resourcetype>
        <d:getlastmodified>Wed, 21 Oct 2015 07:28:00 GMT</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
</d:multistatus>
''';
