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
    super.createdAt,
  });

  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    return ItemModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  factory ItemModel.fromMap(String id, Map<String, dynamic> data) {
    return ItemModel(
      id: id,
      ownerId: data['ownerId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      categoryId: data['categoryId'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      desiredItem: data['desiredItem'] ?? '',
      status: data['status'] ?? 'available',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
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
      createdAt: entity.createdAt,
    );
  }

  ItemModel copyWith({
    String? id,
    List<String>? imageUrls,
    String? status,
  }) {
    return ItemModel(
      id: id ?? this.id,
      ownerId: ownerId,
      title: title,
      description: description,
      categoryId: categoryId,
      imageUrls: imageUrls ?? this.imageUrls,
      desiredItem: desiredItem,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  /// Fields shared by create and update. `createdAt` is written only on
  /// create (see HomeRepositoryImpl.addItem) so edits never overwrite it.
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'imageUrls': imageUrls,
      'desiredItem': desiredItem,
      'status': status,
    };
  }
}
