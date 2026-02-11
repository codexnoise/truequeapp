import 'dart:io';
import '../entities/item_entity.dart';
import '../repositories/home_repository.dart';

class UpdateItemUseCase {
  final HomeRepository repository;

  UpdateItemUseCase(this.repository);

  Future<void> execute(ItemEntity item, List<String> existingUrls, List<File> newImageFiles) async {
    return await repository.updateItem(item, existingUrls, newImageFiles);
  }
}
