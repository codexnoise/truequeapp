import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Uploads a file and returns its public URL
  Future<String> uploadItemImage(File file, String userId) async {
    // Unique filename with timestamp to avoid collisions
    final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';

    // Path: items/USER_ID/filename.jpg
    final ref = _storage.ref().child('items').child(userId).child(fileName);

    // Upload task
    final uploadTask = await ref.putFile(file);

    // Get download URL after completion
    return await uploadTask.ref.getDownloadURL();
  }

  // Deletes a file from Storage given its URL
  Future<void> deleteImage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // Log error but don't fail the update process if a delete fails
      print('Error deleting image from storage: $e');
    }
  }
}
