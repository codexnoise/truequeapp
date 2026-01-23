import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../home/domain/entities/item_entity.dart';
import '../../../home/domain/usecases/add_item_usecase.dart';

sealed class AddItemState {
  const AddItemState();
}

class AddItemInitial extends AddItemState {}

class AddItemLoading extends AddItemState {}

class AddItemSuccess extends AddItemState {}

class AddItemError extends AddItemState {
  final String message;
  const AddItemError(this.message);
}

class AddItemNotifier extends Notifier<AddItemState> {
  @override
  AddItemState build() {
    // Return initial state without side effects
    return AddItemInitial();
  }

  /// Handles the item creation logic
  Future<void> uploadItem(ItemEntity item, List<File> imageFiles) async {
    state = AddItemLoading();

    try {
      // Accessing UseCase via Service Locator as per your Auth architecture
      await sl<AddItemUseCase>().execute(item, imageFiles);

      state = AddItemSuccess();
    } catch (e) {
      state = AddItemError(e.toString());
    }
  }

  /// Resets the state for a new entry
  void reset() {
    state = AddItemInitial();
  }
}

/// Global provider for the add item flow
final addItemProvider = NotifierProvider<AddItemNotifier, AddItemState>(() {
  return AddItemNotifier();
});
