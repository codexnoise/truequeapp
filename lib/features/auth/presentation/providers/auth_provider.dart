import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';

/// Represents the different states of the authentication flow
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);
}
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

/// Modern Notifier for Riverpod 3.x
class AuthNotifier extends Notifier<AuthState> {

  // Notice: In Notifiers, we don't use a standard constructor for dependencies.
  // We initialize the state in the build() method.
  @override
  AuthState build() {
    return AuthInitial();
  }

  Future<void> login(String email, String password) async {
    state = AuthLoading();
    try {
      // We get the UseCase from our Service Locator (GetIt)
      final user = await sl<LoginUseCase>().execute(email, password);

      if (user != null) {
        state = AuthAuthenticated(user);
      } else {
        state = const AuthError("Invalid credentials");
      }
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> register(String email, String password) async {
    state = AuthLoading();
    try {
      final user = await sl<RegisterUseCase>().execute(email, password);
      if (user != null) {
        state = AuthAuthenticated(user);
      } else {
        state = const AuthError("Registration failed");
      }
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  void logout() async {
    // Logic for sign out
    state = AuthInitial();
  }
}

/// Global provider using the new NotifierProvider
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});