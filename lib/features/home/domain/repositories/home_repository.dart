import 'dart:io';

import '../entities/item_entity.dart';

abstract class HomeRepository {
  Stream<List<ItemEntity>> getItems();
  // New method for adding items
  Future<void> addItem(ItemEntity item, List<File> imageFiles);
}