import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController(text: '');
  final _passwordController = TextEditingController(text: 'mortadela1');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: colorScheme.primary),
        );
      }
    });

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: .center,
            crossAxisAlignment: .stretch,
            children: [
              Text(
                'INICIAR SESIÓN',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2, color: colorScheme.onSurface),
                textAlign: .center,
              ),
              const SizedBox(height: 48),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'CORREO ELECTRÓNICO'),
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'CONTRASEÑA'),
                obscureText: true,
                validator: (value) => value!.length < 6 ? 'Muy corta' : null,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Checkbox(
                    value: ref.watch(rememberMeProvider),
                    activeColor: colorScheme.primary,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(rememberMeProvider.notifier).toggle(value);
                      }
                    },
                  ),
                  Text('MANTENER SESIÓN INICIADA', style: TextStyle(fontSize: 12, letterSpacing: 1, color: colorScheme.onSurface)),
                ],
              ),
              const SizedBox(height: 16),
              if (state is AuthLoading)
                Center(child: CircularProgressIndicator(color: colorScheme.primary))
              else
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ref.read(authProvider.notifier).login(
                        _emailController.text.trim(),
                        _passwordController.text.trim(),
                        ref.read(rememberMeProvider),
                      );
                    }
                  },
                  child: const Text('INICIAR SESIÓN'),
                ),
              TextButton(
                onPressed: () => context.push('/register'),
                child: Text('CREAR CUENTA', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.54))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
