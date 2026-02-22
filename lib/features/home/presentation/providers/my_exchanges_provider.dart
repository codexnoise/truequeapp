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
