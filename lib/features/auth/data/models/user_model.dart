import 'package:firebase_auth/firebase_auth.dart' as firebase;
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.email,
    super.name,
    super.phoneNumber,
    super.photoUrl,
  });

  /// Factory to convert Firebase SDK User to our internal UserModel
  factory UserModel.fromFirebase(firebase.User user) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName,
      phoneNumber: user.phoneNumber,
      photoUrl: user.photoURL,
    );
  }

  /// Converts the model to a Map for Firestore storage if needed
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
    };
  }
}
