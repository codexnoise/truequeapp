import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/models/exchange_model.dart';
import '../../domain/entities/item_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../../domain/usecases/update_exchange_status_usecase.dart';

class ExchangeDetailData {
  final ExchangeModel exchange;
  final ItemEntity receiverItem;
  final ItemEntity? senderItem;
  final Map<String, dynamic> senderUser;
  final Map<String, dynamic> receiverUser;

  const ExchangeDetailData({
    required this.exchange,
    required this.receiverItem,
    this.senderItem,
    required this.senderUser,
    required this.receiverUser,
  });
}

sealed class ExchangeDetailState {
  const ExchangeDetailState();
}

class ExchangeDetailInitial extends ExchangeDetailState {}

class ExchangeDetailLoading extends ExchangeDetailState {}

class ExchangeDetailLoaded extends ExchangeDetailState {
  final ExchangeDetailData data;
  const ExchangeDetailLoaded(this.data);
}

class ExchangeDetailActionLoading extends ExchangeDetailState {
  final ExchangeDetailData data;
  const ExchangeDetailActionLoading(this.data);
}

class ExchangeDetailSuccess extends ExchangeDetailState {
  final String message;
  const ExchangeDetailSuccess(this.message);
}

class ExchangeDetailError extends ExchangeDetailState {
  final String message;
  const ExchangeDetailError(this.message);
}

class ExchangeDetailNotifier extends Notifier<ExchangeDetailState> {
  @override
  ExchangeDetailState build() => ExchangeDetailInitial();

  Future<void> loadExchange(String exchangeId) async {
    state = ExchangeDetailLoading();
    try {
      final repo = sl<HomeRepository>();

      final exchange = await repo.getExchangeById(exchangeId);
      if (exchange == null) {
        state = const ExchangeDetailError('Intercambio no encontrado');
        return;
      }

      final results = await Future.wait([
        repo.getItemById(exchange.receiverItemId),
        exchange.senderItemId != null
            ? repo.getItemById(exchange.senderItemId!)
            : Future.value(null),
        repo.getUserById(exchange.senderId),
        repo.getUserById(exchange.receiverId),
      ]);

      final receiverItem = results[0] as ItemEntity?;
      final senderItem = results[1] as ItemEntity?;
      final senderUser = results[2] as Map<String, dynamic>?;
      final receiverUser = results[3] as Map<String, dynamic>?;

      if (receiverItem == null || senderUser == null || receiverUser == null) {
        state = const ExchangeDetailError('No se pudieron cargar los datos del intercambio');
        return;
      }

      state = ExchangeDetailLoaded(ExchangeDetailData(
        exchange: exchange,
        receiverItem: receiverItem,
        senderItem: senderItem,
        senderUser: senderUser,
        receiverUser: receiverUser,
      ));
    } catch (e) {
      state = ExchangeDetailError(e.toString());
    }
  }

  Future<void> acceptExchange(String exchangeId) async {
    print('DEBUG PROVIDER: acceptExchange called with exchangeId: $exchangeId');
    final current = state;
    if (current is! ExchangeDetailLoaded) {
      print('DEBUG PROVIDER: State is not ExchangeDetailLoaded, returning');
      return;
    }
    print('DEBUG PROVIDER: Setting state to ActionLoading');
    state = ExchangeDetailActionLoading(current.data);
    try {
      print('DEBUG PROVIDER: Calling UpdateExchangeStatusUseCase.execute');
      await sl<UpdateExchangeStatusUseCase>().execute(exchangeId, 'accepted');
      print('DEBUG PROVIDER: UpdateExchangeStatusUseCase completed successfully');
      state = const ExchangeDetailSuccess('¡Propuesta aceptada! Contacta al usuario para coordinar el intercambio.');
    } catch (e) {
      print('ERROR PROVIDER: acceptExchange failed: $e');
      state = ExchangeDetailError(e.toString());
    }
  }

  Future<void> rejectExchange(String exchangeId) async {
    final current = state;
    if (current is! ExchangeDetailLoaded) return;
    state = ExchangeDetailActionLoading(current.data);
    try {
      await sl<UpdateExchangeStatusUseCase>().execute(exchangeId, 'rejected');
      state = const ExchangeDetailSuccess('Propuesta rechazada.');
    } catch (e) {
      state = ExchangeDetailError(e.toString());
    }
  }

  Future<void> sendCounterOffer({
    required String originalExchangeId,
    required String senderId,
    required String receiverId,
    required String receiverItemId,
    String? senderItemId,
    String? message,
  }) async {
    final current = state;
    if (current is! ExchangeDetailLoaded) return;
    state = ExchangeDetailActionLoading(current.data);
    try {
      final success = await sl<HomeRepository>().createCounterOffer(
        originalExchangeId: originalExchangeId,
        senderId: senderId,
        receiverId: receiverId,
        receiverItemId: receiverItemId,
        senderItemId: senderItemId,
        message: message,
      );
      if (success) {
        state = const ExchangeDetailSuccess('Contraoferta enviada correctamente.');
      } else {
        state = const ExchangeDetailError('Error al enviar la contraoferta');
      }
    } catch (e) {
      state = ExchangeDetailError(e.toString());
    }
  }
}

final exchangeDetailProvider =
    NotifierProvider<ExchangeDetailNotifier, ExchangeDetailState>(() {
  return ExchangeDetailNotifier();
});
