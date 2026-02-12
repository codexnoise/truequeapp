import 'dart:io';

import '../entities/item_entity.dart';

abstract class HomeRepository {
  Stream<List<ItemEntity>> getItems();

  Future<void> addItem(ItemEntity item, List<File> imageFiles);

  Future<void> updateItem({
    required ItemEntity item,
    required List<String> existingUrls,
    required List<File> newImageFiles,
    required List<String> removedUrls,
  });

  Future<void> deleteItem(ItemEntity item);

  Future<bool> createExchangeRequest({
    required String senderId,
    required String receiverId,
    required String receiverItemId,
    String? senderItemId,
    String? message,
  });
}
