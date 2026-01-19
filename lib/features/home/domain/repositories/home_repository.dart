import '../entities/item_entity.dart';

abstract class HomeRepository {
  Stream<List<ItemEntity>> getItems();
}