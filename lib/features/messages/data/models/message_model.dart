import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String exchangeId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  const MessageModel({
    required this.id,
    required this.exchangeId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'exchangeId': exchangeId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      exchangeId: map['exchangeId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
