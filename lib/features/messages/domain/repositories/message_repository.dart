import '../../data/models/message_model.dart';
import '../../../home/data/models/exchange_model.dart';

abstract class MessageRepository {
  Stream<List<MessageModel>> getMessages(String exchangeId);

  Future<void> sendMessage({
    required String exchangeId,
    required String senderId,
    required String senderName,
    required String text,
    required String receiverId,
  });

  Stream<List<ExchangeModel>> getAcceptedExchanges(String userId);
}
