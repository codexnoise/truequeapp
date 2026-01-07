import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use case to handle user login logic
class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  /// Executes the login process with [email] and [password]
  Future<UserEntity?> execute(String email, String password) {
    return repository.signIn(email, password);
  }
}