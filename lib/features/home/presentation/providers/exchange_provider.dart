import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/create_exchange_usecase.dart';

sealed class ExchangeState {
  const ExchangeState();
}

class ExchangeInitial extends ExchangeState {}
class ExchangeLoading extends ExchangeState {}
class ExchangeSuccess extends ExchangeState {}
class ExchangeError extends ExchangeState {
  final String message;
  const ExchangeError(this.message);
}

class ExchangeNotifier extends Notifier<ExchangeState> {
  @override
  ExchangeState build() => ExchangeInitial();

  Future<void> sendRequest({
    required String senderId,
    required String receiverId,
    required String receiverItemId,
    String? senderItemId,
    String? message,
  }) async {
    state = ExchangeLoading();
    try {
      final success = await sl<CreateExchangeUseCase>().execute(
        senderId: senderId,
        receiverId: receiverId,
        receiverItemId: receiverItemId,
        senderItemId: senderItemId,
        message: message,
      );
      
      if (success) {
        state = ExchangeSuccess();
      } else {
        state = const ExchangeError('Error al procesar la solicitud');
      }
    } catch (e) {
      state = ExchangeError(e.toString());
    }
  }
}

final exchangeProvider = NotifierProvider<ExchangeNotifier, ExchangeState>(() {
  return ExchangeNotifier();
});
