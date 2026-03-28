import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  void _showChangePasswordDialog(ColorScheme colorScheme) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        var isLoading = false;
        var obscureCurrent = true;
        var obscureNew = true;
        var obscureConfirm = true;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Cambiar contraseña',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Contraseña actual',
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa tu contraseña actual';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa la nueva contraseña';
                        }
                        if (value.length < 8) {
                          return 'Mínimo 8 caracteres';
                        }
                        if (value == currentPasswordController.text) {
                          return 'La nueva contraseña debe ser diferente a la actual';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña',
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                      validator: (value) {
                        if (value != newPasswordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!dialogFormKey.currentState!.validate()) return;
                          setDialogState(() => isLoading = true);
                          try {
                            await ref
                                .read(profileProvider.notifier)
                                .changePassword(
                                  currentPasswordController.text,
                                  newPasswordController.text,
                                );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: const Text('Contraseña actualizada'),
                                  backgroundColor: colorScheme.primary,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst('Exception: ', ''),
                                  ),
                                  backgroundColor: colorScheme.error,
                                ),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Cambiar'),
                ),
              ],
            );
          },
        );
      },
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
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
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]')),
              ],
              decoration: const InputDecoration(
                hintText: 'Ej. Juan Perez',
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
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
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
                hintText: 'Ej. 983853525',
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
            ListTile(
              leading: Icon(Icons.lock_outline, color: colorScheme.onSurface),
              title: const Text('Cambiar contraseña'),
              trailing: Icon(Icons.chevron_right, color: colorScheme.onSurface),
              onTap: () => _showChangePasswordDialog(colorScheme),
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: colorScheme.onSurface),
              title: const Text('Términos y Condiciones'),
              trailing: Icon(Icons.chevron_right, color: colorScheme.onSurface),
              onTap: () => context.push('/terms'),
            ),
            ListTile(
              leading: Icon(Icons.delete_forever, color: colorScheme.error),
              title: Text('Eliminar cuenta', style: TextStyle(color: colorScheme.error)),
              trailing: Icon(Icons.chevron_right, color: colorScheme.error),
              onTap: () => context.push('/delete-account'),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
