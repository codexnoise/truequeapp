import '../entities/notification_entity.dart';

abstract class NotificationRepository {
  Stream<List<NotificationEntity>> getUserNotifications(String userId);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
  Future<void> createNotification({
    required String userId,
    required String exchangeId,
    required String type,
    required String title,
    required String body,
  });
  Future<int> getUnreadCount(String userId);
}
