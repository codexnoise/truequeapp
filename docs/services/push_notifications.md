# Push Notifications

Documentación técnica completa del sistema de notificaciones push en TruequeApp.

## Índice

- [Visión General](#visión-general)
- [Dependencias](#dependencias)
- [Arquitectura del Sistema](#arquitectura-del-sistema)
- [Configuración Android](#configuración-android)
- [Configuración iOS](#configuración-ios)
- [Servicio Flutter (Cliente)](#servicio-flutter-cliente)
- [Firebase Cloud Functions (Servidor)](#firebase-cloud-functions-servidor)
- [Ciclo de Vida del Token FCM](#ciclo-de-vida-del-token-fcm)
- [Tipos de Notificaciones](#tipos-de-notificaciones)
- [Publicar en el Servidor de Notificaciones](#publicar-en-el-servidor-de-notificaciones)
- [Diagnóstico y Logs](#diagnóstico-y-logs)
- [Troubleshooting](#troubleshooting)

---

## Visión General

TruequeApp utiliza **Firebase Cloud Messaging (FCM)** como servidor de notificaciones push y **flutter_local_notifications** para mostrar notificaciones cuando la app está en primer plano.

```
┌──────────────┐     Crea exchange      ┌─────────────────┐
│  Dispositivo │ ──────────────────────▶│   Firestore DB  │
│  (Sender)    │                        │ exchanges/{id}  │
└──────────────┘                        └────────┬────────┘
                                                 │ onDocumentCreated trigger
                                        ┌────────▼────────┐
                                        │ Cloud Function  │
                                        │sendExchangeNotif│
                                        └────────┬────────┘
                                                 │ admin.messaging().send()
                                        ┌────────▼────────┐
                                        │   FCM Server    │
                                        │ (Google Cloud)  │
                                        └────────┬────────┘
                                                 │ push notification
                                        ┌────────▼────────┐
                                        │  Dispositivo    │
                                        │  (Receiver)     │
                                        └─────────────────┘
```

---

## Dependencias

### `pubspec.yaml`

```yaml
dependencies:
  firebase_messaging: ^16.0.0          # FCM client SDK
  flutter_local_notifications: ^20.1.0 # Notificaciones locales en foreground
  cloud_firestore: ^6.1.1              # Guardar/leer tokens FCM
```

### `functions/package.json`

```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.3.1"
  },
  "engines": { "node": "22" }
}
```

---

## Arquitectura del Sistema

El sistema tiene dos componentes principales:

| Componente | Ubicación | Responsabilidad |
|---|---|---|
| `PushNotificationService` | `lib/core/services/push_notification_service.dart` | Inicializar FCM, gestionar tokens, mostrar notificaciones locales |
| `sendExchangeNotification` | `functions/index.js` | Enviar notificación cuando se crea un exchange |
| `updateNotificationStatus` | `functions/index.js` | Enviar notificación cuando cambia el estado de un exchange |

---

## Configuración Android

### `android/app/build.gradle.kts`

```kotlin
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true  // Requerido por flutter_local_notifications
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")  // Mínimo 2.1.4
}
```

> **Importante:** `flutter_local_notifications >= 20.x` requiere `desugar_jdk_libs >= 2.1.4`. Versiones anteriores causarán un `NullPointerException` al intentar mostrar notificaciones.

### `android/gradle.properties`

```properties
android.useAndroidX=true
android.enableJetifier=true
```

### Canal de notificaciones Android

El canal `exchange_requests` se configura en `_showLocalNotification()`:

```dart
AndroidNotificationDetails(
  'exchange_requests',        // channelId — debe coincidir con el de Cloud Functions
  'Exchange Requests',        // channelName
  channelDescription: 'Notifications for exchange requests and updates',
  importance: Importance.max,
  priority: Priority.high,
)
```

El mismo `channelId` es referenciado en `functions/index.js`:

```js
android: {
  priority: 'high',
  notification: {
    channelId: 'exchange_requests',  // Debe coincidir con el canal del cliente
  },
}
```

---

## Configuración iOS

No se requiere configuración adicional en `Info.plist`. Los permisos se solicitan en tiempo de ejecución mediante `_requestPermission()`.

Para notificaciones en foreground en iOS se configura:

```dart
await _firebaseMessaging.setForegroundNotificationPresentationOptions(
  alert: true,
  badge: true,
  sound: true,
);
```

---

## Servicio Flutter (Cliente)

Archivo: `lib/core/services/push_notification_service.dart`

### Patrón Singleton

```dart
static final PushNotificationService _instance = PushNotificationService._internal();
factory PushNotificationService() => _instance;
PushNotificationService._internal();
```

### Inicialización

Se llama en `main.dart` antes de `runApp()`:

```dart
await di.sl<PushNotificationService>().initialize();
```

El método `initialize()` ejecuta los siguientes pasos en orden:

1. **Inicializa `flutter_local_notifications`** con configuración para Android e iOS
2. **Solicita permisos** de notificación al usuario
3. **Configura presentación en foreground** (iOS)
4. **Obtiene el token FCM** del dispositivo
5. **Escucha renovaciones de token** para mantenerlo actualizado en Firestore
6. **Registra listeners** de mensajes en foreground y apertura desde notificación

### Métodos Públicos

| Método | Descripción |
|---|---|
| `initialize()` | Configura todo el sistema de notificaciones |
| `saveUserToken(String userId)` | Guarda el token FCM en `users/{userId}/fcmToken` |
| `removeUserToken(String userId)` | Elimina el token FCM al cerrar sesión |
| `fcmToken` (getter) | Retorna el token FCM actual del dispositivo |

### Manejo de Mensajes por Estado de la App

| Estado de la App | Handler | Comportamiento |
|---|---|---|
| **Foreground** | `FirebaseMessaging.onMessage` → `_handleForegroundMessage()` | Muestra notificación local vía `flutter_local_notifications` |
| **Background** | FCM SDK (automático) | El sistema operativo muestra la notificación |
| **Terminada** | `_firebaseMessagingBackgroundHandler()` en `main.dart` | Reinicializa Firebase y procesa el mensaje |

### Handler de Background (main.dart)

```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

// Registrado antes de runApp():
FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
```

> **Nota:** `@pragma('vm:entry-point')` es obligatorio para que el compilador no elimine esta función en modo release.

### Renovación Automática de Token

```dart
_firebaseMessaging.onTokenRefresh.listen((token) async {
  _fcmToken = token;
  if (_currentUserId != null) {
    await saveUserToken(_currentUserId!);
  }
});
```

Los tokens FCM pueden ser renovados por Google en cualquier momento. Este listener garantiza que Firestore siempre tenga el token vigente.

---

## Firebase Cloud Functions (Servidor)

Archivo: `functions/index.js`  
Runtime: **Node.js 22** — Gen 2 — `us-central1`

### Función 1: `sendExchangeNotification`

**Trigger:** `onDocumentCreated('exchanges/{exchangeId}')`  
**Propósito:** Notificar al dueño del artículo cuando alguien le hace una propuesta de intercambio o solicitud de donación.

**Flujo:**

```
Nuevo documento en exchanges/{exchangeId}
    │
    ├─ ¿notificationSent == true? → salir (evitar duplicados)
    │
    ├─ Leer users/{receiverId} → obtener fcmToken
    ├─ Leer items/{receiverItemId} → obtener título del artículo
    ├─ Leer users/{senderId} → obtener nombre del remitente
    │
    ├─ Construir mensaje FCM
    │   ├─ type == 'donation_request' → "¡Nueva solicitud de donación!"
    │   └─ type == 'exchange'         → "¡Nueva propuesta de intercambio!"
    │
    ├─ admin.messaging().send(message)
    └─ Actualizar exchange: { notificationSent: true }
```

**Payload del mensaje FCM:**

```js
{
  token: fcmToken,
  notification: { title, body },
  data: {
    type: 'exchange_request',
    exchangeId: '...',
    senderId: '...',
    receiverItemId: '...',
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  },
  android: {
    priority: 'high',
    notification: { priority: 'high', sound: 'default', channelId: 'exchange_requests' }
  },
  apns: {
    payload: { aps: { sound: 'default', badge: 1, category: 'EXCHANGE_REQUEST' } }
  }
}
```

### Función 2: `updateNotificationStatus`

**Trigger:** `onDocumentUpdated('exchanges/{exchangeId}')`  
**Propósito:** Notificar al remitente cuando el receptor acepta, rechaza o completa el intercambio.

**Mensajes por estado:**

| `after.status` | Título | Cuerpo |
|---|---|---|
| `accepted` | ¡Propuesta aceptada! | Tu propuesta ha sido aceptada... |
| `rejected` | Propuesta rechazada | Tu propuesta ha sido rechazada... |
| `completed` | ¡Intercambio completado! | El intercambio ha sido marcado como completado... |

---

## Ciclo de Vida del Token FCM

```
App instalada / primer login
        │
        ▼
PushNotificationService.initialize()
        │
        ▼
FirebaseMessaging.getToken() → token
        │
        ▼
AuthNotifier.login() llama saveUserToken(userId)
        │
        ▼
Firestore: users/{userId} { fcmToken: "...", tokenUpdatedAt: Timestamp }
        │
        ├─ Token renovado por Google → onTokenRefresh → saveUserToken()
        │
        └─ Usuario cierra sesión → removeUserToken() → fcmToken: FieldValue.delete()
```

---

## Tipos de Notificaciones

| Evento | Función | Destinatario | Canal |
|---|---|---|---|
| Nueva propuesta de intercambio | `sendExchangeNotification` | Receptor del artículo | `exchange_requests` |
| Nueva solicitud de donación | `sendExchangeNotification` | Dueño del artículo | `exchange_requests` |
| Propuesta aceptada | `updateNotificationStatus` | Remitente de la propuesta | `exchange_requests` |
| Propuesta rechazada | `updateNotificationStatus` | Remitente de la propuesta | `exchange_requests` |
| Intercambio completado | `updateNotificationStatus` | Remitente de la propuesta | `exchange_requests` |

---

## Publicar en el Servidor de Notificaciones

### Requisitos previos

1. Tener instalado [Node.js](https://nodejs.org/) >= 18
2. Tener instalado Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```
3. Estar autenticado en Firebase:
   ```bash
   firebase login
   ```
4. Tener habilitadas las siguientes APIs en Google Cloud Console:
   - `cloudfunctions.googleapis.com`
   - `cloudbuild.googleapis.com`
   - `artifactregistry.googleapis.com`
   - `run.googleapis.com`
   - `eventarc.googleapis.com`
   - `pubsub.googleapis.com`

### Paso 1: Instalar dependencias de las funciones

```bash
cd functions
npm install
cd ..
```

### Paso 2: Verificar el código antes de publicar

```bash
# Revisar errores de sintaxis
node -e "require('./functions/index.js')"
```

### Paso 3: Publicar las funciones

```bash
npx firebase-tools deploy --only functions --project truequeapp-c2f82
```

Salida esperada:

```
✔  functions: functions source uploaded successfully
✔  functions[sendExchangeNotification(us-central1)] Successful update operation.
✔  functions[updateNotificationStatus(us-central1)] Successful update operation.
✔  Deploy complete!
```

### Paso 4: Verificar el deploy

Confirmar que las funciones están activas en Firebase Console:

```
https://console.firebase.google.com/project/truequeapp-c2f82/functions
```

O via CLI:

```bash
npx firebase-tools functions:list --project truequeapp-c2f82
```

### Paso 5: Verificar logs post-deploy

```bash
npx firebase-tools functions:log --project truequeapp-c2f82
```

Logs esperados al enviar una notificación exitosa:

```
Attempting to send notification to token: <fcm_token>
Notification sent successfully: projects/truequeapp-c2f82/messages/<message_id>
```

### Actualizar solo una función

```bash
npx firebase-tools deploy --only functions:sendExchangeNotification --project truequeapp-c2f82
npx firebase-tools deploy --only functions:updateNotificationStatus --project truequeapp-c2f82
```

### Actualizar dependencias de las funciones

```bash
cd functions
npm install --save firebase-functions@latest
npm install --save firebase-admin@latest
cd ..
npx firebase-tools deploy --only functions --project truequeapp-c2f82
```

> **Nota:** La versión actual `firebase-functions@4.x` es funcional pero tiene advertencias. Al actualizar a `>=5.1.0` revisar breaking changes en la [guía de migración](https://firebase.google.com/docs/functions/migrate-to-2nd-gen).

---

## Diagnóstico y Logs

### Ver logs en tiempo real

```bash
npx firebase-tools functions:log --project truequeapp-c2f82
```

### Ver logs de un dispositivo Android conectado

```bash
# Logs de Flutter (FCM)
adb logcat | grep -E "flutter|FCM|FLTFireMsg"

# Logs de notificaciones locales
adb logcat | grep "dexterous.com/flutter/local_notifications"

# Logs de errores
adb logcat | grep -E "E/flutter|E/MethodChannel"
```

### Verificar token FCM en Firestore

En Firebase Console → Firestore → colección `users` → documento del usuario → campo `fcmToken`.

Si el campo no existe o está vacío, el usuario no recibirá notificaciones push.

### Verificar permisos en el dispositivo

**Android:** Ajustes → Aplicaciones → TruequeApp → Notificaciones → Activar  
**iOS:** Ajustes → TruequeApp → Notificaciones → Permitir notificaciones

---

## Troubleshooting

### No llegan notificaciones

| Síntoma | Causa probable | Solución |
|---|---|---|
| Log: `No FCM token for receiver` | El usuario no tiene token guardado | Verificar que `saveUserToken()` se llama tras el login |
| Log: `Receiver not found` | El `receiverId` no existe en Firestore | Verificar el campo `receiverId` en el documento de exchange |
| No hay logs en Cloud Functions | La función no se disparó | Verificar que el documento se creó en `exchanges/` (no en otra colección) |
| Notificación llega en background pero no en foreground | `flutter_local_notifications` no inicializado | Verificar que `initialize()` se llama antes de `runApp()` |
| `NullPointerException` en `setupNotificationChannel` | Versión de `desugar_jdk_libs` < 2.1.4 | Actualizar a `desugar_jdk_libs:2.1.4` en `build.gradle.kts` |
| Token inválido / expirado | Token FCM desactualizado | Reinstalar la app para generar un nuevo token |

### Error: `No AppCheckProvider installed`

Este warning aparece en los logs pero **no afecta el funcionamiento** de las notificaciones. Es informativo e indica que App Check no está configurado.

### Error al hacer deploy: API no habilitada

```
Error: HTTP Error: 403, Firebase Cloud Functions API is not enabled
```

Solución: Habilitar la API en [Google Cloud Console](https://console.cloud.google.com/apis/library) para el proyecto `truequeapp-c2f82`.
