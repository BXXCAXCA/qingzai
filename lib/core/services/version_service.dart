abstract interface class VersionService {
  Future<VersionInfo?> check(VersionContext context);

  Stream<VersionProgress> load(VersionInfo info);

  Future<bool> verifyLocalFile(String localPath, String sha256);
}

class VersionContext {
  const VersionContext({
    required this.currentVersion,
    required this.platform,
    required this.channel,
  });

  final String currentVersion;
  final String platform;
  final String channel;
}

class VersionInfo {
  const VersionInfo({
    required this.version,
    required this.notes,
    required this.size,
    required this.source,
    required this.sha256,
    required this.releaseDate,
  });

  final String version;
  final String notes;
  final int size;
  final String source;
  final String sha256;
  final DateTime releaseDate;
}

class VersionProgress {
  const VersionProgress({
    required this.done,
    required this.total,
  });

  final int done;
  final int total;

  double get progress => total <= 0 ? 0 : done / total;
}
