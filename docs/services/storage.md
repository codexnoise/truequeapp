# Service: Storage

Documentación técnica del servicio de almacenamiento de imágenes en TruequeApp.

## Visión General

`StorageService` es un singleton que encapsula todas las operaciones con **Firebase Storage**. Se usa exclusivamente para subir y eliminar imágenes de artículos.

Archivo: `lib/core/services/storage_service.dart`

---

## Registro en GetIt

```dart
sl.registerLazySingleton(() => StorageService());
```

Se accede vía `sl<StorageService>()` desde `HomeRepositoryImpl`.

---

## Métodos

### `uploadItemImage(File file, String userId) → Future<String>`

Sube una imagen a Firebase Storage y retorna su URL pública de descarga.

**Ruta en Storage:**
```
items/{userId}/{timestamp}{extension}
```

- El nombre de archivo usa `DateTime.now().millisecondsSinceEpoch` para evitar colisiones.
- La extensión se preserva del archivo original (`.jpg`, `.png`, etc.).

**Ejemplo:**
```
items/abc123/1708123456789.jpg
```

**Retorna:** URL pública (`https://firebasestorage.googleapis.com/...`), que se guarda en el campo `imageUrls` del documento de Firestore.

---

### `deleteImage(String url) → Future<void>`

Elimina un archivo de Storage dado su URL pública.

- Usa `FirebaseStorage.refFromURL(url)` para obtener la referencia.
- Si la eliminación falla (archivo ya inexistente, permisos, etc.), el error se captura silenciosamente para no interrumpir el flujo de actualización o eliminación del artículo.

---

## Flujo de Imágenes en Items

### Al crear un artículo (`addItem`)

```
Para cada File en imageFiles:
    StorageService.uploadItemImage(file, ownerId) → URL
        │
        ▼
Lista de URLs guardada en items/{id}.imageUrls (Firestore)
```

### Al editar un artículo (`updateItem`)

```
1. Para cada URL en removedUrls:
       StorageService.deleteImage(url)

2. Para cada File en newImageFiles:
       StorageService.uploadItemImage(file, ownerId) → nueva URL

3. finalUrls = existingUrls + nuevas URLs
   Firestore: items/{id}.imageUrls = finalUrls
```

### Al eliminar un artículo (`deleteItem`)

```
Para cada URL en item.imageUrls:
    StorageService.deleteImage(url)
        │
        ▼
Firestore: items/{id} → delete()
```

---

## Reglas de Firebase Storage

Las imágenes de artículos están bajo la ruta `items/`. Las reglas de Storage deben permitir escritura solo a usuarios autenticados y lectura pública (para mostrar imágenes en la UI sin autenticación adicional).

Ejemplo de reglas recomendadas:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /items/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```
