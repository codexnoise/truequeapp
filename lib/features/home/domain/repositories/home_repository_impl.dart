import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/models/item_model.dart';
import '../entities/item_entity.dart';
import 'home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<ItemEntity>> getItems() {
    return _firestore
        .collection('items')
        .where('status', isEqualTo: 'available')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ItemModel.fromFirestore(doc))
          .toList();
    });
  }

  @override
  Future<void> addItem(ItemEntity item, List<File> imageFiles) async {
    List<String> uploadedUrls = [];

    // 1. Upload all images first
    for (var file in imageFiles) {
      final url = await sl<StorageService>().uploadItemImage(file, item.ownerId);
      uploadedUrls.add(url);
    }

    // 2. Add item to Firestore with the new URLs
    final model = ItemModel.fromEntity(item).copyWith(imageUrls: uploadedUrls);
    await _firestore.collection('items').add(model.toFirestore());
  }
}
