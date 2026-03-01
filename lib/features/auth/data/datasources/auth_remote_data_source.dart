import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel?> signIn(String email, String password);
  Future<UserModel?> signUp(String email, String password, String name, String phoneNumber);
  Future<void> signOut();
  Stream<UserModel?> get userStream;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRemoteDataSourceImpl(this._firebaseAuth, this._firestore);

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
        
        // Create user model
        final userModel = UserModel(
          uid: credential.user!.uid,
          email: credential.user!.email!,
          name: name,
          phoneNumber: phoneNumber,
        );
        
        // Save user data to Firestore 'users' collection
        await _firestore.collection('users').doc(credential.user!.uid).set(userModel.toMap());
        
        return userModel;
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
