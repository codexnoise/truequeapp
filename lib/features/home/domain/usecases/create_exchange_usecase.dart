import '../repositories/home_repository.dart';

class CreateExchangeUseCase {
  final HomeRepository repository;

  CreateExchangeUseCase(this.repository);

  Future<bool> execute({
    required String senderId,
    required String receiverId,
    required String receiverItemId,
    String? senderItemId,
    String? message,
  }) async {
    return await repository.createExchangeRequest(
      senderId: senderId,
      receiverId: receiverId,
      receiverItemId: receiverItemId,
      senderItemId: senderItemId,
      message: message,
    );
  }
}
