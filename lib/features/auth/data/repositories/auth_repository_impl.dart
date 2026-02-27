import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

/// Implementation of the AuthRepository that connects the Domain layer
/// with the Firebase Data Source.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<UserEntity?> get currentUser {
    // We map the UserModel stream from data source to a UserEntity stream for domain
    return remoteDataSource.userStream;
  }

  @override
  Future<UserEntity?> signIn(String email, String password) async {
    try {
      return await remoteDataSource.signIn(email, password);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserEntity?> signUp(String email, String password, String name, String phoneNumber) async {
    try {
      final userModel = await remoteDataSource.signUp(email, password, name, phoneNumber);
      if (userModel != null) {
        return UserEntity(
          uid: userModel.uid,
          email: userModel.email,
          name: userModel.name,
          phoneNumber: userModel.phoneNumber,
        );
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await remoteDataSource.signOut();
    } catch (e) {
      rethrow;
    }
  }
}
