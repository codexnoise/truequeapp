import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/item_model.dart';
import '../entities/item_entity.dart';
import 'home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<ItemEntity>> getItems() {
    return _firestore
        .collection('items')
        .where('status', isEqualTo: 'available')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ItemModel.fromFirestore(doc))
              .toList();
        });
  }

  @override
  Future<void> addItem(ItemEntity item) async {
    // We convert the entity to a Model to use the toFirestore() helper
    final model = ItemModel(
      id: '', // Firestore generates this automatically
      ownerId: item.ownerId,
      title: item.title,
      description: item.description,
      categoryId: item.categoryId,
      imageUrls: item.imageUrls,
      desiredItem: item.desiredItem,
      status: 'available',
    );

    await _firestore.collection('items').add(model.toFirestore());
  }
}
