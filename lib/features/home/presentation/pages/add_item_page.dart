import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/item_entity.dart';
import '../providers/add_item_provider.dart';
import '../widgets/category_constants.dart';

class AddItemPage extends ConsumerStatefulWidget {
  const AddItemPage({super.key});

  @override
  ConsumerState<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends ConsumerState<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final List<File> _images = [];
  final _picker = ImagePicker();
  String _selectedCategory = 'general';
  bool _isFree = false;

  final _titleController = TextEditingController();
  final _lookingForController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _lookingForController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 5) return;

    final pickedFiles = await _picker.pickMultiImage(
      imageQuality: 50,
      maxWidth: 1080,
    );

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _images.addAll(
          pickedFiles.map((file) => File(file.path)).take(5 - _images.length),
        );
      });
    }
  }

  void _submit(String ownerId) {
    if (_formKey.currentState?.validate() ?? false) {
      final newItem = ItemEntity(
        id: '',
        ownerId: ownerId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        categoryId: _selectedCategory,
        imageUrls: [],
        desiredItem: _isFree ? 'Donation' : _lookingForController.text.trim(),
        status: 'available',
      );

      ref.read(addItemProvider.notifier).uploadItem(newItem, _images);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<AddItemState>(addItemProvider, (previous, next) {
      if (next is AddItemLoading) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: Center(child: CircularProgressIndicator(color: colorScheme.onPrimary)),
          ),
        );
      }

      if (next is AddItemSuccess) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }

      if (next is AddItemError) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    String? ownerId;
    if (authState is AuthAuthenticated) {
      ownerId = authState.user.uid;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("NUEVO ARTÍCULO")),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: .start,
            children: [
              _buildImageGrid(colorScheme),
              const SizedBox(height: 8),
              Text(
                "${_images.length}/5 imágenes",
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              _CustomTextFormField(
                controller: _titleController,
                label: 'TÍTULO',
                hint: 'Ej. Camara vintage',
                validator: (value) =>
                    value == null || value.isEmpty ? 'El título es requerido' : null,
              ),
              _buildCategorySelector(),
              CheckboxListTile(
                title: const Text("Marcar como donación (gratis)"),
                value: _isFree,
                onChanged: (bool? value) {
                  setState(() {
                    _isFree = value ?? false;
                    if (_isFree) {
                      _lookingForController.clear();
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: colorScheme.primary,
              ),
              _CustomTextFormField(
                controller: _lookingForController,
                label: 'ARTÍCULO DESEADO',
                hint: _isFree ? 'Es una donación' : '¿Qué buscas a cambio?',
                enabled: !_isFree,
                validator: (value) {
                  if (_isFree) return null;
                  return value == null || value.isEmpty ? 'Este campo es requerido' : null;
                },
              ),
              _CustomTextFormField(
                controller: _descController,
                label: 'DESCRIPCIÓN',
                hint: 'Describe el estado...',
                maxLines: 4,
                validator: (value) =>
                    value == null || value.isEmpty ? 'La descripción es requerida' : null,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      ),
      bottomSheet: _buildBottomButton(ref.watch(addItemProvider), ownerId, colorScheme),
    );
  }

  Widget _buildCategorySelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            'CATEGORÍA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 0.5,
            ),
          ),
          DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            onChanged: (value) => setState(() => _selectedCategory = value!),
            items: categories.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(ColorScheme colorScheme) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length < 5 ? _images.length + 1 : 5,
        itemBuilder: (context, i) {
          if (i == _images.length && _images.length < 5) {
            return GestureDetector(
              onTap: _pickImage,
              child: _imagePlaceholder(colorScheme),
            );
          }
          return _imagePreview(i, colorScheme);
        },
      ),
    );
  }

  Widget _imagePlaceholder(ColorScheme colorScheme) {
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

  Widget _imagePreview(int index, ColorScheme colorScheme) {
    return Stack(
      children: [
        Container(
          width: 100,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: FileImage(_images[index]),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 4,
          child: GestureDetector(
            onTap: () => setState(() => _images.removeAt(index)),
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

  Widget _buildBottomButton(AddItemState state, String? ownerId, ColorScheme colorScheme) {
    final bool canUpload =
        state is! AddItemLoading && ownerId != null && _images.isNotEmpty;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: ElevatedButton(
          onPressed: canUpload ? () => _submit(ownerId) : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: state is AddItemLoading
              ? CircularProgressIndicator(color: colorScheme.onPrimary)
              : const Text("PUBLICAR ARTÍCULO"),
        ),
      ),
    );
  }
}

class _CustomTextFormField extends StatelessWidget {
  final String label;
  final String hint;
  final int maxLines;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool enabled;
  final TextCapitalization textCapitalization;

  const _CustomTextFormField({
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            enabled: enabled,
            textCapitalization: textCapitalization,
            decoration: InputDecoration(
              hintText: hint,
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }
}
