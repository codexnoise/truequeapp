import 'dart:async';
import 'dart:io';

abstract class ConnectivityService {
  Stream<bool> get onConnectivityChanged;
  Future<bool> checkConnectivity();
  void pause();
  void resume();
  void dispose();
}

class ConnectivityServiceImpl implements ConnectivityService {
  Timer? _timer;
  final _controller = StreamController<bool>.broadcast();
  bool _lastStatus = true;

  ConnectivityServiceImpl() {
    checkConnectivity();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => checkConnectivity());
  }

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (isConnected != _lastStatus) {
        _lastStatus = isConnected;
        _controller.add(isConnected);
      }
      return isConnected;
    } on SocketException catch (_) {
      if (_lastStatus != false) {
        _lastStatus = false;
        _controller.add(false);
      }
      return false;
    } on TimeoutException catch (_) {
      if (_lastStatus != false) {
        _lastStatus = false;
        _controller.add(false);
      }
      return false;
    }
  }

  @override
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void resume() {
    if (_timer != null) return;
    checkConnectivity();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => checkConnectivity());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
