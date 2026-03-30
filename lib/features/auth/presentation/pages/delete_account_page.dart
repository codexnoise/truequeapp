import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _confirmed = false;
  bool _isDeleting = false;
  bool _isCheckingExchanges = true;
  int _activeExchangeCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkActiveExchanges();
    });
  }

  Future<void> _checkActiveExchanges() async {
    final authState = ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;

    final uid = authState.user.uid;
    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      db.collection('exchanges')
          .where('senderId', isEqualTo: uid)
          .where('status', whereIn: ['accepted', 'received'])
          .get(),
      db.collection('exchanges')
          .where('receiverId', isEqualTo: uid)
          .where('status', whereIn: ['accepted', 'received'])
          .get(),
    ]);

    if (mounted) {
      setState(() {
        _activeExchangeCount = results[0].size + results[1].size;
        _isCheckingExchanges = false;
      });
    }
  }

  bool get _hasActiveExchanges => _activeExchangeCount > 0;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (!_formKey.currentState!.validate() || !_confirmed) return;

    setState(() => _isDeleting = true);

    try {
      await ref.read(authProvider.notifier).deleteAccount(
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Eliminar cuenta',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: _isCheckingExchanges
          ? Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            )
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_hasActiveExchanges) ...[
                        // Active exchanges blocking message
                        Card(
                          color: colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.swap_horiz,
                                  color: colorScheme.onErrorContainer,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No puedes eliminar tu cuenta',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tienes $_activeExchangeCount intercambio(s) en curso (aceptados o en proceso de entrega). Debes completarlos o cancelarlos antes de eliminar tu cuenta.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Warning card
                        Card(
                          color: colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: colorScheme.onErrorContainer,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '¿Estás seguro?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Al eliminar tu cuenta:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildWarningItem(
                                  'Se eliminarán todos tus artículos disponibles',
                                  colorScheme,
                                ),
                                _buildWarningItem(
                                  'Se cancelarán todos los intercambios pendientes',
                                  colorScheme,
                                ),
                                _buildWarningItem(
                                  'Se eliminarán tus datos personales',
                                  colorScheme,
                                ),
                                _buildWarningItem(
                                  'No podrás recuperar tu cuenta',
                                  colorScheme,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Password field
                        Text(
                          'CONFIRMA TU CONTRASEÑA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          enabled: !_isDeleting,
                          decoration: InputDecoration(
                            hintText: 'Ingresa tu contraseña',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa tu contraseña para confirmar';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Confirmation checkbox
                        CheckboxListTile(
                          value: _confirmed,
                          onChanged: _isDeleting
                              ? null
                              : (value) =>
                                  setState(() => _confirmed = value ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Entiendo que esta acción es irreversible y que todos mis datos serán eliminados.',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          activeColor: colorScheme.error,
                        ),
                        const SizedBox(height: 24),
                        // Delete button
                        if (_isDeleting)
                          Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                    color: colorScheme.error),
                                const SizedBox(height: 12),
                                Text(
                                  'Eliminando cuenta...',
                                  style:
                                      TextStyle(color: colorScheme.onSurface),
                                ),
                              ],
                            ),
                          )
                        else
                          ElevatedButton(
                            onPressed: _confirmed &&
                                    _passwordController.text.isNotEmpty
                                ? _deleteAccount
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.error,
                              foregroundColor: colorScheme.onError,
                              disabledBackgroundColor:
                                  colorScheme.error.withValues(alpha: 0.3),
                              disabledForegroundColor:
                                  colorScheme.onError.withValues(alpha: 0.5),
                            ),
                            child: const Text(
                              'ELIMINAR MI CUENTA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildWarningItem(String text, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.close,
            size: 16,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
