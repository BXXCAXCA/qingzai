import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the local device id used by syncable business objects.
///
/// This placeholder is intentionally replaceable. A platform implementation can
/// override it once [PlatformService] is wired to native device identifiers.
final deviceIdProvider = Provider<String>((ref) => 'local-device');
