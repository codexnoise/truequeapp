import '../entities/user_entity.dart';

/// Contract that defines the authentication operations for the application.
abstract class AuthRepository {
  /// Signs in a user using their [email] and [password].
  ///
  /// Returns a [UserEntity] if successful, or null otherwise.
  Future<UserEntity?> signIn(String email, String password);

  /// Creates a new user account with the provided [email] and [password].
  ///
  /// Returns a [UserEntity] representing the newly created user.
  Future<UserEntity?> signUp(String email, String password);

  /// Signs out the currently authenticated user.
  Future<void> signOut();

  /// Notifies about changes in the user's authentication state.
  ///
  /// Emits the current [UserEntity] when a user logs in and null when they log out.
  Stream<UserEntity?> get currentUser;
}