import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

sealed class ProfileState {
  const ProfileState();
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserEntity user;
  const ProfileLoaded(this.user);
}

class ProfileSaving extends ProfileState {
  final UserEntity user;
  const ProfileSaving(this.user);
}

class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
}

class ProfileNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() => ProfileInitial();

  Future<void> loadProfile(String uid) async {
    state = ProfileLoading();
    try {
      final user = await sl<AuthRepository>().getProfile(uid);
      if (user != null) {
        state = ProfileLoaded(user);
      } else {
        state = const ProfileError('No se encontró el perfil');
      }
    } catch (e) {
      state = ProfileError(e.toString());
    }
  }

  Future<void> updateProfile(String uid, {String? name, String? phoneNumber}) async {
    final current = state;
    if (current is ProfileLoaded) {
      state = ProfileSaving(current.user);
    }
    try {
      await sl<AuthRepository>().updateProfile(uid, name: name, phoneNumber: phoneNumber);
      await loadProfile(uid);
    } catch (e) {
      state = ProfileError(e.toString());
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await sl<AuthRepository>().changePassword(currentPassword, newPassword);
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(() {
  return ProfileNotifier();
});
