import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/injection_container.dart';
import '../services/connectivity_service.dart';

class ConnectivityNotifier extends Notifier<bool> {
  StreamSubscription<bool>? _subscription;

  @override
  bool build() {
    final service = sl<ConnectivityService>();

    _subscription = service.onConnectivityChanged.listen((isConnected) {
      state = isConnected;
    });

    service.checkConnectivity().then((value) => state = value);

    ref.onDispose(() => _subscription?.cancel());

    return true;
  }

  Future<void> retry() async {
    final result = await sl<ConnectivityService>().checkConnectivity();
    state = result;
  }
}

final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, bool>(() => ConnectivityNotifier());
