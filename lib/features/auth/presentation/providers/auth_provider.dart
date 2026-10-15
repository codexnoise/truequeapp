import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/delete_account_usecase.dart';
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

class AuthEmailNotVerified extends AuthState {
  final UserEntity user;

  const AuthEmailNotVerified(this.user);
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);
}

/// Modern Notifier for Riverpod 3.x
class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<UserEntity?>? _userSubscription;

  /// The first auth event is the session Firebase restored at app start.
  /// Later events with a user come from login()/register(), which set the
  /// state themselves.
  bool _initialAuthEventHandled = false;

  // Notice: In Notifiers, we don't use a standard constructor for dependencies.
  // We initialize the state in the build() method.
  @override
  AuthState build() {
    // We clean up the subscription when the provider is disposed
    ref.onDispose(() => _userSubscription?.cancel());

    // Initialize the listener
    _listenToAuthState();

    return AuthInitial();
  }

  void _listenToAuthState() {
    _userSubscription = sl<AuthRepository>().currentUser.listen((user) async {
      final isStartup = !_initialAuthEventHandled;
      _initialAuthEventHandled = true;

      // Read keep_session INSIDE the listener so it always has the latest value
      final prefs = await SharedPreferences.getInstance();
      final bool keepSession = prefs.getBool('keep_session') ?? false;

      if (user != null && keepSession) {
        final verified = await sl<AuthRepository>().checkEmailVerified();
        if (!verified) {
          state = AuthEmailNotVerified(user);
        } else {
          state = AuthAuthenticated(user);
          // Save FCM token in background, don't block authentication
          sl<PushNotificationService>().saveUserToken(user.uid);
        }
      } else if (user != null && !keepSession) {
        // Restored session without "remember me": sign out of Firebase too.
        // Only at startup — mid-session this is a login() in progress.
        if (isStartup) {
          await _signOut();
        }
      } else {
        // No user in Firebase
        state = AuthInitial();
      }
    });
  }

  Future<void> login(String email, String password, bool rememberMe) async {
    state = AuthLoading();
    try {
      final user = await sl<LoginUseCase>().execute(email, password);

      if (user != null) {
        if (rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('keep_session', true);
        }

        final verified = await sl<AuthRepository>().checkEmailVerified();
        if (!verified) {
          state = AuthEmailNotVerified(user);
        } else {
          // Save FCM token in background, don't block navigation
          sl<PushNotificationService>().saveUserToken(user.uid);
          state = AuthAuthenticated(user);
        }
      } else {
        state = const AuthError("Invalid credentials");
      }
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> register(String email, String password, String name, String phoneNumber) async {
    state = AuthLoading();
    try {
      // Set keep_session BEFORE the Firebase call to prevent the auth stream
      // listener from calling logout() when it detects the new user.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('keep_session', true);

      final user = await sl<RegisterUseCase>().execute(email, password, name, phoneNumber);
      if (user != null) {
        state = AuthEmailNotVerified(user);
      } else {
        await prefs.remove('keep_session');
        state = const AuthError("Registration failed");
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('keep_session');
      state = AuthError(e.toString());
    }
  }

  Future<bool> checkEmailVerification() async {
    try {
      final verified = await sl<AuthRepository>().checkEmailVerified();
      if (verified) {
        final currentState = state;
        if (currentState is AuthEmailNotVerified) {
          sl<PushNotificationService>().saveUserToken(currentState.user.uid);
          state = AuthAuthenticated(currentState.user);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> resendVerificationEmail() async {
    // Don't catch here — setting AuthError triggers a redirect to /login.
    // Let the caller handle errors in the UI.
    await sl<AuthRepository>().sendVerificationEmail();
  }

  void logout() async {
    // Remove FCM token on logout
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      await sl<PushNotificationService>().removeUserToken(currentState.user.uid);
    }

    await _signOut();
  }

  /// Ends the Firebase session (not just the app state), so the next person on
  /// the device isn't still authenticated as the previous user.
  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('keep_session');
    try {
      await sl<AuthRepository>().signOut();
    } catch (_) {
      // Even if Firebase fails, leave the app logged out.
    }
    state = AuthInitial();
  }

  Future<void> deleteAccount(String password) async {
    final previousState = state;
    state = AuthLoading();
    try {
      await sl<DeleteAccountUseCase>().execute(password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('keep_session');
      state = AuthInitial();
    } catch (e) {
      // Restore previous authenticated state to avoid redirect to /login
      state = previousState;
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
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
