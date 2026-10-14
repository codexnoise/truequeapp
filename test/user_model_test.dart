import 'package:flutter_test/flutter_test.dart';
import 'package:truequeapp/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel.notifyNewItems', () {
    test('fromMap: campo ausente → true (usuarios existentes)', () {
      final user = UserModel.fromMap({'uid': 'u1', 'email': 'a@b.com'});
      expect(user.notifyNewItems, isTrue);
    });

    test('fromMap: respeta false', () {
      final user = UserModel.fromMap({'uid': 'u1', 'email': 'a@b.com', 'notifyNewItems': false});
      expect(user.notifyNewItems, isFalse);
    });

    test('toMap incluye notifyNewItems: true por defecto (registro)', () {
      const user = UserModel(uid: 'u1', email: 'a@b.com');
      expect(user.toMap()['notifyNewItems'], isTrue);
    });

    test('copyWith cambia solo notifyNewItems', () {
      const user = UserModel(uid: 'u1', email: 'a@b.com', name: 'Ana');
      final updated = user.copyWith(notifyNewItems: false);
      expect(updated.notifyNewItems, isFalse);
      expect(updated.uid, 'u1');
      expect(updated.name, 'Ana');
    });
  });
}
