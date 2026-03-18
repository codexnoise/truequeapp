import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recovery_provider.dart';

class RecoveryPage extends ConsumerStatefulWidget {
  const RecoveryPage({super.key});

  @override
  ConsumerState<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends ConsumerState<RecoveryPage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _phoneFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recoveryState = ref.watch(recoveryProvider);

    ref.listen<RecoveryState>(recoveryProvider, (previous, next) {
      if (next is RecoverySuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: colorScheme.primary,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      if (next is RecoveryError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    });

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () {
              ref.read(recoveryProvider.notifier).reset();
              Navigator.pop(context);
            },
          ),
          title: Text(
            'Recuperar cuenta',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          bottom: TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            onTap: (_) => ref.read(recoveryProvider.notifier).reset(),
            tabs: const [
              Tab(text: 'Contraseña'),
              Tab(text: 'Correo'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPasswordTab(colorScheme, recoveryState),
            _buildEmailTab(colorScheme, recoveryState),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordTab(ColorScheme colorScheme, RecoveryState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _emailFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'CORREO ELECTRÓNICO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'tu@correo.com',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'El correo es requerido';
                if (!value.contains('@')) return 'Ingresa un correo válido';
                return null;
              },
            ),
            const SizedBox(height: 32),
            if (state is RecoveryLoading)
              Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
            else
              ElevatedButton(
                onPressed: () {
                  if (_emailFormKey.currentState!.validate()) {
                    ref
                        .read(recoveryProvider.notifier)
                        .resetPassword(_emailController.text.trim());
                  }
                },
                child: const Text('Enviar enlace de recuperación'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailTab(ColorScheme colorScheme, RecoveryState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _phoneFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'Ingresa tu número de teléfono registrado y te mostraremos el correo asociado a tu cuenta.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'TELÉFONO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('\u{1F1EA}\u{1F1E8}', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(
                        '+593',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                hintText: '983853525',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'El teléfono es requerido';
                final phoneRegex = RegExp(r'^9\d{8}$');
                if (!phoneRegex.hasMatch(value)) {
                  return 'Ingresa un número válido (9 dígitos)';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            if (state is RecoveryLoading)
              Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
            else
              ElevatedButton(
                onPressed: () {
                  if (_phoneFormKey.currentState!.validate()) {
                    final storagePhone = '0${_phoneController.text.trim()}';
                    ref
                        .read(recoveryProvider.notifier)
                        .findEmail(storagePhone);
                  }
                },
                child: const Text('Buscar mi correo'),
              ),
          ],
        ),
      ),
    );
  }
}
