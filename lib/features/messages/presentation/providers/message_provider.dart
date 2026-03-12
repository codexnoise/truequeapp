import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/data/models/exchange_model.dart';
import '../../data/models/message_model.dart';
import '../../domain/repositories/message_repository.dart';
import '../../domain/usecases/send_message_usecase.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return di.sl<MessageRepository>();
});

final messagesStreamProvider =
    StreamProvider.autoDispose.family<List<MessageModel>, String>((ref, exchangeId) {
  final repository = ref.watch(messageRepositoryProvider);
  return repository.getMessages(exchangeId);
});

final conversationsStreamProvider =
    StreamProvider.autoDispose<List<ExchangeModel>>((ref) {
  final authState = ref.watch(authProvider);

  if (authState is! AuthAuthenticated) {
    return Stream.value([]);
  }

  final repository = ref.watch(messageRepositoryProvider);
  return repository.getAcceptedExchanges(authState.user.uid);
});

final exchangeStatusProvider =
    StreamProvider.autoDispose.family<String?, String>((ref, exchangeId) {
  return FirebaseFirestore.instance
      .collection('exchanges')
      .doc(exchangeId)
      .snapshots()
      .map((doc) => doc.data()?['status'] as String?);
});

final sendMessageProvider = Provider<SendMessageActions>((ref) {
  return SendMessageActions(di.sl<SendMessageUseCase>());
});

class SendMessageActions {
  final SendMessageUseCase _useCase;

  SendMessageActions(this._useCase);

  Future<void> send({
    required String exchangeId,
    required String senderId,
    required String senderName,
    required String text,
    required String receiverId,
  }) {
    return _useCase.execute(
      exchangeId: exchangeId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      receiverId: receiverId,
    );
  }
}
