import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_provider.dart';

class ConnectivityBanner extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner> {
  bool _isRetrying = false;

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
