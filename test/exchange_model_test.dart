import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truequeapp/features/home/data/models/exchange_model.dart';

void main() {
  group('ExchangeModel', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        const model = ExchangeModel(
          id: 'ex1',
          senderId: 'user1',
          receiverId: 'user2',
          receiverItemId: 'item1',
          status: 'pending',
          type: 'exchange',
        );

        expect(model.id, 'ex1');
        expect(model.senderId, 'user1');
        expect(model.receiverId, 'user2');
        expect(model.receiverItemId, 'item1');
        expect(model.status, 'pending');
        expect(model.type, 'exchange');
        expect(model.senderItemId, isNull);
        expect(model.message, isNull);
        expect(model.parentExchangeId, isNull);
        expect(model.createdAt, isNull);
        expect(model.updatedAt, isNull);
      });

      test('creates instance with all optional fields', () {
        final now = DateTime.now();
        final model = ExchangeModel(
          id: 'ex1',
          senderId: 'user1',
          receiverId: 'user2',
          receiverItemId: 'item1',
          senderItemId: 'item2',
          message: 'Test message',
          status: 'pending',
          type: 'exchange',
          parentExchangeId: 'parent1',
          createdAt: now,
          updatedAt: now,
        );

        expect(model.senderItemId, 'item2');
        expect(model.message, 'Test message');
        expect(model.parentExchangeId, 'parent1');
        expect(model.createdAt, now);
        expect(model.updatedAt, now);
      });

      test('creates counter-offer with parentExchangeId', () {
        const model = ExchangeModel(
          id: 'counter1',
          senderId: 'user2',
          receiverId: 'user1',
          receiverItemId: 'item2',
          senderItemId: 'item3',
          status: 'pending',
          type: 'exchange',
          parentExchangeId: 'original_exchange_1',
        );

        expect(model.parentExchangeId, 'original_exchange_1');
        expect(model.parentExchangeId, isNotNull);
      });

      test('creates donation request without senderItemId', () {
        const model = ExchangeModel(
          id: 'don1',
          senderId: 'user1',
          receiverId: 'user2',
          receiverItemId: 'item1',
          status: 'pending',
          type: 'donation_request',
        );

        expect(model.type, 'donation_request');
        expect(model.senderItemId, isNull);
      });
    });

    group('fromMap', () {
      test('creates model from complete map', () {
        final timestamp = Timestamp.fromDate(DateTime(2025, 1, 1));
        final map = {
          'senderId': 'user1',
          'receiverId': 'user2',
          'receiverItemId': 'item1',
          'senderItemId': 'item2',
          'message': 'Hello',
          'status': 'pending',
          'type': 'exchange',
          'parentExchangeId': null,
          'createdAt': timestamp,
          'updatedAt': timestamp,
        };

        final model = ExchangeModel.fromMap(map, 'ex1');

        expect(model.id, 'ex1');
        expect(model.senderId, 'user1');
        expect(model.receiverId, 'user2');
        expect(model.receiverItemId, 'item1');
        expect(model.senderItemId, 'item2');
        expect(model.message, 'Hello');
        expect(model.status, 'pending');
        expect(model.type, 'exchange');
        expect(model.parentExchangeId, isNull);
        expect(model.createdAt, DateTime(2025, 1, 1));
        expect(model.updatedAt, DateTime(2025, 1, 1));
      });

      test('handles missing optional fields gracefully', () {
        final map = <String, dynamic>{
          'senderId': 'user1',
          'receiverId': 'user2',
          'receiverItemId': 'item1',
          'status': 'pending',
          'type': 'exchange',
        };

        final model = ExchangeModel.fromMap(map, 'ex1');

        expect(model.senderItemId, isNull);
        expect(model.message, isNull);
        expect(model.parentExchangeId, isNull);
        expect(model.createdAt, isNull);
        expect(model.updatedAt, isNull);
      });

      test('defaults status to pending when missing', () {
        final map = <String, dynamic>{
          'senderId': 'user1',
          'receiverId': 'user2',
          'receiverItemId': 'item1',
          'type': 'exchange',
        };

        final model = ExchangeModel.fromMap(map, 'ex1');
        expect(model.status, 'pending');
      });

      test('handles empty strings for required fields', () {
        final map = <String, dynamic>{};

        final model = ExchangeModel.fromMap(map, 'ex1');

        expect(model.senderId, '');
        expect(model.receiverId, '');
        expect(model.receiverItemId, '');
        expect(model.type, '');
      });

      test('parses parentExchangeId for counter-offers', () {
        final map = <String, dynamic>{
          'senderId': 'user2',
          'receiverId': 'user1',
          'receiverItemId': 'item2',
          'senderItemId': 'item3',
          'status': 'pending',
          'type': 'exchange',
          'parentExchangeId': 'original_ex_1',
        };

        final model = ExchangeModel.fromMap(map, 'counter1');

        expect(model.parentExchangeId, 'original_ex_1');
      });

      test('parses all valid statuses', () {
        final statuses = [
          'pending',
          'accepted',
          'rejected',
          'completed',
          'counter_offered',
          'closed',
          'cancelled',
        ];

        for (final status in statuses) {
          final map = <String, dynamic>{
            'senderId': 'user1',
            'receiverId': 'user2',
            'receiverItemId': 'item1',
            'status': status,
            'type': 'exchange',
          };

          final model = ExchangeModel.fromMap(map, 'ex_$status');
          expect(model.status, status, reason: 'Status "$status" should be parsed correctly');
        }
      });
    });

    group('toMap', () {
      test('serializes required fields correctly', () {
        const model = ExchangeModel(
          id: 'ex1',
          senderId: 'user1',
          receiverId: 'user2',
          receiverItemId: 'item1',
          status: 'pending',
          type: 'exchange',
        );

        final map = model.toMap();

        expect(map['senderId'], 'user1');
        expect(map['receiverId'], 'user2');
        expect(map['receiverItemId'], 'item1');
        expect(map['status'], 'pending');
        expect(map['type'], 'exchange');
      });

      test('serializes optional fields', () {
        const model = ExchangeModel(
          id: 'ex1',
          senderId: 'user1',
          receiverId: 'user2',
          receiverItemId: 'item1',
          senderItemId: 'item2',
          message: 'Hello',
          status: 'pending',
          type: 'exchange',
          parentExchangeId: 'parent1',
        );

        final map = model.toMap();

        expect(map['senderItemId'], 'item2');
        expect(map['message'], 'Hello');
        expect(map['parentExchangeId'], 'parent1');
      });

      test('does not include id in map', () {
        const model = ExchangeModel(
          id: 'ex1',
          senderId: 'user1',
          receiverId: 'user2',
          receiverItemId: 'item1',
          status: 'pending',
          type: 'exchange',
        );

        final map = model.toMap();
        expect(map.containsKey('id'), isFalse);
      });

      test('serializes null parentExchangeId for regular exchange', () {
        const model = ExchangeModel(
          id: 'ex1',
          senderId: 'user1',
          receiverId: 'user2',
          receiverItemId: 'item1',
          status: 'pending',
          type: 'exchange',
        );

        final map = model.toMap();
        expect(map['parentExchangeId'], isNull);
      });

      test('serializes parentExchangeId for counter-offer', () {
        const model = ExchangeModel(
          id: 'counter1',
          senderId: 'user2',
          receiverId: 'user1',
          receiverItemId: 'item2',
          senderItemId: 'item3',
          status: 'pending',
          type: 'exchange',
          parentExchangeId: 'ex1',
        );

        final map = model.toMap();
        expect(map['parentExchangeId'], 'ex1');
      });
    });
  });
}
