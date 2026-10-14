class UserEntity {
  final String uid;
  final String email;
  final String? name;
  final String? phoneNumber;
  final String? photoUrl;

  /// Push "new item" opt-in. Missing in Firestore means true (existing users).
  final bool notifyNewItems;

  const UserEntity({
    required this.uid,
    required this.email,
    this.name,
    this.phoneNumber,
    this.photoUrl,
    this.notifyNewItems = true,
  });

  UserEntity copyWith({bool? notifyNewItems}) {
    return UserEntity(
      uid: uid,
      email: email,
      name: name,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
      notifyNewItems: notifyNewItems ?? this.notifyNewItems,
    );
  }

  List<Object?> get props => [uid, email, name, phoneNumber, photoUrl, notifyNewItems];
}
