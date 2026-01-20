import '../entities/item_entity.dart';
import '../repositories/home_repository.dart';

class GetItemsUseCase {
  final HomeRepository repository;

  GetItemsUseCase(this.repository);

  /// Executes the request to get the stream of available items
  Stream<List<ItemEntity>> execute() {
    return repository.getItems();
  }
}