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

    // Escuchar errores para mostrar SnackBar
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: Colors.black),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: .center,
            crossAxisAlignment: .stretch,
            children: [
              const Text(
                'LOGIN',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
                textAlign: .center,
              ),
              const SizedBox(height: 48),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'EMAIL'),
                validator: (value) => value!.isEmpty ? 'Field required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'PASSWORD'),
                obscureText: true,
                validator: (value) => value!.length < 6 ? 'Too short' : null,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Checkbox(
                    // Watches the boolean value
                    value: ref.watch(rememberMeProvider),
                    activeColor: Colors.black,
                    onChanged: (value) {
                      // Uses the explicit method from the notifier
                      if (value != null) {
                        ref.read(rememberMeProvider.notifier).toggle(value);
                      }
                    },
                  ),
                  const Text('KEEP ME SIGNED IN', style: TextStyle(fontSize: 12, letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 16),
              if (state is AuthLoading)
                const Center(child: CircularProgressIndicator(color: Colors.black))
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
                  child: const Text('SIGN IN'),
                ),
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text('CREATE ACCOUNT', style: TextStyle(color: Colors.black54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}