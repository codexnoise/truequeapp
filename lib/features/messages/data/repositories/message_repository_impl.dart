import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

    // Critical: save the message — if this fails, let the error propagate
    await _firestore
        .collection('exchanges')
        .doc(exchangeId)
        .collection('messages')
        .add(message.toMap());

    // Run metadata update and notification creation independently
    // so a failure in one does not block the other
    await Future.wait([
      _updateExchangeMetadata(exchangeId, text, senderId),
      _createMessageNotification(receiverId, exchangeId, senderId, senderName, text),
    ]);
  }

  Future<void> _updateExchangeMetadata(String exchangeId, String text, String senderId) async {
    try {
      await _firestore.collection('exchanges').doc(exchangeId).update({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
      });
    } catch (e) {
      debugPrint('Error updating exchange metadata: $e');
    }
  }

  Future<void> _createMessageNotification(
    String receiverId,
    String exchangeId,
    String senderId,
    String senderName,
    String text,
  ) async {
    try {
      await _notificationRepository.createNotification(
        userId: receiverId,
        exchangeId: exchangeId,
        type: 'new_message',
        title: 'Nuevo mensaje de $senderName',
        body: text.length > 100 ? '${text.substring(0, 100)}...' : text,
        senderId: senderId,
        senderName: senderName,
      );
    } catch (e) {
      debugPrint('Error creating message notification: $e');
    }
  }

  @override
  Stream<List<ExchangeModel>> getAcceptedExchanges(String userId) {
    // We need exchanges where the user is either sender or receiver AND status is accepted or received
    // Firestore doesn't support OR queries on different fields, so we merge two streams
    const statuses = ['accepted', 'received'];
    final sentStream = _firestore
        .collection('exchanges')
        .where('senderId', isEqualTo: userId)
        .where('status', whereIn: statuses)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ExchangeModel.fromMap(doc.data(), doc.id))
            .toList());

    final receivedStream = _firestore
        .collection('exchanges')
        .where('receiverId', isEqualTo: userId)
        .where('status', whereIn: statuses)
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
