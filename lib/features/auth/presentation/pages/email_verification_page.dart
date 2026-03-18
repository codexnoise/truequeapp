import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  ConsumerState<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  Timer? _pollingTimer;
  Timer? _timeoutTimer;
  bool _isChecking = false;
  bool _isResending = false;
  bool _pollingExpired = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingExpired = false;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_isChecking) return;
      final verified = await ref.read(authProvider.notifier).checkEmailVerification();
      if (verified) {
        _pollingTimer?.cancel();
        _timeoutTimer?.cancel();
      }
    });

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      _pollingTimer?.cancel();
      if (mounted) setState(() => _pollingExpired = true);
    });
  }

  Future<void> _manualCheck() async {
    setState(() => _isChecking = true);
    final verified = await ref.read(authProvider.notifier).checkEmailVerification();
    if (!verified && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tu correo aún no ha sido verificado'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
    if (mounted) setState(() => _isChecking = false);
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    await ref.read(authProvider.notifier).resendVerificationEmail();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Correo de verificación reenviado'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      setState(() {
        _isResending = false;
        _pollingExpired = false;
      });
      _startPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final email = authState is AuthEmailNotVerified ? authState.user.email : '';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'VERIFICA TU CORREO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Hemos enviado un enlace de verificación a:',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                email,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Revisa tu bandeja de entrada (o la carpeta de spam/no deseado) y haz click en el enlace para activar tu cuenta.',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (_pollingExpired) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'El tiempo de espera ha expirado. Reenvía el correo para intentar de nuevo.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onErrorContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _manualCheck,
                  child: _isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('YA VERIFIQUÉ MI CORREO'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isResending ? null : _resendEmail,
                  child: _isResending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('REENVIAR CORREO'),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _pollingTimer?.cancel();
                  ref.read(authProvider.notifier).logout();
                },
                child: Text(
                  'Volver al inicio de sesión',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 24,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TRUEQUEAPP',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
