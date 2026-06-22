import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../errors/app_exception.dart';
import 'webdav_service.dart';

class DioWebDavService implements WebDavService {
  DioWebDavService({Dio? dio, Duration timeout = const Duration(seconds: 20)})
      : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = timeout
      ..sendTimeout = timeout
      ..receiveTimeout = timeout
      ..responseType = ResponseType.plain
      ..validateStatus = (_) => true;
  }

  final Dio _dio;

  Uri? _baseUri;
  String? _authorizationHeader;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  @override
  Future<bool> connect(WebDavConfig config) async {
    final uri = _validateConfig(config);
    _baseUri = _ensureTrailingSlash(uri);
    _authorizationHeader = _basicAuth(config.username, config.secret);

    try {
      final response = await _request(
        method: 'PROPFIND',
        remotePath: '',
        data: _propfindAllPropertiesBody,
        headers: const {
          'Depth': '0',
          'Content-Type': 'application/xml; charset=utf-8',
        },
      );

      _isConnected = _isSuccessful(response.statusCode) || response.statusCode == 207;
      if (!_isConnected) {
        throw WebDavException('Failed to connect to WebDAV server: HTTP ${response.statusCode}');
      }
      return true;
    } catch (error) {
      _isConnected = false;
      if (error is WebDavException || error is ValidationException) {
        rethrow;
      }
      throw WebDavException('Failed to connect to WebDAV server', cause: error);
    }
  }

  @override
  Future<UploadResult> uploadFile({
    required String remotePath,
    required List<int> data,
    String? etag,
  }) async {
    _ensureConnected();
    _validateRemotePath(remotePath);
    if (data.isEmpty) {
      throw const ValidationException('Upload data must not be empty.');
    }

    final headers = <String, String>{'Content-Type': 'application/octet-stream'};
    if (etag != null && etag.isNotEmpty) {
      headers['If-Match'] = etag;
    }

    try {
      final response = await _request(
        method: 'PUT',
        remotePath: remotePath,
        data: data,
        headers: headers,
      );
      final success = response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
      return UploadResult(
        success: success,
        etag: response.headers.value('etag'),
        errorMessage: success ? null : 'HTTP ${response.statusCode}',
      );
    } catch (error) {
      return UploadResult(success: false, errorMessage: error.toString());
    }
  }

  @override
  Future<DownloadResult> downloadFile(String remotePath) async {
    _ensureConnected();
    _validateRemotePath(remotePath);

    final response = await _request(
      method: 'GET',
      remotePath: remotePath,
      options: Options(responseType: ResponseType.bytes),
    );

    if (!_isSuccessful(response.statusCode)) {
      throw WebDavException('Failed to download WebDAV file: HTTP ${response.statusCode}');
    }

    final data = List<int>.from(response.data as List<dynamic>);
    return DownloadResult(
      data: data,
      metadata: _metadataFromHeaders(
        remotePath,
        response.headers,
        fallbackSize: data.length,
        isDirectory: false,
      ),
    );
  }

  @override
  Future<List<FileMetadata>> listDirectory(String remotePath) async {
    _ensureConnected();
    _validateRemotePath(remotePath, allowRoot: true);

    final response = await _request(
      method: 'PROPFIND',
      remotePath: remotePath,
      data: _propfindAllPropertiesBody,
      headers: const {
        'Depth': '1',
        'Content-Type': 'application/xml; charset=utf-8',
      },
    );

    if (response.statusCode != 207 && !_isSuccessful(response.statusCode)) {
      throw WebDavException('Failed to list WebDAV directory: HTTP ${response.statusCode}');
    }

    final xml = response.data?.toString() ?? '';
    return _parseMultiStatus(xml, requestedPath: _normalizeRemotePath(remotePath));
  }

  @override
  Future<bool> deleteFile(String remotePath) async {
    _ensureConnected();
    _validateRemotePath(remotePath);

    final response = await _request(method: 'DELETE', remotePath: remotePath);
    if (response.statusCode == 404) {
      return false;
    }
    return response.statusCode == 200 || response.statusCode == 202 || response.statusCode == 204;
  }

  @override
  Future<bool> fileExists(String remotePath) async {
    _ensureConnected();
    _validateRemotePath(remotePath);

    final response = await _request(method: 'HEAD', remotePath: remotePath);
    if (response.statusCode == 404) {
      return false;
    }
    return _isSuccessful(response.statusCode);
  }

  @override
  Future<FileMetadata?> getFileMetadata(String remotePath) async {
    _ensureConnected();
    _validateRemotePath(remotePath);

    final response = await _request(method: 'HEAD', remotePath: remotePath);
    if (response.statusCode == 404) {
      return null;
    }
    if (!_isSuccessful(response.statusCode)) {
      throw WebDavException('Failed to read WebDAV metadata: HTTP ${response.statusCode}');
    }

    return _metadataFromHeaders(remotePath, response.headers, isDirectory: false);
  }

  @override
  Future<bool> createDirectory(String remotePath) async {
    _ensureConnected();
    _validateRemotePath(remotePath);

    final response = await _request(method: 'MKCOL', remotePath: remotePath);
    if (response.statusCode == 201) {
      return true;
    }
    if (response.statusCode == 405) {
      return fileExists(remotePath);
    }
    return false;
  }

  Future<Response<dynamic>> _request({
    required String method,
    required String remotePath,
    Object? data,
    Map<String, String> headers = const {},
    Options? options,
  }) async {
    final uri = _resolveRemoteUri(remotePath);
    final mergedHeaders = <String, String>{
      if (_authorizationHeader != null) 'Authorization': _authorizationHeader!,
      ...headers,
    };

    return _dio.requestUri<dynamic>(
      uri,
      data: data,
      options: (options ?? Options()).copyWith(
        method: method,
        headers: mergedHeaders,
        validateStatus: (_) => true,
      ),
    );
  }

  Uri _validateConfig(WebDavConfig config) {
    if (config.serverUrl.trim().isEmpty) {
      throw const ValidationException('WebDAV server URL must not be empty.');
    }
    if (config.username.trim().isEmpty) {
      throw const ValidationException('WebDAV username must not be empty.');
    }
    if (config.secret.isEmpty) {
      throw const ValidationException('WebDAV password must not be empty.');
    }

    final uri = Uri.tryParse(config.serverUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ValidationException('WebDAV server URL is invalid.');
    }
    if (uri.scheme.toLowerCase() != 'https') {
      throw const ValidationException('WebDAV server URL must use HTTPS.');
    }
    return uri;
  }

  void _ensureConnected() {
    if (!_isConnected || _baseUri == null) {
      throw const WebDavException('WebDAV service is not connected.');
    }
  }

  Uri _resolveRemoteUri(String remotePath) {
    final baseUri = _baseUri;
    if (baseUri == null) {
      throw const WebDavException('WebDAV service is not configured.');
    }
    final normalizedPath = _normalizeRemotePath(remotePath);
    return baseUri.resolve(normalizedPath);
  }

  void _validateRemotePath(String remotePath, {bool allowRoot = false}) {
    final normalizedPath = _normalizeRemotePath(remotePath);
    if (!allowRoot && normalizedPath.isEmpty) {
      throw const ValidationException('Remote path must not be empty.');
    }

    final segments = normalizedPath.split('/').where((segment) => segment.isNotEmpty);
    if (segments.any((segment) => segment == '..' || segment == '.')) {
      throw const ValidationException('Remote path must not contain traversal segments.');
    }
  }

  String _normalizeRemotePath(String remotePath) {
    return remotePath.trim().replaceAll(RegExp(r'^/+'), '');
  }

  Uri _ensureTrailingSlash(Uri uri) {
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return uri.replace(path: path);
  }

  String _basicAuth(String username, String password) {
    final credential = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credential';
  }

  bool _isSuccessful(int? statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  FileMetadata _metadataFromHeaders(
    String path,
    Headers headers, {
    int? fallbackSize,
    required bool isDirectory,
  }) {
    final contentLength = int.tryParse(headers.value('content-length') ?? '');
    final lastModifiedHeader = headers.value('last-modified');
    return FileMetadata(
      path: _normalizeRemotePath(path),
      etag: _stripQuotes(headers.value('etag') ?? ''),
      lastModified: _parseHttpDate(lastModifiedHeader) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      size: contentLength ?? fallbackSize ?? 0,
      isDirectory: isDirectory,
    );
  }

  List<FileMetadata> _parseMultiStatus(String xml, {required String requestedPath}) {
    final responsePattern = RegExp(
      r'<(?:[A-Za-z0-9_]+:)?response\b[^>]*>(.*?)</(?:[A-Za-z0-9_]+:)?response>',
      dotAll: true,
      caseSensitive: false,
    );

    final requested = _stripTrailingSlash(_normalizeRemotePath(Uri.decodeComponent(requestedPath)));

    return responsePattern
        .allMatches(xml)
        .map((match) => _parseResponseNode(match.group(1) ?? ''))
        .whereType<FileMetadata>()
        .where((metadata) => _stripTrailingSlash(metadata.path) != requested)
        .toList(growable: false);
  }

  FileMetadata? _parseResponseNode(String node) {
    final href = _tagValue(node, 'href');
    if (href == null || href.isEmpty) {
      return null;
    }

    final decodedPath = Uri.decodeComponent(href);
    final remotePath = _pathRelativeToBase(decodedPath);
    final isDirectory = RegExp(
      r'<(?:[A-Za-z0-9_]+:)?collection\b[^>]*/?>',
      caseSensitive: false,
    ).hasMatch(node);
    final size = int.tryParse(_tagValue(node, 'getcontentlength') ?? '') ?? 0;
    final lastModified = _parseHttpDate(_tagValue(node, 'getlastmodified')) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return FileMetadata(
      path: remotePath,
      etag: _stripQuotes(_tagValue(node, 'getetag') ?? ''),
      lastModified: lastModified,
      size: size,
      isDirectory: isDirectory,
    );
  }

  String? _tagValue(String xml, String localName) {
    final pattern = RegExp(
      '<(?:[A-Za-z0-9_]+:)?$localName\\b[^>]*>(.*?)</(?:[A-Za-z0-9_]+:)?$localName>',
      dotAll: true,
      caseSensitive: false,
    );
    final match = pattern.firstMatch(xml);
    if (match == null) {
      return null;
    }
    return _decodeXml(match.group(1)?.trim() ?? '');
  }

  String _pathRelativeToBase(String absoluteOrRelativePath) {
    final basePath = _baseUri?.path ?? '/';
    final path = absoluteOrRelativePath.startsWith('/') ? absoluteOrRelativePath : '/$absoluteOrRelativePath';
    if (path.startsWith(basePath)) {
      return _normalizeRemotePath(path.substring(basePath.length));
    }
    return _normalizeRemotePath(path);
  }

  String _stripTrailingSlash(String value) {
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  String _stripQuotes(String value) {
    final trimmed = value.trim();
    if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }

  String _decodeXml(String value) {
    return value
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }

  DateTime? _parseHttpDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    try {
      return HttpDate.parse(value);
    } on FormatException {
      return null;
    }
  }
}

const _propfindAllPropertiesBody = '''<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <allprop />
</propfind>
''';
