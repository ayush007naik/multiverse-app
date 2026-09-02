import 'package:db_compat/db_compat.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../core/logging_service.dart';

class VendorProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Add product
  Future<String> addProduct({
    required String vendorId,
    required String title,
    required String description,
    required String category,
    required double price,
    required double discount,
    required int stock,
    required List<String> images,
    required String status,
    double gst = 0.0,
  }) async {
    final docRef = _firestore.collection('products').doc();

    await docRef.set({
      'id': docRef.id,
      'vendorId': vendorId,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'discount': discount,
      'finalPrice': price * (1 - discount / 100),
      'stock': stock,
      'images': images,
      'gst': gst,
      'status': status,
      'totalSales': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // Update product
  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    if (data.containsKey('price') || data.containsKey('discount')) {
      final double price = (data['price'] as num?)?.toDouble() ?? 0.0;
      final double discount = (data['discount'] as num?)?.toDouble() ?? 0.0;
      if (price > 0) {
        data['finalPrice'] = (price * (1 - (discount / 100))).roundToDouble();
      }
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('products').doc(productId).update(data);
  }

  // Delete product
  Future<void> deleteProduct(String productId) async {
    // Delete images from storage
    final productDoc = await _firestore
        .collection('products')
        .doc(productId)
        .get();
    if (productDoc.exists) {
      final images = List<String>.from(productDoc.data()?['images'] ?? []);
      for (final imageUrl in images) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          Log.e('VendorProductService', 'Error deleting image: $e', ex: e);
        }
      }
    }

    await _firestore.collection('products').doc(productId).delete();
  }

  // Upload product image
  Future<String> uploadProductImage(String productId, File imageFile) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
    final ref = _storage.ref().child('product_images/$productId/$fileName');

    final uploadTask = ref.putFile(imageFile);

    // Monitor upload progress
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
      Log.i(
        'VendorProductService',
        'Upload progress: ${progress.toStringAsFixed(2)}%',
      );
    });

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Update stock
  Future<void> updateStock(String productId, int newStock) async {
    String status;
    if (newStock == 0) {
      status = 'out_of_stock';
    } else if (newStock <= 10) {
      status = 'low_stock';
    } else {
      status = 'in_stock';
    }

    await _firestore.collection('products').doc(productId).update({
      'stock': newStock,
      'stockStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream vendor products
  Stream<QuerySnapshot> streamVendorProducts(String vendorId) {
    return _firestore
        .collection('products')
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Pick image from gallery
  Future<File?> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  // Get inventory status
  Future<Map<String, int>> getInventoryStats(String vendorId) async {
    final snapshot = await _firestore
        .collection('products')
        .where('vendorId', isEqualTo: vendorId)
        .get();

    int inStock = 0;
    int lowStock = 0;
    int outOfStock = 0;

    for (final doc in snapshot.docs) {
      final stock = doc.data()['stock'] ?? 0;
      if (stock == 0) {
        outOfStock++;
      } else if (stock <= 10) {
        lowStock++;
      } else {
        inStock++;
      }
    }

    return {'inStock': inStock, 'lowStock': lowStock, 'outOfStock': outOfStock};
  }
}
