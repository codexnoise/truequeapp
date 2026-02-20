import '../repositories/home_repository.dart';

class UpdateExchangeStatusUseCase {
  final HomeRepository repository;

  UpdateExchangeStatusUseCase(this.repository);

  Future<void> execute(String exchangeId, String status) {
    return repository.updateExchangeStatus(exchangeId, status);
  }
}
