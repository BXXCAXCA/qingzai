import 'dart:async';
import 'dart:io';

abstract interface class ConnectivityMonitor {
  Future<bool> get isOnline;

  Stream<bool> get onOnlineChanged;
}

class DartIoConnectivityMonitor implements ConnectivityMonitor {
  DartIoConnectivityMonitor({
    Duration pollInterval = const Duration(seconds: 30),
    String probeHost = 'example.com',
    InternetAddressLookup lookup = InternetAddress.lookup,
  })  : _pollInterval = pollInterval,
        _probeHost = probeHost,
        _lookup = lookup;

  final Duration _pollInterval;
  final String _probeHost;
  final InternetAddressLookup _lookup;

  @override
  Future<bool> get isOnline async {
    try {
      final result = await _lookup(_probeHost).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.any((address) => address.rawAddress.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get onOnlineChanged async* {
    var previous = await isOnline;
    yield previous;

    await for (final _ in Stream<void>.periodic(_pollInterval)) {
      final current = await isOnline;
      if (current != previous) {
        previous = current;
        yield current;
      }
    }
  }
}

typedef InternetAddressLookup = Future<List<InternetAddress>> Function(String host);
