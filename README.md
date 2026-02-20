# TruequeApp

TruequeApp is a Flutter mobile application for trading and donating items between users. It supports real-time exchange proposals, push notifications, and image uploads.

## Quick Links

- [Architecture](docs/architecture/overview.md)
- [Features](docs/features/)
- [Services](docs/services/)
- [Backend (Firebase Functions)](docs/backend/firebase_functions.md)
- [Setup Guide](docs/setup/getting_started.md)

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter |
| State Management | Riverpod |
| Navigation | GoRouter |
| Dependency Injection | GetIt |
| Authentication | Firebase Auth |
| Database | Cloud Firestore |
| Storage | Firebase Storage |
| Push Notifications | Firebase Messaging + flutter_local_notifications |
| Backend | Firebase Cloud Functions (Node.js 22) |
| Architecture | Clean Architecture (Feature-driven) |

## Project Structure

```
truequeapp/
├── lib/
│   ├── core/
│   │   ├── di/                  # Dependency injection (GetIt)
│   │   ├── router/              # Navigation (GoRouter)
│   │   └── services/            # Shared services (push notifications, storage)
│   ├── features/
│   │   ├── auth/                # Authentication feature
│   │   └── home/                # Items, exchanges, and home feed
│   ├── firebase_options.dart
│   └── main.dart
├── functions/                   # Firebase Cloud Functions (Node.js)
├── android/
├── ios/
└── docs/                        # Project documentation
```

## Getting Started

See the [Getting Started guide](docs/setup/getting_started.md) for full setup instructions.

```bash
flutter pub get
flutter run
```
