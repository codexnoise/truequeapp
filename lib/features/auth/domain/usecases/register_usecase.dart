import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use case to handle user registration logic
class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  /// Executes the registration process with [email], [password], [name], and [phoneNumber]
  Future<UserEntity?> execute(String email, String password, String name, String phoneNumber) {
    return repository.signUp(email, password, name, phoneNumber);
  }
}
