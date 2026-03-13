import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel?> signIn(String email, String password);
  Future<UserModel?> signUp(String email, String password, String name, String phoneNumber);
  Future<void> signOut();
  Stream<UserModel?> get userStream;
  Future<UserModel?> getProfile(String uid);
  Future<void> updateProfile(String uid, {String? name, String? phoneNumber});
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

  @override
  Future<UserModel?> getProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception("Get Profile Error: ${e.toString()}");
    }
  }

  @override
  Future<void> updateProfile(String uid, {String? name, String? phoneNumber}) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);
      }

      if (name != null) {
        await _firebaseAuth.currentUser?.updateDisplayName(name);
      }
    } catch (e) {
      throw Exception("Update Profile Error: ${e.toString()}");
    }
  }
}
