# Architecture Overview

TruequeApp follows **Clean Architecture** principles organized by feature modules. Each feature is self-contained and divided into three layers: `data`, `domain`, and `presentation`.

## Diagram

```
┌─────────────────────────────────────────────────────┐
│                   Presentation Layer                 │
│         (Pages, Widgets, Riverpod Providers)         │
└────────────────────────┬────────────────────────────┘
                         │ calls
┌────────────────────────▼────────────────────────────┐
│                    Domain Layer                      │
│          (Use Cases, Entities, Repository            │
│                    Contracts)                        │
└────────────────────────┬────────────────────────────┘
                         │ implemented by
┌────────────────────────▼────────────────────────────┐
│                     Data Layer                       │
│     (Repository Impl, Data Sources, Models)          │
│              Firebase / External APIs                │
└─────────────────────────────────────────────────────┘
```

## Layers

### Presentation
- **Pages**: Full-screen UI widgets (`ConsumerStatefulWidget` / `ConsumerWidget`)
- **Providers**: Riverpod `StateNotifier` classes that manage UI state
- **Widgets**: Reusable UI components scoped to a feature

### Domain
- **Entities**: Pure Dart classes representing business objects (no framework dependencies)
- **Repository contracts**: Abstract classes defining what data operations are available
- **Use cases**: Single-responsibility classes encapsulating one business action (e.g., `LoginUseCase`, `CreateExchangeUseCase`)

### Data
- **Repository implementations**: Concrete classes implementing domain contracts
- **Data sources**: Classes that communicate directly with Firebase (Firestore, Auth, Storage)
- **Models**: Data Transfer Objects (DTOs) that extend entities and add serialization logic (`fromMap`, `toMap`)

## Dependency Flow

```
Presentation → Domain ← Data
```

- The **domain** layer has zero dependencies on Flutter or Firebase.
- The **data** layer depends on domain (implements its contracts).
- The **presentation** layer depends on domain (calls use cases via providers).

## Dependency Injection

All dependencies are wired in [`lib/core/di/injection_container.dart`](../../lib/core/di/injection_container.dart) using **GetIt** as a service locator. Dependencies are registered as `lazySingleton` so they are only instantiated when first requested.

```dart
sl.registerLazySingleton(() => LoginUseCase(sl()));
sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(remoteDataSource: sl()));
```

## State Management

**Riverpod 3.x** is used throughout the presentation layer. Each feature exposes a `Notifier` provider that holds a sealed state class:

```dart
// Example sealed states
sealed class AuthState { const AuthState(); }
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState { final UserEntity user; const AuthAuthenticated(this.user); }
class AuthError extends AuthState { final String message; const AuthError(this.message); }

// Notifier (replaces StateNotifier)
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() { ... }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier());
```

UI widgets watch these providers and rebuild when state changes.

## Navigation

**GoRouter** handles all navigation via `routerProvider` in [`lib/core/router/app_router.dart`](../../lib/core/router/app_router.dart). It automatically redirects based on `AuthState`:

| State | Redirect |
|---|---|
| `AuthLoading` | `/loading` (full-screen spinner while Firebase resolves session) |
| `AuthAuthenticated` | `/home` |
| `AuthInitial` / `AuthError` | `/login` |

### Routes

| Path | Page | Protected |
|---|---|---|
| `/loading` | Loading screen | — |
| `/login` | `LoginPage` | — |
| `/register` | `RegisterPage` | — |
| `/home` | `HomePage` | ✓ |
| `/my-items` | `MyItemsPage` | ✓ |
| `/item-detail` | `ItemDetailPage` | ✓ |
| `/add-item` | `AddItemPage` | ✓ |
| `/edit-item` | `EditItemPage` | ✓ |
| `/exchange-detail` | `ExchangeDetailPage` | ✓ |

## Directory Structure

```
lib/
├── core/
│   ├── di/
│   │   └── injection_container.dart   # GetIt wiring
│   ├── router/
│   │   └── app_router.dart            # GoRouter + auth redirect
│   └── services/
│       ├── push_notification_service.dart
│       └── storage_service.dart
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── pages/
│   │       ├── providers/
│   │       └── widgets/
│   └── home/
│       ├── data/
│       ├── domain/
│       └── presentation/
├── firebase_options.dart
└── main.dart
```

## Firestore Collections

| Collection | Document fields | Notes |
|---|---|---|
| `items` | `id`, `ownerId`, `title`, `description`, `categoryId`, `imageUrls[]`, `desiredItem`, `status` | `status: 'available'` for active items |
| `exchanges` | `senderId`, `receiverId`, `receiverItemId`, `senderItemId?`, `message?`, `status`, `type`, `createdAt`, `updatedAt`, `notificationSent`, `parentExchangeId?` | `type`: `'proposal'` or `'donation_request'` |
| `users` | `fcmToken?`, `tokenUpdatedAt?` | Written by `PushNotificationService` on login |

### Exchange `status` values

| Value | Meaning |
|---|---|
| `pending` | Awaiting receiver response |
| `accepted` | Receiver accepted |
| `rejected` | Receiver rejected |
| `completed` | Both parties marked as done |
| `counter_offered` | Receiver sent a counter-offer (original exchange superseded) |

### Item `categoryId` values

`tech`, `fashion`, `home`, `books`, `music`, `general`
