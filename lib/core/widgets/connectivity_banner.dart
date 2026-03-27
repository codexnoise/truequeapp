import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/injection_container.dart';
import '../providers/connectivity_provider.dart';
import '../services/connectivity_service.dart';

class ConnectivityBanner extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner>
    with WidgetsBindingObserver {
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = sl<ConnectivityService>();
    if (state == AppLifecycleState.resumed) {
      service.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      service.pause();
    }
  }

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    await ref.read(connectivityProvider.notifier).retry();
    if (mounted) setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(connectivityProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        widget.child,
        if (!isConnected)
          PopScope(
            canPop: false,
            child: Scaffold(
              backgroundColor: colorScheme.surface,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 80,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Sin conexión a internet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Revisa tu conexión Wi-Fi o datos móviles e intenta de nuevo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isRetrying ? null : _retry,
                          icon: _isRetrying
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: Text(
                            _isRetrying ? 'Verificando...' : 'Reintentar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
