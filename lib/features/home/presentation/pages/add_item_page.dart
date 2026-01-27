import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/item_entity.dart';
import '../providers/add_item_provider.dart';

class AddItemPage extends ConsumerStatefulWidget {
  const AddItemPage({super.key});

  @override
  ConsumerState<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends ConsumerState<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final List<File> _images = [];
  final _picker = ImagePicker();

  // Controllers to manage the text fields' state
  final _titleController = TextEditingController();
  final _lookingForController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    // Dispose controllers to free up resources
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
    // Trigger validation and check if the form is valid.
    if (_formKey.currentState?.validate() ?? false) {
      final newItem = ItemEntity(
        id: '', // Firestore will generate this
        ownerId: ownerId, // The authenticated user's ID
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        categoryId: 'general', // Placeholder category
        imageUrls: [], // URLs will be populated by the provider during upload
        desiredItem: _lookingForController.text.trim(),
        status: 'available',
      );

      // Call the notifier to handle the item upload logic
      ref.read(addItemProvider.notifier).uploadItem(newItem, _images);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    ref.listen<AddItemState>(addItemProvider, (previous, next) {
      // Show loading dialog
      if (next is AddItemLoading) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const PopScope(
            canPop: false,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
        );
      }

      // Pop loading dialog and go back on success
      if (next is AddItemSuccess) {
        Navigator.of(context).pop(); // Dismiss dialog
        Navigator.of(context).pop(); // Go back to prev screen
      }

      // Pop loading dialog and show error
      if (next is AddItemError) {
        Navigator.of(context).pop(); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    // Extract ownerId from the authenticated state
    String? ownerId;
    if (authState is AuthAuthenticated) {
      ownerId = authState.user.uid;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("NEW ITEM")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: .start,
            children: [
              _buildImageGrid(),
              const SizedBox(height: 8),
              Text(
                "${_images.length}/5 images",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _CustomTextFormField(
                controller: _titleController,
                label: 'TITLE',
                hint: 'e.g. Vintage Camera',
                validator: (value) =>
                    value == null || value.isEmpty ? 'Title is required' : null,
              ),
              _CustomTextFormField(
                controller: _lookingForController,
                label: 'LOOKING FOR',
                hint: 'What do you want in exchange?',
                validator: (value) =>
                    value == null || value.isEmpty ? 'This field is required' : null,
              ),
              _CustomTextFormField(
                controller: _descController,
                label: 'DESCRIPTION',
                hint: 'Describe condition...',
                maxLines: 4,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomSheet: _buildBottomButton(ref.watch(addItemProvider), ownerId),
    );
  }

  Widget _buildImageGrid() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length < 5 ? _images.length + 1 : 5,
        itemBuilder: (context, i) {
          if (i == _images.length && _images.length < 5) {
            return GestureDetector(
              onTap: _pickImage,
              child: _imagePlaceholder(),
            );
          }
          return _imagePreview(i);
        },
      ),
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

  Widget _imagePreview(int index) {
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

  Widget _buildBottomButton(AddItemState state, String? ownerId) {
    final bool canUpload =
        state is! AddItemLoading && ownerId != null && _images.isNotEmpty;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: ElevatedButton(
          onPressed: canUpload ? () => _submit(ownerId!) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: state is AddItemLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("POST ITEM"),
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

  const _CustomTextFormField({
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFEEEEEE)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }
}
