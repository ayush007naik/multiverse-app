import 'dart:io';
import 'package:db_compat/db_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<String>> uploadPropertyImages(String propertyId, List<XFile> images) async {
    List<String> imageUrls = [];

    for (var i = 0; i < images.length; i++) {
      String fileName = 'property_${propertyId}_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child('properties/$propertyId/$fileName');

      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = ref.putData(await images[i].readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
      } else {
        uploadTask = ref.putFile(File(images[i].path));
      }

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      imageUrls.add(downloadUrl);
    }

    return imageUrls;
  }

  Future<void> deleteImage(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }
}
