abstract interface class WebDavService {
  Future<bool> connect(WebDavConfig config);

  Future<UploadResult> uploadFile({
    required String remotePath,
    required List<int> data,
    String? etag,
  });

  Future<DownloadResult> downloadFile(String remotePath);

  Future<List<FileMetadata>> listDirectory(String remotePath);

  Future<bool> deleteFile(String remotePath);

  Future<bool> fileExists(String remotePath);

  Future<FileMetadata?> getFileMetadata(String remotePath);

  Future<bool> createDirectory(String remotePath);
}

class WebDavConfig {
  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.secret,
  });

  final String serverUrl;
  final String username;
  final String secret;
}

class UploadResult {
  const UploadResult({required this.success, this.etag, this.errorMessage});

  final bool success;
  final String? etag;
  final String? errorMessage;
}

class DownloadResult {
  const DownloadResult({required this.data, required this.metadata});

  final List<int> data;
  final FileMetadata metadata;
}

class FileMetadata {
  const FileMetadata({
    required this.path,
    required this.etag,
    required this.lastModified,
    required this.size,
    required this.isDirectory,
  });

  final String path;
  final String etag;
  final DateTime lastModified;
  final int size;
  final bool isDirectory;
}
