import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../home/data/models/exchange_model.dart';
import '../../../notifications/domain/repositories/notification_repository.dart';
import '../../domain/repositories/message_repository.dart';
import '../models/message_model.dart';

class MessageRepositoryImpl implements MessageRepository {
  final FirebaseFirestore _firestore;
  final NotificationRepository _notificationRepository;

  MessageRepositoryImpl(this._firestore, this._notificationRepository);

  @override
  Stream<List<MessageModel>> getMessages(String exchangeId) {
    return _firestore
        .collection('exchanges')
        .doc(exchangeId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Future<void> sendMessage({
    required String exchangeId,
    required String senderId,
    required String senderName,
    required String text,
    required String receiverId,
  }) async {
    final message = MessageModel(
      id: '',
      exchangeId: exchangeId,
      senderId: senderId,
      senderName: senderName,
      text: text,
    );

    await _firestore
        .collection('exchanges')
        .doc(exchangeId)
        .collection('messages')
        .add(message.toMap());

    // Update last message info on the exchange document for conversation list
    await _firestore.collection('exchanges').doc(exchangeId).update({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
    });

    // Create notification for the receiver
    await _notificationRepository.createNotification(
      userId: receiverId,
      exchangeId: exchangeId,
      type: 'new_message',
      title: 'Nuevo mensaje de $senderName',
      body: text.length > 100 ? '${text.substring(0, 100)}...' : text,
    );
  }

  @override
  Stream<List<ExchangeModel>> getAcceptedExchanges(String userId) {
    // We need exchanges where the user is either sender or receiver AND status is accepted
    // Firestore doesn't support OR queries on different fields, so we merge two streams
    final sentStream = _firestore
        .collection('exchanges')
        .where('senderId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ExchangeModel.fromMap(doc.data(), doc.id))
            .toList());

    final receivedStream = _firestore
        .collection('exchanges')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ExchangeModel.fromMap(doc.data(), doc.id))
            .toList());

    // Merge both streams into one
    return sentStream.asyncExpand((sentList) {
      return receivedStream.map((receivedList) {
        final all = [...sentList, ...receivedList];
        // Sort by lastMessageAt or updatedAt descending
        all.sort((a, b) {
          final aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
          final bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
        return all;
      });
    });
  }
}
