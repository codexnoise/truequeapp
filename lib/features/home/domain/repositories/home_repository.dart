import 'dart:io';

import '../entities/item_entity.dart';
import '../../data/models/exchange_model.dart';

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

  Stream<List<ExchangeModel>> getSentExchanges(String userId);

  Stream<List<ExchangeModel>> getReceivedExchanges(String userId);

  Future<ExchangeModel?> getExchangeById(String exchangeId);

  Future<ItemEntity?> getItemById(String itemId);

  Future<Map<String, dynamic>?> getUserById(String userId);

  Future<void> updateExchangeStatus(String exchangeId, String status);

  Future<bool> createCounterOffer({
    required String originalExchangeId,
    required String senderId,
    required String receiverId,
    required String receiverItemId,
    String? senderItemId,
    String? message,
  });
}
