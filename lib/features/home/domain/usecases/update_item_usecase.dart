import 'dart:io';
import '../entities/item_entity.dart';
import '../repositories/home_repository.dart';

class UpdateItemUseCase {
  final HomeRepository repository;

  UpdateItemUseCase(this.repository);

  Future<void> execute({
    required ItemEntity item,
    required List<String> existingUrls,
    required List<File> newImageFiles,
    required List<String> removedUrls,
  }) async {
    return await repository.updateItem(
      item: item,
      existingUrls: existingUrls,
      newImageFiles: newImageFiles,
      removedUrls: removedUrls,
    );
  }
}
