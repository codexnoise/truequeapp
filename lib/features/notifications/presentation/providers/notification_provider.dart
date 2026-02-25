import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../../../core/di/injection_container.dart' as di;

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return di.sl<NotificationRepository>();
});

final notificationsStreamProvider = StreamProvider.autoDispose<List<NotificationEntity>>((ref) {
  final authState = ref.watch(authProvider);
  
  if (authState is! AuthAuthenticated) {
    return Stream.value([]);
  }
  
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUserNotifications(authState.user.uid);
});

final unreadCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final authState = ref.watch(authProvider);
  
  if (authState is! AuthAuthenticated) {
    yield 0;
    return;
  }
  
  final repository = ref.watch(notificationRepositoryProvider);
  await for (final notifications in repository.getUserNotifications(authState.user.uid)) {
    yield notifications.where((n) => !n.isRead).length;
  }
});

final notificationActionsProvider = Provider<NotificationActions>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationActions(repository);
});

class NotificationActions {
  final NotificationRepository _repository;

  NotificationActions(this._repository);

  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _repository.markAllAsRead(userId);
  }
}
