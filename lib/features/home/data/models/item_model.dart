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

  factory ItemModel.fromEntity(ItemEntity entity) {
    return ItemModel(
      id: entity.id,
      ownerId: entity.ownerId,
      title: entity.title,
      description: entity.description,
      categoryId: entity.categoryId,
      imageUrls: entity.imageUrls,
      desiredItem: entity.desiredItem,
      status: entity.status,
    );
  }

  ItemModel copyWith({String? id, List<String>? imageUrls, String? status}) {
    return ItemModel(
      id: id ?? this.id,
      ownerId: ownerId,
      title: title,
      description: description,
      categoryId: categoryId,
      imageUrls: imageUrls ?? this.imageUrls,
      desiredItem: desiredItem,
      status: status ?? this.status,
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
