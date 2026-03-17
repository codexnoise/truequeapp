import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState is AuthAuthenticated) {
        ref.read(profileProvider.notifier).loadProfile(authState.user.uid);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Converts Firestore phone (09XXXXXXXX) to display format (9XXXXXXXX)
  String _toDisplayPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    if (phone.startsWith('0')) return phone.substring(1);
    return phone;
  }

  /// Converts display phone (9XXXXXXXX) to Firestore format (09XXXXXXXX)
  String _toStoragePhone(String phone) {
    if (phone.isEmpty) return '';
    if (!phone.startsWith('0')) return '0$phone';
    return phone;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'El nombre es requerido';
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return 'Ingresa al menos nombre y apellido';
    for (var part in parts) {
      if (part.length < 3) return 'Cada palabra debe tener al menos 3 letras';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'El teléfono es requerido';
    final phoneRegex = RegExp(r'^9\d{8}$');
    if (!phoneRegex.hasMatch(value)) return 'Ingresa un número válido (9 dígitos)';
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;

    final storagePhone = _toStoragePhone(_phoneController.text.trim());

    ref.read(profileProvider.notifier).updateProfile(
      authState.user.uid,
      name: _nameController.text.trim(),
      phoneNumber: storagePhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<ProfileState>(profileProvider, (previous, next) {
      if (next is ProfileLoaded && previous is ProfileSaving) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Perfil actualizado'),
            backgroundColor: colorScheme.primary,
          ),
        );
      }
      if (next is ProfileError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    });

    if (profileState is ProfileLoaded && !_initialized) {
      _nameController.text = profileState.user.name ?? '';
      _phoneController.text = _toDisplayPhone(profileState.user.phoneNumber);
      _emailController.text = profileState.user.email;
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mi Perfil',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: _buildBody(profileState, colorScheme),
    );
  }

  Widget _buildBody(ProfileState state, ColorScheme colorScheme) {
    if (state is ProfileLoading) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    if (state is ProfileError && !_initialized) {
      return Center(
        child: Text('Error: ${state.message}',
            style: const TextStyle(color: Colors.red)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                backgroundColor: colorScheme.primary,
                radius: 40,
                child: Text(
                  _nameController.text.isNotEmpty
                      ? _nameController.text[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'NOMBRE Y APELLIDO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Ej: Juan Pérez',
              ),
              validator: _validateName,
            ),
            const SizedBox(height: 20),
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
                      const Text('🇪🇨', style: TextStyle(fontSize: 20)),
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
              validator: _validatePhone,
            ),
            const SizedBox(height: 20),
            Text(
              'EMAIL',
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
              enabled: false,
              decoration: InputDecoration(
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
              ),
            ),
            const SizedBox(height: 40),
            if (state is ProfileSaving)
              Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
            else
              ElevatedButton(
                onPressed: _save,
                child: const Text(
                  'GUARDAR',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Modo oscuro'),
              subtitle: Text(
                ref.watch(themeModeProvider) == ThemeMode.dark
                    ? 'Activado'
                    : 'Desactivado',
              ),
              value: ref.watch(themeModeProvider) == ThemeMode.dark,
              activeTrackColor: colorScheme.primary,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
