import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/item_entity.dart';
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
    ref.listen<UpdateItemState>(updateItemProvider, (previous, next) {
      if (next is UpdateItemLoading) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const PopScope(
            canPop: false,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Editar Artículo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Eliminar Artículo'),
                  content: const Text('¿Estás seguro de que quieres eliminar este artículo?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: actually delete
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'TÍTULO',
                  labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
                validator: (value) => value == null || value.isEmpty ? 'El título es requerido' : null,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'DESCRIPCIÓN',
                  labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
                maxLines: 4,
                validator: (value) => value == null || value.isEmpty ? 'La descripción es requerida' : null,
              ),
              const SizedBox(height: 16),
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
                activeColor: Colors.black,
              ),
              TextFormField(
                controller: _desiredItemController,
                enabled: !_isFree,
                decoration: InputDecoration(
                  labelText: 'ARTÍCULO DESEADO',
                  labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                  hintText: _isFree ? 'Este artículo es una donación' : '¿Qué buscas a cambio?',
                ),
                validator: (value) {
                  if (_isFree) return null;
                  return value == null || value.isEmpty ? 'Este campo es requerido' : null;
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('GUARDAR CAMBIOS'),
                ),
              ),
            ],
          ),
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
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.black,
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _newImagePreview(int index, File file) {
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
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.black,
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
    );
  }
}
