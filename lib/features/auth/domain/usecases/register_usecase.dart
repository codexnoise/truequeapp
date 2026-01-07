import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use case to handle user registration logic
class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  /// Executes the registration process with [email] and [password]
  Future<UserEntity?> execute(String email, String password) {
    return repository.signUp(email, password);
  }
}