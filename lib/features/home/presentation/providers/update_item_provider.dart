import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../home/domain/entities/item_entity.dart';
import '../../../home/domain/usecases/update_item_usecase.dart';

sealed class UpdateItemState {
  const UpdateItemState();
}

class UpdateItemInitial extends UpdateItemState {}

class UpdateItemLoading extends UpdateItemState {}

class UpdateItemSuccess extends UpdateItemState {}

class UpdateItemError extends UpdateItemState {
  final String message;
  const UpdateItemError(this.message);
}

class UpdateItemNotifier extends Notifier<UpdateItemState> {
  @override
  UpdateItemState build() {
    return UpdateItemInitial();
  }

  Future<void> updateItem({
    required ItemEntity item,
    required List<String> existingUrls,
    required List<File> newImageFiles,
    required List<String> removedUrls,
  }) async {
    state = UpdateItemLoading();
    try {
      await sl<UpdateItemUseCase>().execute(
        item: item,
        existingUrls: existingUrls,
        newImageFiles: newImageFiles,
        removedUrls: removedUrls,
      );
      state = UpdateItemSuccess();
    } catch (e) {
      state = UpdateItemError(e.toString());
    }
  }

  void reset() {
    state = UpdateItemInitial();
  }
}

final updateItemProvider = NotifierProvider<UpdateItemNotifier, UpdateItemState>(() {
  return UpdateItemNotifier();
});
