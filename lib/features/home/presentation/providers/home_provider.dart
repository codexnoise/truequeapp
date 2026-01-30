import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/item_entity.dart';
import '../../domain/usecases/get_items_usecase.dart';

/// Provider that listens to the stream of available barter items
final itemsStreamProvider = StreamProvider<List<ItemEntity>>((ref) {
  // We use the sl (Service Locator) to get the UseCase
  return sl<GetItemsUseCase>().execute();
});

/// Provider that returns only items from other users (excludes current user's items)
final availableItemsProvider = Provider<AsyncValue<List<ItemEntity>>>((ref) {
  final authState = ref.watch(authProvider);
  final itemsAsync = ref.watch(itemsStreamProvider);

  return itemsAsync.whenData((items) {
    if (authState is AuthAuthenticated) {
      final currentUserId = authState.user.uid;
      return items.where((item) => item.ownerId != currentUserId).toList();
    }
    return items;
  });
});