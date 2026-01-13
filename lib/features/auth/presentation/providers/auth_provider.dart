import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
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
  StreamSubscription<UserEntity?>? _userSubscription;

  // Notice: In Notifiers, we don't use a standard constructor for dependencies.
  // We initialize the state in the build() method.
  @override
  AuthState build() {
    // We clean up the subscription when the provider is disposed
    ref.onDispose(() => _userSubscription?.cancel());

    // Initialize the listener
    _listenToAuthState();

    // Start listening to the Firebase Stream
    _initAuthCheck();

    return AuthInitial();
  }

  void _initAuthCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final bool keepSession = prefs.getBool('keep_session') ?? false;

    // Listen to your reactive stream from the repository
    _userSubscription = sl<AuthRepository>().currentUser.listen((user) async {
      if (user != null && keepSession) {
        // User exists and wants to be remembered
        state = AuthAuthenticated(user);
      } else if (user != null && !keepSession) {
        // User exists but "Keep Session" is false: force logout
        logout();
      } else {
        // No user session found
        state = AuthInitial();
      }
    });
  }

  void _listenToAuthState() async {
    // 1. Check our local persistence flag first
    final prefs = await SharedPreferences.getInstance();
    final bool keepSession = prefs.getBool('keep_session') ?? false;

    // 2. Listen to the Stream you just created in the Repository
    _userSubscription = sl<AuthRepository>().currentUser.listen((user) async {
      if (user != null && keepSession) {
        // Only authenticate if there's a user AND the checkbox was checked
        state = AuthAuthenticated(user);
      } else if (user != null && !keepSession) {
        // If there's a user but NO "remember me", we force sign out
        logout();
      } else {
        // No user in Firebase
        state = AuthInitial();
      }
    });
  }

  Future<void> login(String email, String password, bool rememberMe) async {
    state = AuthLoading();
    try {
      // We get the UseCase from our Service Locator (GetIt)
      final user = await sl<LoginUseCase>().execute(email, password);

      if (user != null) {
        if (rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('keep_session', true);
        }

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('keep_session');
    state = AuthInitial();
  }
}

/// Global provider using the new NotifierProvider
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

/// Modern way to manage a simple boolean state in Riverpod 3.0
/// This replaces StateProvider and avoids legacy imports
class RememberMeNotifier extends Notifier<bool> {
  @override
  bool build() => false; // Initial state

  void toggle(bool? value) {
    state = value ?? false;
  }
}

/// Global provider for the Remember Me checkbox
final rememberMeProvider = NotifierProvider<RememberMeNotifier, bool>(() {
  return RememberMeNotifier();
});
