import '../repositories/home_repository.dart';

class UpdateExchangeStatusUseCase {
  final HomeRepository repository;

  UpdateExchangeStatusUseCase(this.repository);

  Future<void> execute(String exchangeId, String status) {
    print('DEBUG USECASE: UpdateExchangeStatusUseCase.execute called');
    print('DEBUG USECASE: exchangeId: $exchangeId, status: $status');
    return repository.updateExchangeStatus(exchangeId, status);
  }
}
