# TruequeApp — Contexto para Claude Code

App Flutter de **trueque y donación** entre particulares. Permite publicar artículos, proponer intercambios, conversar por chat y recibir notificaciones push. Sin transacciones de dinero — solo intercambio directo.

- **Mercado objetivo**: Colombia, Ecuador, Perú (Spanish-speaking LATAM)
- **App ID Android**: `com.truequeapp.truequeapp`
- **Firebase project**: `truequeapp-c2f82` (funciones: `us-central1`, salvo `notifyNewItem` en `southamerica-west1`; Firestore está en `southamerica-west1`)
- **Estado actual**: publicada en Producción en Play Store (Android). iOS aún no está en App Store.

---

## Stack tecnológico

### Core
- **Flutter** 3.44.9 (pinneado con FVM en `.fvmrc`), **Dart** ^3.12
- **Riverpod 3.1** (state management)
- **GetIt 9.2** (dependency injection, expuesto como `sl`)
- **go_router 17.0** (routing declarativo)

### Firebase
- `firebase_core` 4.15.0 — bootstrap
- `firebase_auth` 6.7.0 — auth email/password + verificación de email
- `cloud_firestore` 6.10.0 — DB principal
- `firebase_storage` 13.6.0 — imágenes de items y avatares
- `firebase_messaging` 16.7.0 — push notifications (FCM)
- `cloud_functions` 6.5.0 — invocar Cloud Functions
- `firebase_analytics` 12.6.0 — telemetría (solo screen tracking automático)

### Otros
- `shared_preferences` 2.5.4 — `keep_session`, configs locales
- `image_picker` 1.2.1 — cámara / galería para publicar items
- `flutter_local_notifications` 20.1.0 — notificaciones foreground
- `flutter_dotenv` 5.2.1 — variables de entorno (archivo `.env`)
- `timeago` 3.7.0 — formato de fechas relativas
- **iOS deps**: Swift Package Manager (desde Flutter 3.44). CocoaPods fue retirado del proyecto; no correr `pod install`. En Xcode abrir siempre `ios/Runner.xcworkspace` (nunca `Runner.xcodeproj` directo): hay dos `Package.resolved` versionados (workspace y proyecto) y abrir el `.xcodeproj` los haría divergir.
- **FVM**: `fvm install` tras clonar instala la versión de `.fvmrc`. `flutter` sin `fvm` usa el global de la máquina y puede no coincidir.

---

## Arquitectura: Clean Architecture por feature

```
lib/
├── main.dart                          # bootstrap: dotenv, Firebase, DI, runApp
├── firebase_options.dart              # generado por FlutterFire CLI
├── core/
│   ├── di/injection_container.dart    # GetIt setup (sl)
│   ├── router/app_router.dart         # GoRouter + redirect basado en auth
│   ├── theme/                         # AppTheme.light/dark + ThemeProvider
│   ├── services/
│   │   ├── push_notification_service.dart
│   │   ├── storage_service.dart       # subida de imágenes
│   │   └── connectivity_service.dart
│   └── widgets/
│       └── connectivity_banner.dart
└── features/
    ├── auth/        # login, registro, recovery, verify-email, profile, delete-account
    ├── home/        # listado items, my-items, add-item, edit-item, item-detail, exchange-detail
    ├── messages/    # conversations, chat
    ├── notifications/  # listado, badge unread
    ├── legal/       # terms & conditions
    └── splash/      # pantalla inicial
```

### Capas por feature (estándar)

```
features/<feature>/
├── data/
│   ├── datasources/    # *_remote_data_source.dart (Firebase)
│   ├── models/         # *_model.dart (serialización Firestore)
│   └── repositories/   # *_repository_impl.dart (implementan los contratos)
├── domain/
│   ├── entities/       # *_entity.dart (objetos puros del dominio)
│   ├── repositories/   # *_repository.dart (abstract)
│   └── usecases/       # *_usecase.dart (una clase por acción)
└── presentation/
    ├── pages/          # *_page.dart (widgets de pantalla)
    ├── providers/      # *_provider.dart (Notifiers de Riverpod)
    └── widgets/        # widgets reutilizables del feature
```

**Flujo de llamada:** Page → Provider (Notifier) → UseCase → Repository (abstract) → RepositoryImpl → DataSource → Firebase.

---

## Dependency Injection (GetIt)

Archivo: `lib/core/di/injection_container.dart`

Se expone como `sl` (service locator). Patrón estándar:
```dart
sl.registerLazySingleton(() => FirebaseAuth.instance);
sl.registerLazySingleton(() => LoginUseCase(sl()));
sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(remoteDataSource: sl()));
```

`PushNotificationService` se registra con `registerSingletonAsync` porque requiere `await initialize()`.

---

## Routing (go_router)

Archivo: `lib/core/router/app_router.dart`

- `refreshListenable` bridge entre Riverpod `authProvider` y GoRouter.
- Redirect basado en `AuthState`:
  - `AuthEmailNotVerified` → `/verify-email`
  - `AuthAuthenticated` → `/home`
  - Otros → `/login`
  - `/splash` y `/terms` quedan exentos.
