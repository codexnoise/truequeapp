import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/repositories/auth_repository.dart';

sealed class RecoveryState {
  const RecoveryState();
}

class RecoveryInitial extends RecoveryState {}

class RecoveryLoading extends RecoveryState {}

class RecoverySuccess extends RecoveryState {
  final String message;
  const RecoverySuccess(this.message);
}

class RecoveryError extends RecoveryState {
  final String message;
  const RecoveryError(this.message);
}

class RecoveryNotifier extends Notifier<RecoveryState> {
  @override
  RecoveryState build() => RecoveryInitial();

  Future<void> resetPassword(String email) async {
    state = RecoveryLoading();
    try {
      await sl<AuthRepository>().sendPasswordResetEmail(email);
      state = const RecoverySuccess('Revisa tu correo para restablecer tu contraseña');
    } catch (e) {
      state = RecoveryError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> findEmail(String phoneNumber) async {
    state = RecoveryLoading();
    try {
      final maskedEmail = await sl<AuthRepository>().findEmailByPhone(phoneNumber);
      if (maskedEmail != null) {
        state = RecoverySuccess('Tu correo es: $maskedEmail');
      } else {
        state = const RecoveryError('No se encontró una cuenta con ese número');
      }
    } catch (e) {
      state = RecoveryError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void reset() {
    state = RecoveryInitial();
  }
}

final recoveryProvider = NotifierProvider<RecoveryNotifier, RecoveryState>(() {
  return RecoveryNotifier();
});
