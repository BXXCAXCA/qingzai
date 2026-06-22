class SyncResult {
  SyncResult({
    this.uploaded = 0,
    this.downloaded = 0,
    this.errors = const [],
    this.completedAt,
  });

  final int uploaded;
  final int downloaded;
  final List<String> errors;
  final DateTime? completedAt;

  bool get hasErrors => errors.isNotEmpty;

  bool get isSuccess => !hasErrors;

  SyncResult copyWith({
    int? uploaded,
    int? downloaded,
    List<String>? errors,
    DateTime? completedAt,
  }) {
    return SyncResult(
      uploaded: uploaded ?? this.uploaded,
      downloaded: downloaded ?? this.downloaded,
      errors: errors ?? this.errors,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
