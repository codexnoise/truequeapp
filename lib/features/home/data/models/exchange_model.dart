import 'package:cloud_firestore/cloud_firestore.dart';

class ExchangeModel {
  final String exchangeId;
  final String senderId;
  final String receiverId;
  final String receiverItemId;
  final String? senderItemId;
  final String? message;
  final String status;
  final String type;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ExchangeModel({
    required this.exchangeId,
    required this.senderId,
    required this.receiverId,
    required this.receiverItemId,
    this.senderItemId,
    this.message,
    required this.status,
    required this.type,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'receiverItemId': receiverItemId,
      'senderItemId': senderItemId,
      'message': message,
      'status': status,
      'type': type,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ExchangeModel.fromMap(Map<String, dynamic> map, String id) {
    return ExchangeModel(
      exchangeId: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverItemId: map['receiverItemId'] ?? '',
      senderItemId: map['senderItemId'],
      message: map['message'],
      status: map['status'] ?? 'pending',
      type: map['type'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
