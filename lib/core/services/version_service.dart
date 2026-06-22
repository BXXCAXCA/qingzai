abstract interface class VersionService {
  Future<VersionInfo?> check(VersionContext context);

  Stream<VersionProgress> load(VersionInfo info);

  Future<bool> verifyLocalFile(String localPath, String sha256);

  Future<UpdateManifest> fetchManifest(Uri manifestUri);

  UpdateStrategy selectUpdateStrategy(VersionContext context, UpdatePackage package);

  List<PatchInfo> calculateUpdatePath({
    required String currentVersion,
    required String targetVersion,
    required UpdateManifest manifest,
  });
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
    required this.strategy,
    this.channel,
    this.platform,
    this.localPath,
    this.isForceUpdate = false,
    this.patches = const [],
  });

  final String version;
  final String notes;
  final int size;
  final String source;
  final String sha256;
  final DateTime releaseDate;
  final UpdateStrategy strategy;
  final String? channel;
  final String? platform;
  final String? localPath;
  final bool isForceUpdate;
  final List<PatchInfo> patches;
}

class VersionProgress {
  const VersionProgress({
    required this.done,
    required this.total,
    this.speedBytesPerSecond = 0,
    this.localPath,
    this.status = VersionProgressStatus.downloading,
  });

  final int done;
  final int total;
  final double speedBytesPerSecond;
  final String? localPath;
  final VersionProgressStatus status;

  double get progress => total <= 0 ? 0 : done / total;
}

enum VersionProgressStatus { pending, downloading, completed, redirect, failed }

enum UpdateStrategy { none, storeRedirect, selfHostedFullPackage, selfHostedPatch }

class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.releaseNotes,
    required this.releaseDate,
    required this.packages,
    this.fileChecksums = const {},
    this.patches = const [],
    this.isForceUpdate = false,
  });

  final String version;
  final String releaseNotes;
  final DateTime releaseDate;
  final Map<String, UpdatePackage> packages;
  final Map<String, String> fileChecksums;
  final List<PatchInfo> patches;
  final bool isForceUpdate;

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final packageEntries = <String, UpdatePackage>{};
    final packagesJson = json['packages'];
    if (packagesJson is Map) {
      for (final entry in packagesJson.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          packageEntries[entry.key.toString()] = UpdatePackage.fromJson(value);
        } else if (value is Map) {
          packageEntries[entry.key.toString()] = UpdatePackage.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      }
    }

    final patchesJson = json['patches'];
    final parsedPatches = patchesJson is List
        ? patchesJson
            .whereType<Map>()
            .map((patch) => PatchInfo.fromJson(Map<String, dynamic>.from(patch)))
            .toList(growable: false)
        : const <PatchInfo>[];

    return UpdateManifest(
      version: json['version'] as String,
      releaseNotes: (json['releaseNotes'] ?? json['notes'] ?? '') as String,
      releaseDate: DateTime.parse(json['releaseDate'] as String),
      packages: packageEntries,
      fileChecksums: Map<String, String>.from(json['fileChecksums'] as Map? ?? const {}),
      patches: parsedPatches,
      isForceUpdate: json['isForceUpdate'] as bool? ?? false,
    );
  }
}

class UpdatePackage {
  const UpdatePackage({
    required this.platform,
    required this.channel,
    required this.downloadUrl,
    required this.sha256,
    required this.size,
    this.storeUrl,
    this.signature,
    this.supportsPatch = false,
  });

  final String platform;
  final String channel;
  final String downloadUrl;
  final String sha256;
  final int size;
  final String? storeUrl;
  final String? signature;
  final bool supportsPatch;

  factory UpdatePackage.fromJson(Map<String, dynamic> json) {
    return UpdatePackage(
      platform: (json['platform'] ?? '') as String,
      channel: (json['channel'] ?? 'stable') as String,
      downloadUrl: (json['downloadUrl'] ?? json['url'] ?? '') as String,
      sha256: (json['sha256'] ?? json['checksum'] ?? '') as String,
      size: json['size'] as int? ?? 0,
      storeUrl: json['storeUrl'] as String?,
      signature: json['signature'] as String?,
      supportsPatch: json['supportsPatch'] as bool? ?? false,
    );
  }
}

class PatchInfo {
  const PatchInfo({
    required this.fromVersion,
    required this.toVersion,
    required this.patchUrl,
    required this.sha256,
    required this.size,
  });

  final String fromVersion;
  final String toVersion;
  final String patchUrl;
  final String sha256;
  final int size;

  factory PatchInfo.fromJson(Map<String, dynamic> json) {
    return PatchInfo(
      fromVersion: json['fromVersion'] as String,
      toVersion: json['toVersion'] as String,
      patchUrl: (json['patchUrl'] ?? json['url']) as String,
      sha256: (json['sha256'] ?? json['checksum']) as String,
      size: json['size'] as int,
    );
  }
}
