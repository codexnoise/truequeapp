import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truequeapp/features/home/domain/usecases/update_item_usecase.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/domain/repositories/home_repository_impl.dart';
import '../../features/home/domain/usecases/add_item_usecase.dart';
import '../../features/home/domain/usecases/create_exchange_usecase.dart';
import '../../features/home/domain/usecases/delete_item_usecase.dart';
import '../../features/home/domain/usecases/get_items_usecase.dart';
import '../../features/home/domain/usecases/update_exchange_status_usecase.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../services/storage_service.dart';
import '../services/push_notification_service.dart';

// sl stands for Service Locator
final sl = GetIt.instance;

/// Initializes all the dependencies of the application.
Future<void> init() async {
  // Features - Auth

  // Use cases (Business Logic)
  // We use registerLazySingleton so they are only created when needed
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));

  setupHomeDependencies();
  setupNotificationDependencies();

  // Repositories (Contracts implementation)
  // We register the implementation linked to the abstract contract
  sl.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources (External communication)
  sl.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthRemoteDataSourceImpl(sl()),
  );

  // Core
  sl.registerLazySingleton(() => StorageService());

  sl.registerSingletonAsync<PushNotificationService>(() async {
    final service = PushNotificationService();
    await service.initialize();
    return service;
  });
  await sl.isReady<PushNotificationService>();

  // External (Third-party plugins)
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);
}


void setupHomeDependencies() {
  // Repository
  sl.registerLazySingleton<HomeRepository>(() => HomeRepositoryImpl());

  // UseCases
  sl.registerLazySingleton(() => GetItemsUseCase(sl()));
  sl.registerLazySingleton(() => AddItemUseCase(sl()));
  sl.registerLazySingleton(() => UpdateItemUseCase(sl()));
  sl.registerLazySingleton(() => DeleteItemUseCase(sl()));
  sl.registerLazySingleton(() => CreateExchangeUseCase(sl()));
  sl.registerLazySingleton(() => UpdateExchangeStatusUseCase(sl()));
}

void setupNotificationDependencies() {
  // Repository
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(sl()),
  );
}
