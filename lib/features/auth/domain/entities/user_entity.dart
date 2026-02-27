class UserEntity {
  final String uid;
  final String email;
  final String? name;
  final String? phoneNumber;
  final String? photoUrl;

  const UserEntity({
    required this.uid,
    required this.email,
    this.name,
    this.phoneNumber,
    this.photoUrl,
  });

  List<Object?> get props => [uid, email, name, phoneNumber, photoUrl];
}
