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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              const Text('REGISTER', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 48),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'EMAIL'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'PASSWORD'),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              if (state is AuthLoading)
                const Center(child: CircularProgressIndicator(color: Colors.black))
              else
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ref.read(authProvider.notifier).register(
                        _emailController.text.trim(),
                        _passwordController.text.trim(),
                      );
                    }
                  },
                  child: const Text('CREATE ACCOUNT'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}