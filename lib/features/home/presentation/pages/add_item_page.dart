import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/add_item_provider.dart';

class AddItemPage extends ConsumerWidget {
  const AddItemPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch the provider state to react to changes
    final addItemState = ref.watch(addItemProvider);

    // 2. Listen for success or error side effects
    ref.listen(addItemProvider, (previous, next) {
      switch (next) {
        case AddItemSuccess():
          Navigator.pop(context);
        case AddItemError(message: final msg):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $msg')),
          );
        default:
          break;
      }
    });

    final uploadState = ref.watch(addItemProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('NEW ITEM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            // Image Placeholder (Minimalist)
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),

            // Minimal Inputs
            _CustomTextField(label: 'TITLE', hint: 'e.g. Vintage Camera'),
            _CustomTextField(label: 'LOOKING FOR', hint: 'What do you want in exchange?'),
            _CustomTextField(label: 'DESCRIPTION', hint: 'Describe condition...', maxLines: 4),

            const SizedBox(height: 40),

            // Action Button
            ElevatedButton(
              // Use the declared variable 'addItemState'
              onPressed: addItemState is AddItemLoading ? null : () {
                //_handleUpload(ref);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 64),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: addItemState is AddItemLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text("POST ITEM", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final int maxLines;

  const _CustomTextField({required this.label, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
          TextField(
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFEEEEEE))),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}