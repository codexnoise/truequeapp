import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/item_entity.dart';

class ItemModel extends ItemEntity {
  const ItemModel({
    required super.id,
    required super.ownerId,
    required super.title,
    required super.description,
    required super.categoryId,
    required super.imageUrls,
    required super.desiredItem,
    required super.status,
  });

  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItemModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      categoryId: data['categoryId'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      desiredItem: data['desiredItem'] ?? '',
      status: data['status'] ?? 'available',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'imageUrls': imageUrls,
      'desiredItem': desiredItem,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}