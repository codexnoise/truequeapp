import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel?> signIn(String email, String password);
  Future<UserModel?> signUp(String email, String password, String name, String phoneNumber);
  Future<void> signOut();
  Stream<UserModel?> get userStream;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;

  AuthRemoteDataSourceImpl(this._firebaseAuth);

  @override
  Stream<UserModel?> get userStream {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      return firebaseUser != null ? UserModel.fromFirebase(firebaseUser) : null;
    });
  }

  @override
  Future<UserModel?> signIn(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send verification email manually
      // await credential.user?.sendEmailVerification();

      return credential.user != null ? UserModel.fromFirebase(credential.user!) : null;
    } catch (e) {
      throw Exception("Sign In Error: ${e.toString()}");
    }
  }

  @override
  Future<UserModel?> signUp(String email, String password, String name, String phoneNumber) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // Update Firebase User Profile (displayName)
        await credential.user!.updateDisplayName(name);
        // Note: For phoneNumber, usually you'd store it in Firestore as Firebase Auth 
        // phone number is for phone authentication. But for this requirement, we'll 
        // rely on the UserModel to represent it or store in Firestore if needed later.
        
        return UserModel(
          uid: credential.user!.uid,
          email: credential.user!.email!,
          name: name,
          phoneNumber: phoneNumber,
        );
      }
      return null;
    } catch (e) {
      throw Exception("Sign Up Error: ${e.toString()}");
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
