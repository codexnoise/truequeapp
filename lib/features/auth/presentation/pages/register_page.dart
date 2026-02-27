import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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
    // Formato Ecuador: 10 dígitos, empieza con 09
    final phoneRegex = RegExp(r'^09\d{8}$');
    if (!phoneRegex.hasMatch(value)) return 'Ingresa un número válido (ej: 0983853525)';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('CREAR CUENTA', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'NOMBRE Y APELLIDO',
                  hintText: 'Ej: Juan Pérez',
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'TELÉFONO',
                  hintText: '0983853525',
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'EMAIL'),
                validator: (value) => value == null || !value.contains('@') ? 'Email inválido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'CONTRASEÑA'),
                obscureText: true,
                validator: (value) => value == null || value.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 40),
              if (state is AuthLoading)
                const Center(child: CircularProgressIndicator(color: Colors.black))
              else
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ref.read(authProvider.notifier).register(
                        _emailController.text.trim(),
                        _passwordController.text.trim(),
                        _nameController.text.trim(),
                        _phoneController.text.trim(),
                      );
                    }
                  },
                  child: const Text('REGISTRARSE'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