- Observers: `FirebaseAnalyticsObserver` para screen tracking automático.

### Rutas registradas

`/splash`, `/login`, `/register`, `/recovery`, `/verify-email`, `/home`, `/my-items`, `/item-detail`, `/add-item`, `/edit-item`, `/exchange-detail`, `/notifications`, `/conversations`, `/profile`, `/chat`, `/delete-account`, `/terms`.

La mayoría tiene `name:` definido — útil para `context.pushNamed(...)` y para nombres limpios de eventos `screen_view` en Analytics.

---

## State management (Riverpod 3)

- **Notifier modernos** (sin `StateProvider` legacy).
- Providers globales viven junto al feature: `auth_provider.dart`, `home_provider.dart`, `notification_provider.dart`, etc.
- Estados sealed para flujos complejos: `AuthState` → `AuthInitial | AuthLoading | AuthAuthenticated | AuthEmailNotVerified | AuthError`.

---

## Modelo de datos (Firestore)

### Colecciones

| Colección | Campos clave |
|---|---|
| `users/{uid}` | `uid, email, name, phoneNumber, photoUrl, fcmToken, tokenUpdatedAt, notifyNewItems` (bool; ausente = `true`) |
| `items/{id}` | `ownerId, title, description, categoryId, imageUrls[], desiredItem, status, createdAt` (`createdAt` solo se escribe al crear) |
| `exchanges/{id}` | `senderId, receiverId, senderItemId, receiverItemId, message, status, type, parentExchangeId, createdAt, updatedAt, lastMessage, lastMessageAt, lastMessageSenderId, notificationSent, cancelledReason` |
| `exchanges/{id}/messages/{msgId}` | `senderId, senderName, text, createdAt` (subcolección) |
| `notifications/{id}` | `userId, exchangeId, type, title, body, isRead, createdAt, senderId, senderName` |

### Estados de Exchange

`pending` → `accepted` / `rejected` / `counter_offered` → `received` → `completed`
También: `cancelled` (con `cancelledReason`: `item_no_longer_available`, `item_deleted`, `parent_exchange_cancelled`, `account_deleted`).

### Categorías de items

`lib/features/home/presentation/widgets/category_constants.dart`:
`tech, fashion, home, books, music, general` (etiquetas en español).

---

## Backend: Cloud Functions

Directorio: `functions/` (Node.js 22). El código no fija región. Las funciones creadas antes de 2026-10 viven en `us-central1` con el trigger en `southamerica-west1` (región de Firestore). `notifyNewItem` (creada el 2026-10-14) la ubicó el CLI en `southamerica-west1`, junto a Firestore. Una función ya desplegada no cambia de región al redesplegarla.

| Función | Trigger | Propósito |
|---|---|---|
| `sendExchangeNotification` | `exchanges/{id}` onCreate | Push + notificación in-app a quien recibe la propuesta |
| `updateNotificationStatus` | `exchanges/{id}` onUpdate | Cascada de cancelaciones, cierre de exchanges padres, push de cambio de estado |
| `sendMessageNotification` | `notifications/{id}` onCreate | Push para nuevos mensajes |
| `notifyNewItem` | `items/{id}` onCreate | Push "artículo nuevo" a todos los usuarios con token, excepto el autor y quienes tengan `notifyNewItems == false` (lógica pura en `functions/new_item_recipients.js`) |

> Importante: las notificaciones de intercambios (`exchange_*`) las crean las Cloud Functions. La excepción son los mensajes de chat: la app crea el documento `notifications/*` con `type: new_message` y `sendMessageNotification` envía el push (ignora los demás tipos para no duplicar).

### Reglas de seguridad

- **Storage**: versionadas en `storage.rules` y registradas en `firebase.json`. Solo `items/{uid}/{archivo}`: lectura con sesión, escritura y borrado solo del dueño (imágenes, < 10 MB). Desplegar con `firebase deploy --only storage`. Las reglas de "modo de prueba" con fecha de vencimiento rompieron las subidas en producción desde el 2026-06-02 hasta el 2026-10-01: no volver a usarlas.
- **Firestore**: versionadas en `firestore.rules` (registradas en `firebase.json`). Por colección: `items` lectura pública, alta solo a nombre propio y `available`, un tercero solo puede pasar un artículo `available` a `exchanged` (aceptación de intercambio); `exchanges` y `messages` solo para los dos participantes; `notifications` solo las propias (cambiando `isRead`) y avisos de chat al otro participante; `users` lectura individual con sesión, sin listados, edición solo de campos propios. Tests en `firestore-tests/` (`npm test`, requiere Java 21: el de Android Studio sirve con `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`). Desplegar con `firebase deploy --only firestore:rules`. Al agregar un acceso nuevo en la app, agregar su regla y su test.

---

## Auth flow

Archivo principal: `lib/features/auth/presentation/providers/auth_provider.dart`

