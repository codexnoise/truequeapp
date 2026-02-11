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

    for (var file in imageFiles) {
      final url = await sl<StorageService>().uploadItemImage(file, item.ownerId);
      uploadedUrls.add(url);
    }

    final model = ItemModel.fromEntity(item).copyWith(imageUrls: uploadedUrls);
    await _firestore.collection('items').add(model.toFirestore());
  }

  @override
  Future<void> updateItem({
    required ItemEntity item,
    required List<String> existingUrls,
    required List<File> newImageFiles,
    required List<String> removedUrls,
  }) async {
    // 1. Delete removed images from Storage
    for (var url in removedUrls) {
      await sl<StorageService>().deleteImage(url);
    }

    // 2. Upload new images
    List<String> finalUrls = List.from(existingUrls);
    for (var file in newImageFiles) {
      final url = await sl<StorageService>().uploadItemImage(file, item.ownerId);
      finalUrls.add(url);
    }

    // 3. Update Firestore document
    final model = ItemModel.fromEntity(item).copyWith(imageUrls: finalUrls);
    await _firestore.collection('items').doc(item.id).update(model.toFirestore());
  }

  @override
  Future<void> deleteItem(ItemEntity item) async {
    // 1. Delete all images from Storage
    for (var url in item.imageUrls) {
      await sl<StorageService>().deleteImage(url);
    }

    // 2. Delete document from Firestore
    await _firestore.collection('items').doc(item.id).delete();
  }
}
