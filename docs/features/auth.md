# Feature: Auth

Handles user registration, login, session persistence, and sign-out.

## Índice

- [Visión General](#visión-general)
- [Estructura de Archivos](#estructura-de-archivos)
- [Entidades y Modelos](#entidades-y-modelos)
- [Repositorio](#repositorio)
- [Use Cases](#use-cases)
- [Estado (AuthState)](#estado-authstate)
- [AuthNotifier](#authnotifier)
- [Flujo de Sesión Persistente](#flujo-de-sesión-persistente)
- [RememberMeNotifier](#remembermenotifier)
- [Páginas](#páginas)

---

## Visión General

La feature `auth` gestiona todo el ciclo de autenticación:

1. El usuario inicia sesión con email/contraseña (Firebase Auth).
2. Si marcó "Keep me signed in", la sesión se persiste en `SharedPreferences`.
3. Al abrir la app, `AuthNotifier` verifica la sesión guardada y restaura el estado automáticamente.
4. Al cerrar sesión, se elimina el token FCM de Firestore y se borra la preferencia local.

---

## Estructura de Archivos

```
lib/features/auth/
├── data/
│   ├── datasources/
│   │   └── auth_remote_data_source.dart   # Firebase Auth wrapper
│   ├── models/
│   │   └── user_model.dart                # DTO con fromFirebase()
│   └── repositories/
│       └── auth_repository_impl.dart      # Implementación del contrato
├── domain/
│   ├── entities/
│   │   └── user_entity.dart               # Entidad pura (uid, email)
│   ├── repositories/
│   │   └── auth_repository.dart           # Contrato abstracto
│   └── usecases/
│       ├── login_usecase.dart
│       └── register_usecase.dart
└── presentation/
    ├── pages/
    │   ├── login_page.dart
    │   └── register_page.dart
    ├── providers/
    │   └── auth_provider.dart             # AuthNotifier + RememberMeNotifier
    └── widgets/
        └── auth_field_widget.dart
```

---

## Entidades y Modelos

### `UserEntity`

Clase pura de dominio, sin dependencias de Flutter ni Firebase:

```dart
class UserEntity {
  final String uid;
  final String? email;
}
```

### `UserModel`

Extiende `UserEntity` y añade `fromFirebase(User firebaseUser)` para mapear desde Firebase Auth.

---

## Repositorio

### Contrato: `AuthRepository`

```dart
abstract class AuthRepository {
  Stream<UserEntity?> get currentUser;
  Future<UserEntity?> signIn(String email, String password);
  Future<UserEntity?> signUp(String email, String password);
  Future<void> signOut();
}
```

### Implementación: `AuthRepositoryImpl`

- `currentUser` → mapea `FirebaseAuth.authStateChanges()` a `Stream<UserEntity?>`
- `signIn` / `signUp` → delega a `AuthRemoteDataSourceImpl`
- `signOut` → llama a `FirebaseAuth.signOut()`

---

## Use Cases

| Use Case | Método | Descripción |
|---|---|---|
| `LoginUseCase` | `execute(email, password)` | Llama a `repository.signIn()` |
| `RegisterUseCase` | `execute(email, password)` | Llama a `repository.signUp()` |

---

## Estado (AuthState)

```dart
sealed class AuthState { const AuthState(); }

class AuthInitial extends AuthState {}         // Estado inicial / sesión cerrada
class AuthLoading extends AuthState {}         // Verificando sesión o procesando login
class AuthAuthenticated extends AuthState {    // Sesión activa
  final UserEntity user;
}
class AuthError extends AuthState {            // Error en login/registro
  final String message;
}
```

---

## AuthNotifier

Archivo: `lib/features/auth/presentation/providers/auth_provider.dart`

```dart
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier());
```

### Ciclo de vida

```
build()
  └─ _listenToAuthState()  [async]
       ├─ state = AuthLoading()
       ├─ await SharedPreferences.getInstance()
       │    └─ keepSession = prefs.getBool('keep_session') ?? false
       └─ AuthRepository.currentUser.listen((user) {
              if (user != null && keepSession) → AuthAuthenticated(user)
              if (user != null && !keepSession) → logout()
              if (user == null)                → AuthInitial()
          })
```

### Métodos

| Método | Descripción |
|---|---|
| `login(email, password, rememberMe)` | Ejecuta `LoginUseCase`, guarda `keep_session` si `rememberMe`, guarda token FCM |
| `register(email, password)` | Ejecuta `RegisterUseCase`, guarda token FCM |
| `logout()` | Elimina token FCM de Firestore, borra `keep_session`, estado → `AuthInitial` |

---

## Flujo de Sesión Persistente

```
App abierta
    │
    ▼
AuthNotifier.build() → _listenToAuthState()
    │
    ├─ state = AuthLoading()  →  Router redirige a /loading
    │
    ├─ SharedPreferences: keepSession?
    │
    └─ Firebase authStateChanges emite usuario
         ├─ usuario != null && keepSession → AuthAuthenticated → /home
         ├─ usuario != null && !keepSession → logout() → AuthInitial → /login
         └─ usuario == null → AuthInitial → /login
```

> La clave `keep_session` en `SharedPreferences` es la única fuente de verdad para decidir si restaurar la sesión. Esto permite que el usuario cierre sesión explícitamente sin que Firebase Auth lo recuerde.

---

## RememberMeNotifier

Gestiona el estado del checkbox "Keep me signed in" en `LoginPage`:

```dart
final rememberMeProvider = NotifierProvider<RememberMeNotifier, bool>(() => RememberMeNotifier());
```

- Estado inicial: `false`
- Método: `toggle(bool? value)` — actualiza el estado del checkbox

---

## Páginas

### `LoginPage`

- Formulario con campos `email` y `password`
- Checkbox "KEEP ME SIGNED IN" vinculado a `rememberMeProvider`
- Muestra `CircularProgressIndicator` cuando `authState is AuthLoading`
- Muestra errores vía `SnackBar` cuando `authState is AuthError`
- Navega a `/register` con `context.push('/register')`

### `RegisterPage`

- Formulario con campos `email`, `password` y confirmación de contraseña
- Llama a `authProvider.notifier.register(email, password)`
- Misma lógica de loading/error que `LoginPage`
