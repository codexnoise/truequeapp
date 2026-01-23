import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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

    // imageQuality: 50 reduces size significantly with minimal mobile visual loss
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 1080,
    );

    if (pickedFile != null) {
      setState(() => _images.add(File(pickedFile.path)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addItemProvider);

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
            // ... rest of your inputs (Title, Description, etc)
          ],
        ),
      ),
      bottomSheet: _buildBottomButton(state),
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ElevatedButton(
        onPressed: canUpload
            ? () {
                // Logic to collect controllers data and call notifier
                // ref.read(addItemProvider.notifier).uploadItem(item, _images);
              }
            : null,
        child: state is AddItemLoading
            ? const CircularProgressIndicator()
            : const Text("POST ITEM"),
      ),
    );
  }
}
