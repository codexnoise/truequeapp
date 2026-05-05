import 'package:flutter/material.dart';

Future<void> showImageSourcePicker({
  required BuildContext context,
  required VoidCallback onCamera,
  required VoidCallback onGallery,
}) async {
  final colorScheme = Theme.of(context).colorScheme;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.photo_camera, color: colorScheme.primary),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.of(context).pop();
                onCamera();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: colorScheme.primary),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.of(context).pop();
                onGallery();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
