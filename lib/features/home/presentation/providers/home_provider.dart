import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/item_entity.dart';
import '../../domain/usecases/get_items_usecase.dart';

/// Provider that listens to the stream of available barter items
final itemsStreamProvider = StreamProvider<List<ItemEntity>>((ref) {
  // We use the sl (Service Locator) to get the UseCase
  return sl<GetItemsUseCase>().execute();
});