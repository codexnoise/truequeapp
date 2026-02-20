import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/models/exchange_model.dart';
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

  @override
  Future<bool> createExchangeRequest({
    required String senderId,
    required String receiverId,
    required String receiverItemId,
    String? senderItemId,
    String? message,
  }) async {
    try {
      final type = senderItemId == null ? 'donation_request' : 'proposal';
      
      final data = {
        'senderId': senderId,
        'receiverId': receiverId,
        'receiverItemId': receiverItemId,
        'senderItemId': senderItemId,
        'message': message,
        'status': 'pending',
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'notificationSent': false,
      };

      await _firestore.collection('exchanges').add(data);
      return true;
    } on FirebaseException catch (e) {
      print('Firebase Error: ${e.message}');
      rethrow;
    } catch (e) {
      print('Error creating exchange request: $e');
      return false;
    }
  }

  @override
  Future<ExchangeModel?> getExchangeById(String exchangeId) async {
    try {
      final doc = await _firestore.collection('exchanges').doc(exchangeId).get();
      if (!doc.exists) return null;
      return ExchangeModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('Error getting exchange: $e');
      return null;
    }
  }

  @override
  Future<ItemEntity?> getItemById(String itemId) async {
    try {
      final doc = await _firestore.collection('items').doc(itemId).get();
      if (!doc.exists) return null;
      return ItemModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting item: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  @override
  Future<void> updateExchangeStatus(String exchangeId, String status) async {
    await _firestore.collection('exchanges').doc(exchangeId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> createCounterOffer({
    required String originalExchangeId,
    required String senderId,
    required String receiverId,
    required String receiverItemId,
    String? senderItemId,
    String? message,
  }) async {
    try {
      await _firestore.collection('exchanges').doc(originalExchangeId).update({
        'status': 'counter_offered',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final data = {
        'senderId': senderId,
        'receiverId': receiverId,
        'receiverItemId': receiverItemId,
        'senderItemId': senderItemId,
        'message': message,
        'status': 'pending',
        'type': senderItemId == null ? 'donation_request' : 'proposal',
        'parentExchangeId': originalExchangeId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'notificationSent': false,
      };

      await _firestore.collection('exchanges').add(data);
      return true;
    } catch (e) {
      print('Error creating counter offer: $e');
      return false;
    }
  }
}
