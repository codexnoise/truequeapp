import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel?> signIn(String email, String password);
  Future<UserModel?> signUp(String email, String password, String name, String phoneNumber);
  Future<void> signOut();
  Stream<UserModel?> get userStream;
  Future<UserModel?> getProfile(String uid);
  Future<void> updateProfile(String uid, {String? name, String? phoneNumber});
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> sendPasswordResetEmail(String email);
  Future<String?> findEmailByPhone(String phoneNumber);
  Future<void> sendVerificationEmail();
  Future<bool> checkEmailVerified();
  bool get isEmailVerified;
  Future<void> deleteAccount(String password);
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

        // Send verification email
        await credential.user!.sendEmailVerification();

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

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No hay usuario autenticado');
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    try {
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('La contraseña actual es incorrecta');
        case 'weak-password':
          throw Exception('La nueva contraseña es muy débil (mínimo 6 caracteres)');
        default:
          throw Exception('Error al cambiar contraseña: ${e.message}');
      }
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No existe una cuenta con ese correo');
        case 'invalid-email':
          throw Exception('El correo ingresado no es válido');
        default:
          throw Exception('Error al enviar correo: ${e.message}');
      }
    }
  }

  @override
  bool get isEmailVerified => _firebaseAuth.currentUser?.emailVerified ?? false;

  @override
  Future<void> sendVerificationEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado');
    await user.sendEmailVerification();
  }

  @override
  Future<bool> checkEmailVerified() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }

  @override
  Future<String?> findEmailByPhone(String phoneNumber) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final email = query.docs.first.data()['email'] as String?;
      if (email == null) return null;

      final parts = email.split('@');
      final name = parts[0];
      final masked = name.length > 1
          ? '${name[0]}***${name[name.length - 1]}'
          : '${name[0]}***';
      return '$masked@${parts[1]}';
    } catch (e) {
      throw Exception('Error al buscar cuenta: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteAccount(String password) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No hay usuario autenticado');
    }

    // Re-authenticate before deletion
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );

    try {
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('La contraseña es incorrecta');
        default:
          throw Exception('Error de autenticación: ${e.message}');
      }
    }

    // Call Cloud Function to delete all user data
    try {
      await FirebaseFunctions.instance
          .httpsCallable('deleteUserAccount')
          .call();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Error al eliminar la cuenta');
    }

    // Sign out locally
    await _firebaseAuth.signOut();
  }
}
