import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/vendor_model.dart';
import '../core/logging_service.dart';
import 'logout_service.dart';

/// Vendor Service - Handles all vendor-related operations
class VendorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get current vendor ID
  String? get currentVendorId => _auth.currentUser?.uid;

  // Check if current user is a vendor
  Future<bool> isVendor(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    final role = data['role']?.toString().toLowerCase() ?? '';
    final roles = List<String>.from(data['roles'] ?? []);

    return role == 'vendor' || roles.contains('vendor');
  }

  // Check if vendor is approved
  Future<bool> isVendorApproved(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    return doc.data()?['isApproved'] ?? false;
  }

  // Vendor Signup
  Future<VendorModel> signupVendor({
    required String email,
    required String password,
    required String shopName,
    required String ownerName,
    required String phone,
    required String category,
    required String location,
    required double deliveryRadius,
    File? shopImage,
  }) async {
    try {
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Upload shop image if provided
      String? imageUrl;
      if (shopImage != null) {
        imageUrl = await _uploadShopImage(uid, shopImage);
      }

      // Create vendor document
      final vendorDoc = VendorModel(
        id: uid,
        shopName: shopName,
        ownerName: ownerName,
        email: email,
        phone: phone,
        category: category,
        location: location,
        deliveryRadius: deliveryRadius,
        shopImage: imageUrl,
        status: 'pending',
        isApproved: false,
        isOnline: false,
        rating: 0.0,
        totalOrders: 0,
        totalEarnings: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('vendors').doc(uid).set(vendorDoc.toMap());

      // Create user document with vendor role
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': ownerName,
        'email': email,
        'phone': phone,
        'role': 'vendor',
        'roles': ['vendor', 'customer'],
        'isApproved': false,
        'verificationStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return vendorDoc;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('Vendor signup failed: $e');
    }
  }

  // Vendor Login
  Future<User> loginVendor(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;

      // Check if user is a vendor
      final isVendorUser = await isVendor(user.uid);
      if (!isVendorUser) {
        await _auth.signOut();
        throw Exception('This account is not a vendor account');
      }

      // Check if vendor is approved
      final isApproved = await isVendorApproved(user.uid);
      if (!isApproved) {
        await _auth.signOut();
        throw Exception('Your vendor account is pending admin approval');
      }

      // Update vendor online status
      await _firestore.collection('vendors').doc(user.uid).update({
        'isOnline': true,
        'lastLogin': FieldValue.serverTimestamp(),
      });

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('Vendor login failed: $e');
    }
  }

  // Forgot Password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  // Logout
  Future<void> logout() async {
    final uid = currentVendorId;
    if (uid != null) {
      // Update vendor offline status
      await _firestore.collection('vendors').doc(uid).update({
        'isOnline': false,
        'lastLogout': FieldValue.serverTimestamp(),
      });
    }
    await LogoutService.signOutOnly();
  }

  // Get vendor data stream
  Stream<VendorModel?> streamVendorData(String uid) {
    return _firestore.collection('vendors').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return VendorModel.fromMap(doc.data()!, doc.id);
    });
  }

  // Get vendor data once
  Future<VendorModel?> getVendorData(String uid) async {
    final doc = await _firestore.collection('vendors').doc(uid).get();
    if (!doc.exists) return null;
    return VendorModel.fromMap(doc.data()!, doc.id);
  }

  // Update vendor profile — syncs deliveryRadius to shop collection
  Future<void> updateVendorProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('vendors').doc(uid).update(data);

    // If deliveryRadius changed, sync to the shop document
    if (data.containsKey('deliveryRadius')) {
      await _firestore.collection('shops').doc(uid).update({
        'deliveryRadius': data['deliveryRadius'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Update shop status (open/closed) and sync delivery data
  Future<void> updateShopStatus(String uid, bool isOpen) async {
    // Update vendors collection
    await _firestore.collection('vendors').doc(uid).update({
      'isShopOpen': isOpen,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Also update shops collection for customer app visibility
    // Sync deliveryRadius from vendor data to ensure accurate filtering
    final vendorDoc = await _firestore.collection('vendors').doc(uid).get();
    final vendorData = vendorDoc.data();
    final deliveryRadius =
        (vendorData?['deliveryRadius'] as num?)?.toDouble() ?? 5.0;

    await _firestore.collection('shops').doc(uid).update({
      'open': isOpen,
      'isShopOpen': isOpen,
      'deliveryRadius': deliveryRadius,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    Log.i(
      'VendorService',
      '🏪 Shop status updated: ${isOpen ? "OPEN" : "CLOSED"} (radius: $deliveryRadius km)',
    );
  }

  // Upload shop image
  Future<String> _uploadShopImage(String uid, File imageFile) async {
    try {
      final ref = _storage.ref().child('vendor_images/$uid/shop.jpg');
      final uploadTask = ref.putFile(imageFile);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        Log.i(
          'VendorService',
          'Shop image upload progress: ${progress.toStringAsFixed(2)}%',
        );
      });

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload shop image: $e');
    }
  }

  // Handle Firebase Auth errors
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'operation-not-allowed':
        return 'Operation not allowed';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'user-not-found':
        return 'No vendor found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
        return 'Invalid credentials';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}
