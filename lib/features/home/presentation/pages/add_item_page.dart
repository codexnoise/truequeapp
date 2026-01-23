import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/item_entity.dart';
import '../providers/add_item_provider.dart';

class AddItemPage extends ConsumerStatefulWidget {
  const AddItemPage({super.key});

  @override
  ConsumerState<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends ConsumerState<AddItemPage> {
  final List<File> _images = [];
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    if (_images.length >= 5) return;

    // pickMultiImage allows selecting multiple images at once.
    final pickedFiles = await _picker.pickMultiImage(
      imageQuality: 50,
      maxWidth: 1080,
    );

    if (pickedFiles.isNotEmpty) {
      setState(() {
        // Add all selected images, respecting the limit of 5.
        _images.addAll(
          pickedFiles.map((file) => File(file.path)).take(5 - _images.length),
        );
      });
    }
  }

  void _submit() {
    if (_images.isEmpty) return;

    // final newItem = ItemEntity(
    //   id: '',
    //   ownerId: 'current_user_id', // Integrate with your AuthProvider later
    //   title: _titleController.text.trim(),
    //   description: _descController.text.trim(),
    //   categoryId: 'general',
    //   imageUrls: [],
    //   desiredItem: _lookingForController.text.trim(),
    //   status: 'available',
    // );
    //
    // ref.read(addItemProvider.notifier).uploadItem(newItem, _images);
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(addItemProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("NEW ITEM")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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

            // Minimal Inputs
            _CustomTextField(label: 'TITLE', hint: 'e.g. Vintage Camera'),
            _CustomTextField(
              label: 'LOOKING FOR',
              hint: 'What do you want in exchange?',
            ),
            _CustomTextField(
              label: 'DESCRIPTION',
              hint: 'Describe condition...',
              maxLines: 4,
            ),

            const SizedBox(height: 40),

          ],
        ),
      ),
      bottomSheet: _buildBottomButton(uploadState),
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

  Widget _buildBottomButton(AddItemState state) {
    // Disable if loading or if no images selected
    final bool canUpload = state is! AddItemLoading && _images.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: ElevatedButton(
        onPressed: canUpload
            ? () {
                // Logic to collect controllers data and call notifier
                // ref.read(addItemProvider.notifier).uploadItem(item, _images);
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: state is AddItemLoading
            ? const CircularProgressIndicator()
            : const Text("POST ITEM"),
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final int maxLines;

  const _CustomTextField({
    required this.label,
    required this.hint,
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
          TextField(
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
          ),
        ],
      ),
    );
  }
}
