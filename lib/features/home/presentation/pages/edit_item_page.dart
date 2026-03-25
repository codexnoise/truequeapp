import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/item_entity.dart';
import '../providers/delete_item_provider.dart';
import '../providers/update_item_provider.dart';

class EditItemPage extends ConsumerStatefulWidget {
  final ItemEntity item;

  const EditItemPage({super.key, required this.item});

  @override
  ConsumerState<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends ConsumerState<EditItemPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _desiredItemController;
  bool _isFree = false;

  late List<String> _existingImageUrls;
  final List<String> _removedImageUrls = [];
  final List<File> _newImages = [];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isFree = widget.item.desiredItem == 'Donation';
    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController = TextEditingController(text: widget.item.description);
    _desiredItemController = TextEditingController(
      text: _isFree ? 'Es una donación' : widget.item.desiredItem,
    );
    _existingImageUrls = List.from(widget.item.imageUrls);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _desiredItemController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final totalImages = _existingImageUrls.length + _newImages.length;
    if (totalImages >= 5) return;

    final pickedFiles = await _picker.pickMultiImage(
      imageQuality: 50,
      maxWidth: 1080,
    );

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _newImages.addAll(
          pickedFiles.map((file) => File(file.path)).take(5 - totalImages),
        );
      });
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, agrega al menos una imagen')),
        );
        return;
      }

      final updatedItem = ItemEntity(
        id: widget.item.id,
        ownerId: widget.item.ownerId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: widget.item.categoryId,
        imageUrls: [], // Handled by repository
        desiredItem: _isFree ? 'Donation' : _desiredItemController.text.trim(),
        status: widget.item.status,
      );

      ref.read(updateItemProvider.notifier).updateItem(
        item: updatedItem,
        existingUrls: _existingImageUrls,
        newImageFiles: _newImages,
        removedUrls: _removedImageUrls,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final updateState = ref.watch(updateItemProvider);
    final deleteState = ref.watch(deleteItemProvider);

    ref.listen<DeleteItemState>(deleteItemProvider, (previous, next) {
      if (next is DeleteItemLoading) {
        // Muestra un loader general mientras se borra
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: Center(child: CircularProgressIndicator(color: colorScheme.onPrimary)),
          ),
        );
      }
      if (next is DeleteItemSuccess) {
        // Cierra el loader, el diálogo de alerta y la página de edición
        Navigator.of(context).pop(); // Cierra loader
        Navigator.of(context).pop(); // Cierra AlertDialog
        Navigator.of(context).pop(); // Cierra EditItemPage
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Artículo eliminado con éxito')),
        );
      }
      if (next is DeleteItemError) {
        Navigator.of(context).pop(); // Cierra loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    ref.listen<UpdateItemState>(updateItemProvider, (previous, next) {
      if (next is UpdateItemLoading) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: Center(child: CircularProgressIndicator(color: colorScheme.onPrimary)),
          ),
        );
      }

      if (next is UpdateItemSuccess) {
        Navigator.of(context).pop(); // Dismiss loading
        Navigator.of(context).pop(); // Go back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Artículo actualizado con éxito')),
        );
      }

      if (next is UpdateItemError) {
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Artículo'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: colorScheme.onSurface),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  final dialogColorScheme = Theme.of(context).colorScheme;
                  return AlertDialog(
                    backgroundColor: dialogColorScheme.surface,
                    surfaceTintColor: dialogColorScheme.surface,
                    title: const Text('Eliminar Artículo'),
                    content: const Text('¿Estás seguro de que quieres eliminar este artículo?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          if (deleteState is! DeleteItemLoading) {
                            ref.read(deleteItemProvider.notifier).deleteItem(widget.item);
                          }
                        },
                        child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(),
              const SizedBox(height: 8),
              Text(
                "${_existingImageUrls.length + _newImages.length}/5 imágenes",
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              Text(
                'TÍTULO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Ej. Camara vintage',
                ),
                validator: (value) => value == null || value.isEmpty ? 'El título es requerido' : null,
              ),
              const SizedBox(height: 20),
              Text(
                'DESCRIPCIÓN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Describe el estado...',
                ),
                maxLines: 4,
                validator: (value) => value == null || value.isEmpty ? 'La descripción es requerida' : null,
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                title: const Text("Es una donación (gratis)"),
                value: _isFree,
                onChanged: (bool? value) {
                  setState(() {
                    _isFree = value ?? false;
                    if (_isFree) {
                      _desiredItemController.text = 'Es una donación';
                    } else {
                      _desiredItemController.clear();
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: colorScheme.primary,
              ),
              Text(
                'ARTÍCULO DESEADO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _desiredItemController,
                textCapitalization: TextCapitalization.sentences,
                enabled: !_isFree,
                decoration: InputDecoration(
                  hintText: _isFree ? 'Este artículo es una donación' : '¿Qué buscas a cambio?',
                ),
                validator: (value) {
                  if (_isFree) return null;
                  return value == null || value.isEmpty ? 'Este campo es requerido' : null;
                },
              ),
              const SizedBox(height: 100), // Space for bottom sheet
            ],
          ),
        ),
      ),
      ),
      bottomSheet: _buildBottomButton(updateState),
    );
  }

  Widget _buildBottomButton(UpdateItemState state) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: ElevatedButton(
          onPressed: state is UpdateItemLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: state is UpdateItemLoading
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2),
                )
              : const Text("GUARDAR CAMBIOS"),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._existingImageUrls.asMap().entries.map((entry) => _existingImagePreview(entry.key, entry.value)),
          ..._newImages.asMap().entries.map((entry) => _newImagePreview(entry.key, entry.value)),
          if (_existingImageUrls.length + _newImages.length < 5)
            GestureDetector(
              onTap: _pickImage,
              child: _imagePlaceholder(),
            ),
        ],
      ),
    );
  }

  Widget _existingImagePreview(int index, String url) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          width: 100,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(url),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 4,
          child: GestureDetector(
            onTap: () => setState(() {
              final removedUrl = _existingImageUrls.removeAt(index);
              _removedImageUrls.add(removedUrl);
            }),
            child: CircleAvatar(
              radius: 10,
              backgroundColor: colorScheme.primary,
              child: Icon(Icons.close, size: 12, color: colorScheme.onPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _newImagePreview(int index, File file) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          width: 100,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: FileImage(file),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 4,
          child: GestureDetector(
            onTap: () => setState(() => _newImages.removeAt(index)),
            child: CircleAvatar(
              radius: 10,
              backgroundColor: colorScheme.primary,
              child: Icon(Icons.close, size: 12, color: colorScheme.onPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.add_a_photo_outlined, color: colorScheme.onSurfaceVariant),
    );
  }
}
