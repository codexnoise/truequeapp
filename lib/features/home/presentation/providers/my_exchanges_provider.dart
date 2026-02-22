import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/models/exchange_model.dart';
import '../../domain/repositories/home_repository.dart';

final sentExchangesProvider =
    StreamProvider.family<List<ExchangeModel>, String>((ref, userId) {
  return sl<HomeRepository>().getSentExchanges(userId);
});

final receivedExchangesProvider =
    StreamProvider.family<List<ExchangeModel>, String>((ref, userId) {
  return sl<HomeRepository>().getReceivedExchanges(userId);
});

/// Returns the existing exchange for [senderId] targeting [receiverItemId], or null if none.
final existingExchangeForItemProvider = StreamProvider.family<
    ExchangeModel?,
    ({String senderId, String receiverItemId})>((ref, args) {
  return sl<HomeRepository>()
      .getSentExchanges(args.senderId)
      .map((exchanges) {
    try {
      return exchanges.firstWhere(
        (e) =>
            e.receiverItemId == args.receiverItemId &&
            (e.status == 'pending' || e.status == 'accepted'),
      );
    } catch (_) {
      return null;
    }
  });
});
