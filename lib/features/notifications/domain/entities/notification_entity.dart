class NotificationEntity {
  final String id;
  final String userId;
  final String exchangeId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.exchangeId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });
}
