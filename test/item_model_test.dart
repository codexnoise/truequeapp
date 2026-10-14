import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truequeapp/features/home/data/models/item_model.dart';
import 'package:truequeapp/features/home/domain/entities/item_entity.dart';

void main() {
  group('ItemModel', () {
    final baseData = <String, dynamic>{
      'ownerId': 'owner1',
      'title': 'Cámara',
      'description': 'Usada',
      'categoryId': 'tech',
      'imageUrls': ['https://img/1.jpg'],
      'desiredItem': 'Un libro',
      'status': 'available',
    };

    test('fromMap lee createdAt desde un Timestamp', () {
      final date = DateTime(2026, 10, 1, 12, 30);
      final model = ItemModel.fromMap('item1', {
        ...baseData,
        'createdAt': Timestamp.fromDate(date),
      });

      expect(model.id, 'item1');
      expect(model.createdAt, date);
    });

    test('fromMap tolera createdAt ausente', () {
      final model = ItemModel.fromMap('item1', baseData);
      expect(model.createdAt, isNull);
    });

    test('fromMap ignora acquisitionDate de documentos viejos', () {
      final model = ItemModel.fromMap('item1', {
        ...baseData,
        'acquisitionDate': Timestamp.fromDate(DateTime(2020)),
      });
      expect(model.title, 'Cámara');
    });

    test('toFirestore no escribe createdAt ni acquisitionDate', () {
      final model = ItemModel.fromMap('item1', {
        ...baseData,
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
      });
      final map = model.toFirestore();

      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('acquisitionDate'), isFalse);
      expect(map['title'], 'Cámara');
      expect(map['status'], 'available');
    });

    test('fromEntity conserva createdAt', () {
      final date = DateTime(2026, 9, 1);
      final entity = ItemEntity(
        id: 'i',
        ownerId: 'o',
        title: 't',
        description: 'd',
        categoryId: 'tech',
        imageUrls: const [],
        desiredItem: 'x',
        status: 'available',
        createdAt: date,
      );
      expect(ItemModel.fromEntity(entity).createdAt, date);
    });
  });
}
