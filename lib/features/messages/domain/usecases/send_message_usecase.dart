import '../repositories/message_repository.dart';

class SendMessageUseCase {
  final MessageRepository repository;

  SendMessageUseCase(this.repository);

  Future<void> execute({
    required String exchangeId,
    required String senderId,
    required String senderName,
    required String text,
    required String receiverId,
  }) {
    return repository.sendMessage(
      exchangeId: exchangeId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      receiverId: receiverId,
    );
  }
}
