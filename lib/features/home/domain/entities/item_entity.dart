class ItemEntity {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String categoryId;
  final List<String> imageUrls;
  final String desiredItem;
  final String status;

  const ItemEntity({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.imageUrls,
    required this.desiredItem,
    required this.status,
  });
}