- Email + password con verificación de email obligatoria.
- `keep_session` (SharedPreferences) controla auto-login al reabrir la app.
- Al autenticar: se llama `PushNotificationService.requestPermissionAndSaveToken(uid)` que **pide permiso de notificaciones + guarda token FCM**.
- Al cerrar sesión: `removeUserToken(uid)` borra el token del documento del usuario.

**Decisión clave**: el permiso de notificaciones **no se pide al abrir la app**, solo después de login/registro exitoso. Esto se hizo para no asustar al usuario en su primer contacto. Si rechaza, en iOS y Android 13+ el SO bloquea repreguntar — no hay diálogo de fallback in-app (se evaluó y descartó por simplicidad).

---

## Notificaciones (FCM + local)

Servicio: `lib/core/services/push_notification_service.dart` (singleton).

- **Canales Android**: `exchange_requests` (importancia max) y `new_items` ("Artículos nuevos"), ambos creados en `initialize()`.
- **Foreground**: muestra `flutter_local_notifications` con canal `exchange_requests`, o `new_items` para `type: new_item`.
- **Background / closed**: notificación del sistema; el tap navega según `data.type`: `new_item` → `/item-detail` (carga por `itemId`), `new_message` → `/chat`, resto → `/exchange-detail`.
- **App cerrada**: la push que abrió la app (`getInitialMessage`, o `getNotificationAppLaunchDetails` para notificaciones locales) se guarda como pendiente y se procesa cuando se monta `HomePage` (después del splash y con sesión). Se descarta al cerrar sesión.
- **Token refresh**: re-guarda automáticamente en `users/{uid}.fcmToken` si hay usuario activo.

---

## Tema y localización

- `AppTheme.light()` / `AppTheme.dark()` + `ThemeProvider` Riverpod.
- Locales soportados: `es` (default), `en`. Material delegates registrados en `MaterialApp.router`.

---

## Convenciones y patrones

- **Imports**: relativos dentro del feature, absolutos (`package:truequeapp/...`) solo cuando es necesario cruzar capas lejanas.
- **`sl<T>()`** para acceso a singletons en presentación.
- **Cada UseCase = una clase con `execute(...)`**. No agrupar acciones distintas.
- **Models en `data/models/`, Entities en `domain/entities/`**. Models implementan `toFirestore()` / `fromFirestore()`; Entities son puras.
- **Sin abstracciones prematuras**: si solo hay una implementación de un repositorio y no es probable que cambie, igual mantenemos el contrato abstract por consistencia.

---

## Comandos comunes

```bash
fvm flutter pub get                 # instalar deps tras cambios en pubspec (fvm resuelve a .fvm/flutter_sdk)
fvm flutter analyze                 # linter — línea base: 27 avisos info preexistentes, 0 errores
fvm flutter test test/exchange_cancellation_logic_test.dart test/exchange_model_test.dart test/exchange_status_test.dart
fvm flutter run                     # debug en device/emulator conectado
fvm flutter build appbundle --release   # AAB de producción (Android)
fvm flutter build ios --release     # iOS (SwiftPM; ya no hay Podfile ni pod install)
fvm flutter clean                   # limpia caches si pub get da problemas

# Firebase Analytics DebugView (Android)
adb shell setprop debug.firebase.analytics.app com.truequeapp.truequeapp

# Cloud Functions (desde functions/)
firebase deploy --only functions
firebase functions:log --only sendExchangeNotification
```

---

## Producción y versionado

- Versionado en `pubspec.yaml` línea 19: `version: <name>+<code>` (ej. `1.0.5+6`).
- **Regla dura**: `versionCode` (parte `+N`) **siempre incrementa**, jamás se repite ni decrece — Play Console lo rechaza.
- Patch bump (1.0.x) = fixes / cambios invisibles para el usuario.
- Minor bump (1.x.0) = features visibles nuevas.
- Track actual: Producción **publicada**, Open Testing en Colombia/Ecuador/Perú.
- Signing: `android/app/upload-keystore.jks` + `key.properties` (NO está en git).

### Declaraciones obligatorias en Play Console

- **Data Safety**: declara recolección por Firebase Analytics + FCM (App interactions, Diagnostics, Device IDs, Email, Phone, Photos, In-app messages).
- **Advertising ID declarado como "Sí" → uso "Análisis"** (Firebase Analytics declara `AD_ID` automáticamente).

---

## Documentación complementaria

En `docs/`:
- `architecture/overview.md`
- `features/auth.md`, `features/home.md`
- `services/push_notifications.md`, `services/storage.md`
- `setup/getting_started.md`

Consultar al profundizar en un área específica.

---

## Lo que NO está implementado (alcance fuera del MVP)

- Eventos custom de Analytics (`item_published`, `exchange_initiated`, etc.) — solo screen tracking.
- `setUserId` en Analytics vinculando con Firebase Auth uid.
- Crashlytics.
- Calificaciones / reseñas entre usuarios.
- Filtros geográficos / por radio.
- Multi-idioma más allá de es/en.
- Modo offline real (la app depende de conectividad).
- AdMob u otros SDKs de publicidad.

Estas pueden ser candidatas para `1.1.0` y siguientes.
