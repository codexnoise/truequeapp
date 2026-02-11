import '../entities/item_entity.dart';
import '../repositories/home_repository.dart';

class DeleteItemUseCase {
  final HomeRepository repository;

  DeleteItemUseCase(this.repository);

  Future<void> execute(ItemEntity item) async {
    return await repository.deleteItem(item);
  }
}
