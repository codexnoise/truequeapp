import 'dart:io';

import '../entities/item_entity.dart';
import '../repositories/home_repository.dart';

class AddItemUseCase {
  final HomeRepository repository;

  AddItemUseCase(this.repository);

  // Execute the item upload process
  Future<void> execute(ItemEntity item, List<File> imageFiles) async {
    return await repository.addItem(item, imageFiles);
  }
}