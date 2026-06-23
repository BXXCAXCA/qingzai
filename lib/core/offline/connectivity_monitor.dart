import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class ConnectivityMonitor {
  Future<bool> get isOnline;

  Stream<bool> get onOnlineChanged;
}

class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return _isOnlineResult(result);
  }

  @override
  Stream<bool> get onOnlineChanged {
    return _connectivity.onConnectivityChanged
        .map(_isOnlineResult)
        .distinct();
  }

  bool _isOnlineResult(ConnectivityResult result) {
    return result != ConnectivityResult.none;
  }
}
