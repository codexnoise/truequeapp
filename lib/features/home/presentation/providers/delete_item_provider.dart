import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../home/domain/entities/item_entity.dart';
import '../../../home/domain/usecases/delete_item_usecase.dart';

sealed class DeleteItemState {
  const DeleteItemState();
}

class DeleteItemInitial extends DeleteItemState {}

class DeleteItemLoading extends DeleteItemState {}

class DeleteItemSuccess extends DeleteItemState {}

class DeleteItemError extends DeleteItemState {
  final String message;
  const DeleteItemError(this.message);
}

class DeleteItemNotifier extends Notifier<DeleteItemState> {
  @override
  DeleteItemState build() {
    return DeleteItemInitial();
  }

  Future<void> deleteItem(ItemEntity item) async {
    state = DeleteItemLoading();
    try {
      await sl<DeleteItemUseCase>().execute(item);
      state = DeleteItemSuccess();
    } catch (e) {
      state = DeleteItemError(e.toString());
    }
  }
}

final deleteItemProvider = NotifierProvider<DeleteItemNotifier, DeleteItemState>(() {
  return DeleteItemNotifier();
});
