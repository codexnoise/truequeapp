# Feature: Home (Items & Exchanges)

Gestiona el catálogo de artículos, las propuestas de intercambio/donación, y el detalle de cada exchange.

## Índice

- [Visión General](#visión-general)
- [Estructura de Archivos](#estructura-de-archivos)
- [Entidades y Modelos](#entidades-y-modelos)
- [Repositorio](#repositorio)
- [Use Cases](#use-cases)
- [Providers](#providers)
- [Páginas](#páginas)
- [Widgets](#widgets)
- [Categorías](#categorías)

---

## Visión General

La feature `home` cubre dos dominios principales:

- **Items**: artículos publicados por los usuarios para intercambiar o donar. Soporta creación, edición, eliminación y carga de imágenes a Firebase Storage.
- **Exchanges**: propuestas de intercambio o solicitudes de donación entre usuarios. Soporta envío, aceptación, rechazo, marcado como completado y contraoferta.

---

## Estructura de Archivos

```
lib/features/home/
├── data/
│   ├── datasources/
│   │   └── home_remote_data_source.dart   # (reservado)
│   ├── models/
│   │   ├── item_model.dart                # DTO con fromFirestore / toFirestore
│   │   └── exchange_model.dart            # DTO con fromMap / toMap
│   └── repositories/
│       └── home_repository_impl.dart      # Implementación con Firestore + Storage
├── domain/
│   ├── entities/
│   │   └── item_entity.dart               # Entidad pura de artículo
│   ├── repositories/
│   │   └── home_repository.dart           # Contrato abstracto
│   └── usecases/
│       ├── add_item_usecase.dart
│       ├── update_item_usecase.dart
│       ├── delete_item_usecase.dart
│       ├── get_items_usecase.dart
│       ├── create_exchange_usecase.dart
│       └── update_exchange_status_usecase.dart
└── presentation/
    ├── pages/
    │   ├── home_page.dart
    │   ├── my_items_page.dart
    │   ├── item_detail_page.dart
    │   ├── add_item_page.dart
    │   ├── edit_item_page.dart
    │   └── exchange_detail_page.dart
    ├── providers/
    │   ├── home_provider.dart
    │   ├── add_item_provider.dart
    │   ├── update_item_provider.dart
    │   ├── delete_item_provider.dart
    │   ├── exchange_provider.dart
    │   ├── exchange_detail_provider.dart
    │   └── my_exchanges_provider.dart
    └── widgets/
        ├── item_card_widget.dart
        └── category_constants.dart
```

---

## Entidades y Modelos

### `ItemEntity`

Clase pura de dominio:

```dart
class ItemEntity {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String categoryId;      // Ver sección Categorías
  final List<String> imageUrls; // URLs públicas en Firebase Storage
  final String desiredItem;     // Qué busca el dueño a cambio
  final String status;          // 'available' | otros
}
```

### `ExchangeModel`

DTO que representa una propuesta de intercambio o donación:

```dart
class ExchangeModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String receiverItemId;   // Artículo que el sender quiere
  final String? senderItemId;    // Artículo que el sender ofrece (null = donación)
  final String? message;
  final String status;           // 'pending' | 'accepted' | 'rejected' | 'completed' | 'counter_offered'
  final String type;             // 'proposal' | 'donation_request'
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
```

> `type` se determina automáticamente: si `senderItemId == null` → `'donation_request'`, si no → `'proposal'`.

---

## Repositorio

### Contrato: `HomeRepository`

```dart
abstract class HomeRepository {
  Stream<List<ItemEntity>> getItems();
  Future<void> addItem(ItemEntity item, List<File> imageFiles);
  Future<void> updateItem({required ItemEntity item, required List<String> existingUrls, required List<File> newImageFiles, required List<String> removedUrls});
  Future<void> deleteItem(ItemEntity item);
  Future<bool> createExchangeRequest({required String senderId, required String receiverId, required String receiverItemId, String? senderItemId, String? message});
  Stream<List<ExchangeModel>> getSentExchanges(String userId);
  Stream<List<ExchangeModel>> getReceivedExchanges(String userId);
  Future<ExchangeModel?> getExchangeById(String exchangeId);
  Future<ItemEntity?> getItemById(String itemId);
  Future<Map<String, dynamic>?> getUserById(String userId);
  Future<void> updateExchangeStatus(String exchangeId, String status);
  Future<bool> createCounterOffer({required String originalExchangeId, required String senderId, required String receiverId, required String receiverItemId, String? senderItemId, String? message});
}
```

### Implementación: `HomeRepositoryImpl`

Ubicación: `lib/features/home/domain/repositories/home_repository_impl.dart`

Usa directamente `FirebaseFirestore.instance` y `StorageService` (vía GetIt).

**Lógica de `updateItem`:**
1. Elimina de Storage las URLs en `removedUrls`
2. Sube los nuevos archivos en `newImageFiles`
3. Actualiza el documento en Firestore con la lista final de URLs

**Lógica de `deleteItem`:**
1. Elimina todas las imágenes del artículo de Storage
2. Elimina el documento de Firestore

**Lógica de `createCounterOffer`:**
1. Actualiza el exchange original a `status: 'counter_offered'`
2. Crea un nuevo documento en `exchanges` con `parentExchangeId` apuntando al original

---

## Use Cases

| Use Case | Método | Descripción |
|---|---|---|
| `GetItemsUseCase` | `execute()` | Stream de todos los items con `status: 'available'` |
| `AddItemUseCase` | `execute(item, imageFiles)` | Sube imágenes y crea documento en Firestore |
| `UpdateItemUseCase` | `execute(item, existingUrls, newImageFiles, removedUrls)` | Gestiona imágenes y actualiza Firestore |
| `DeleteItemUseCase` | `execute(item)` | Elimina imágenes de Storage y documento de Firestore |
| `CreateExchangeUseCase` | `execute(senderId, receiverId, receiverItemId, senderItemId?, message?)` | Crea un exchange en Firestore |
| `UpdateExchangeStatusUseCase` | `execute(exchangeId, status)` | Actualiza el campo `status` del exchange |

---

## Providers

### `home_provider.dart`

| Provider | Tipo | Descripción |
|---|---|---|
| `itemsStreamProvider` | `StreamProvider<List<ItemEntity>>` | Stream de todos los items disponibles |
| `availableItemsProvider` | `Provider<AsyncValue<List<ItemEntity>>>` | Items de otros usuarios (excluye los del usuario actual) |
| `myItemsProvider` | `Provider<AsyncValue<List<ItemEntity>>>` | Solo los items del usuario actual |

### `add_item_provider.dart`

```dart
sealed class AddItemState { ... }
// AddItemInitial | AddItemLoading | AddItemSuccess | AddItemError

final addItemProvider = NotifierProvider<AddItemNotifier, AddItemState>(...);
```

Método: `uploadItem(item, imageFiles)` — sube imágenes y crea el artículo.  
Método: `reset()` — vuelve a `AddItemInitial`.

### `update_item_provider.dart`

```dart
sealed class UpdateItemState { ... }
// UpdateItemInitial | UpdateItemLoading | UpdateItemSuccess | UpdateItemError

final updateItemProvider = NotifierProvider<UpdateItemNotifier, UpdateItemState>(...);
```

Método: `updateItem({item, existingUrls, newImageFiles, removedUrls})`.  
Método: `reset()`.

### `delete_item_provider.dart`

```dart
sealed class DeleteItemState { ... }
// DeleteItemInitial | DeleteItemLoading | DeleteItemSuccess | DeleteItemError

final deleteItemProvider = NotifierProvider<DeleteItemNotifier, DeleteItemState>(...);
```

Método: `deleteItem(item)`.

### `exchange_provider.dart`

Gestiona el envío de una nueva propuesta de intercambio desde `ItemDetailPage`.

```dart
sealed class ExchangeState { ... }
// ExchangeInitial | ExchangeLoading | ExchangeSuccess | ExchangeError

final exchangeProvider = NotifierProvider<ExchangeNotifier, ExchangeState>(...);
```

Método: `sendRequest({senderId, receiverId, receiverItemId, senderItemId?, message?})`.

### `my_exchanges_provider.dart`

| Provider | Tipo | Descripción |
|---|---|---|
| `sentExchangesProvider` | `StreamProvider.family<List<ExchangeModel>, String>` | Exchanges enviados por el usuario (por `userId`) |
| `receivedExchangesProvider` | `StreamProvider.family<List<ExchangeModel>, String>` | Exchanges recibidos por el usuario (por `userId`) |
| `existingExchangeForItemProvider` | `StreamProvider.family<ExchangeModel?, ({senderId, receiverItemId})>` | Exchange activo (`pending`/`accepted`) del usuario para un artículo específico |

> `existingExchangeForItemProvider` se usa en `ItemDetailPage` para deshabilitar el botón de propuesta si ya existe un exchange activo para ese artículo.

### `exchange_detail_provider.dart`

Gestiona la carga y las acciones sobre un exchange específico.

```dart
sealed class ExchangeDetailState { ... }
// ExchangeDetailInitial | ExchangeDetailLoading | ExchangeDetailLoaded
// | ExchangeDetailActionLoading | ExchangeDetailSuccess | ExchangeDetailError

final exchangeDetailProvider = NotifierProvider<ExchangeDetailNotifier, ExchangeDetailState>(...);
```

**`ExchangeDetailData`** — objeto compuesto cargado en paralelo:

```dart
class ExchangeDetailData {
  final ExchangeModel exchange;
  final ItemEntity receiverItem;
  final ItemEntity? senderItem;       // null si es donación
  final Map<String, dynamic> senderUser;
  final Map<String, dynamic> receiverUser;
}
```

Métodos:

| Método | Descripción |
|---|---|
| `loadExchange(exchangeId)` | Carga exchange + items + usuarios en paralelo con `Future.wait` |
| `acceptExchange(exchangeId)` | Actualiza status a `'accepted'` |
| `rejectExchange(exchangeId)` | Actualiza status a `'rejected'` |
| `sendCounterOffer(...)` | Marca el original como `'counter_offered'` y crea uno nuevo |

---

## Páginas

### `HomePage`

- Muestra el feed de artículos disponibles de otros usuarios (`availableItemsProvider`)
- Permite navegar a `/item-detail`, `/my-items`, `/add-item`

### `MyItemsPage`

- Muestra los artículos del usuario actual (`myItemsProvider`)
- Permite navegar a `/edit-item` y eliminar artículos (`deleteItemProvider`)
- Muestra los exchanges enviados y recibidos del usuario

### `ItemDetailPage`

- Recibe un `ItemEntity` vía `GoRouter` `extra`
- Muestra imágenes, descripción, categoría y artículo deseado
- Botón de propuesta de intercambio → abre modal para seleccionar artículo propio y escribir mensaje
- Deshabilitado si ya existe un exchange activo para ese artículo (`existingExchangeForItemProvider`)

### `AddItemPage`

- Formulario: título, descripción, categoría, artículo deseado, imágenes
- Usa `addItemProvider` para subir el artículo

### `EditItemPage`

- Recibe un `ItemEntity` vía `GoRouter` `extra`
- Permite modificar campos y gestionar imágenes (agregar/eliminar)
- Usa `updateItemProvider`

### `ExchangeDetailPage`

- Recibe un `exchangeId` (String) vía `GoRouter` `extra`
- Carga todos los datos del exchange con `exchangeDetailProvider`
- Muestra artículos involucrados, usuarios y estado actual
- Acciones disponibles según rol (sender/receiver) y estado actual

---

## Widgets

### `ItemCardWidget`

Tarjeta reutilizable que muestra imagen principal, título y categoría de un `ItemEntity`. Usada en `HomePage` y `MyItemsPage`.

---

## Categorías

Definidas en `lib/features/home/presentation/widgets/category_constants.dart`:

```dart
const Map<String, String> categories = {
  'tech':    'Tech',
  'fashion': 'Fashion',
  'home':    'Home',
  'books':   'Books',
  'music':   'Music',
  'general': 'General',
};
```

La clave (`categoryId`) se guarda en Firestore; el valor es el label mostrado en la UI.
