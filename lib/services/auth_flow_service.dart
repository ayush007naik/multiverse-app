import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screen/delivery_home_screen.dart';
import '../screen/home_screen.dart';
import '../screen/vendor_dashboard.dart';
import '../screen/admin_screen.dart';
import '../screen/real_estate_screen.dart';
import 'account_linking_service.dart';
import '../screen/service_provider_home_screen.dart';

class AuthFlowService {
  AuthFlowService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final AccountLinkingService _linkingService = AccountLinkingService();
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<String> ensureUserProfile({
    required String uid,
    String? email,
    String? phoneNumber,
    String? name,
    String defaultRole = 'customer',
  }) async {
    final ref = _db.collection('users').doc(uid);
    final snapshot = await ref.get();
    final data = snapshot.data();
    // Normalize role to lowercase
    final role = (data?['role'] as String? ?? defaultRole).toLowerCase();

    // If user document doesn't exist, check for existing user by email or phone
    if (snapshot.data() == null) {
      String? existingUserId;
      Map<String, dynamic>? existingUserData;

      // Check if user exists with this email
      if (email != null && email.isNotEmpty) {
        existingUserData = await _linkingService.findUserByEmail(email);
        if (existingUserData != null) {
          existingUserId = existingUserData['uid'];
          debugPrint('🔗 [AuthFlow] Found existing user by email: $existingUserId');
        }
      }

      // Check if user exists with this phone
      if (existingUserId == null && phoneNumber != null && phoneNumber.isNotEmpty) {
        existingUserData = await _linkingService.findUserByPhone(phoneNumber);
        if (existingUserData != null) {
          existingUserId = existingUserData['uid'];
          debugPrint('🔗 [AuthFlow] Found existing user by phone: $existingUserId');
        }
      }

      // If existing user found, we should link accounts
      if (existingUserId != null && existingUserId != uid) {
        debugPrint('🔗 [AuthFlow] Attempting to link accounts...');
        // Note: Account linking should be done before this point in the login flow
        // This is just a fallback - the proper way is to link credentials in login_screen
        debugPrint('⚠️ [AuthFlow] Accounts need to be linked in login flow');
      }
    }

    Map<String, dynamic> updateData = {
      'uid': uid,
      'name': name ?? data?['name'] ?? '',
      'email': (email ?? data?['email'] ?? '').toLowerCase(),
      'phone': phoneNumber ?? data?['phone'] ?? '',
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (snapshot.data() == null) {
      updateData['createdAt'] = FieldValue.serverTimestamp();
      updateData['isActive'] = true;
      updateData['isBlocked'] = false;
      updateData['linkedProviders'] = [];
      
      if (role == 'vendor') {
        updateData['isApproved'] = false;
      } else {
        updateData['isApproved'] = true;
      }
    } else {
      // Update linked providers if not already present
      final existingProviders = List<String>.from(data?['linkedProviders'] ?? []);
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        for (final provider in currentUser.providerData) {
          if (!existingProviders.contains(provider.providerId)) {
            existingProviders.add(provider.providerId);
          }
        }
      }
      
      updateData['linkedProviders'] = existingProviders;
    }

    await ref.set(updateData, SetOptions(merge: true));

    return role;
  }

  Future<String> getUserRole(
    String uid, {
    String fallbackRole = 'Customer',
  }) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['role'] as String? ?? fallbackRole;
  }

  Widget destinationForRole(String role) {
    final normalizedRole = role.toLowerCase();

    switch (normalizedRole) {
      case 'admin':
        return const AdminScreen();
      case 'vendor':
        return const VendorDashboard();
      case 'rider':
      case 'delivery partner':
        return const DeliveryHomeScreen();
      case 'real estate agent':
        return const RealEstateScreen();
    // ← YE ADD KAR
      case 'plumber':
      case 'electrician':
      case 'doctor':
      case 'carpenter':
      case 'cleaner':
      case 'service_provider':
        return const ServiceProviderHomeScreen(); // neeche banayenge
      case 'customer':
       default:
         return const HomeScreen();
     }
   }
}
