import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Account Linking Service
/// 
/// This service handles linking phone and email authentication
/// to the same user account to prevent duplicate users.
/// 
/// Features:
/// - Find existing user by phone or email
/// - Link email to phone-authenticated account
/// - Link phone to email-authenticated account
/// - Merge user data when linking
/// - Prevent duplicate user creation
class AccountLinkingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Find user document by phone number
  /// Returns the user document data if found, null otherwise
  Future<Map<String, dynamic>?> findUserByPhone(String phoneNumber) async {
    try {
      debugPrint('🔍 [AccountLinking] Searching for user by phone: $phoneNumber');
      
      final snapshot = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        debugPrint('✅ [AccountLinking] Found user by phone: ${doc.id}');
        return doc.data();
      }

      debugPrint('❌ [AccountLinking] No user found with phone: $phoneNumber');
      return null;
    } catch (e) {
      debugPrint('❌ [AccountLinking] Error finding user by phone: $e');
      return null;
    }
  }

  /// Find user document by email
  /// Returns the user document data if found, null otherwise
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    try {
      debugPrint('🔍 [AccountLinking] Searching for user by email: $email');
      
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        debugPrint('✅ [AccountLinking] Found user by email: ${doc.id}');
        return doc.data();
      }

      debugPrint('❌ [AccountLinking] No user found with email: $email');
      return null;
    } catch (e) {
      debugPrint('❌ [AccountLinking] Error finding user by email: $e');
      return null;
    }
  }

  /// Link email credential to current user's account
  /// 
  /// Use this when:
  /// - User logged in with phone
  /// - Now wants to add email to same account
  Future<bool> linkEmailToCurrentUser(String email, String password) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ [AccountLinking] No current user to link email to');
        return false;
      }

      debugPrint('🔗 [AccountLinking] Linking email to user: ${currentUser.uid}');

      // Create email credential
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      // Link credential to current user
      await currentUser.linkWithCredential(credential);

      debugPrint('✅ [AccountLinking] Email linked successfully');

      // Update Firestore with email
      await _firestore.collection('users').doc(currentUser.uid).update({
        'email': email.toLowerCase(),
        'linkedProviders': FieldValue.arrayUnion(['email']),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [AccountLinking] Failed to link email: ${e.code} - ${e.message}');
      
      if (e.code == 'email-already-in-use') {
        debugPrint('⚠️ [AccountLinking] Email already linked to another account');
      } else if (e.code == 'provider-already-linked') {
        debugPrint('⚠️ [AccountLinking] Email already linked to this account');
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ [AccountLinking] Error linking email: $e');
      return false;
    }
  }

  /// Link phone credential to current user's account
  /// 
  /// Use this when:
  /// - User logged in with email
  /// - Now wants to add phone to same account
  Future<bool> linkPhoneToCurrentUser(
    String verificationId,
    String smsCode,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ [AccountLinking] No current user to link phone to');
        return false;
      }

      debugPrint('🔗 [AccountLinking] Linking phone to user: ${currentUser.uid}');

      // Create phone credential
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Link credential to current user
      await currentUser.linkWithCredential(credential);

      debugPrint('✅ [AccountLinking] Phone linked successfully');

      // Update Firestore with phone
      // Note: Phone number will be available from currentUser after linking
      final updatedUser = _auth.currentUser;
      if (updatedUser != null && updatedUser.phoneNumber != null) {
        await _firestore.collection('users').doc(updatedUser.uid).update({
          'phone': updatedUser.phoneNumber,
          'linkedProviders': FieldValue.arrayUnion(['phone']),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [AccountLinking] Failed to link phone: ${e.code} - ${e.message}');
      
      if (e.code == 'provider-already-linked') {
        debugPrint('⚠️ [AccountLinking] Phone already linked to this account');
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ [AccountLinking] Error linking phone: $e');
      return false;
    }
  }

  /// Check if user has email provider linked
  bool hasEmailProvider(User user) {
    return user.providerData.any((provider) => provider.providerId == 'password');
  }

  /// Check if user has phone provider linked
  bool hasPhoneProvider(User user) {
    return user.providerData.any((provider) => provider.providerId == 'phone');
  }

  /// Check if user has Google provider linked
  bool hasGoogleProvider(User user) {
    return user.providerData.any((provider) => provider.providerId == 'google.com');
  }

  /// Get all linked providers for current user
  List<String> getLinkedProviders() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    return currentUser.providerData.map((provider) => provider.providerId).toList();
  }

  /// Merge user data from old account to new account
  /// 
  /// Use this when automatic linking fails and you need to manually merge
  Future<bool> mergeUserData({
    required String fromUid,
    required String toUid,
  }) async {
    try {
      debugPrint('🔄 [AccountLinking] Merging data from $fromUid to $toUid');

      final fromDoc = await _firestore.collection('users').doc(fromUid).get();
      final toDoc = await _firestore.collection('users').doc(toUid).get();

      if (!fromDoc.exists) {
        debugPrint('❌ [AccountLinking] Source user document not found');
        return false;
      }

      final fromData = fromDoc.data()!;
      final toData = toDoc.exists ? toDoc.data()! : <String, dynamic>{};

      // Merge data (prefer existing data in toUid, fill in missing from fromUid)
      final mergedData = Map<String, dynamic>.from(toData);
      
      // Add missing fields from source
      for (final entry in fromData.entries) {
        if (!mergedData.containsKey(entry.key) || mergedData[entry.key] == null) {
          mergedData[entry.key] = entry.value;
        }
      }

      // Update linked providers
      final providers = <String>[];
      if (mergedData['linkedProviders'] != null) {
        providers.addAll(List<String>.from(mergedData['linkedProviders']));
      }
      mergedData['linkedProviders'] = providers;

      // Update timestamp
      mergedData['updatedAt'] = FieldValue.serverTimestamp();
      mergedData['mergedFrom'] = fromUid;

      // Save merged data to target user
      await _firestore.collection('users').doc(toUid).set(
        mergedData,
        SetOptions(merge: true),
      );

      debugPrint('✅ [AccountLinking] User data merged successfully');

      // Optionally delete old user document
      // await _firestore.collection('users').doc(fromUid).delete();

      return true;
    } catch (e) {
      debugPrint('❌ [AccountLinking] Error merging user data: $e');
      return false;
    }
  }

  /// Unlink a provider from current user
  Future<bool> unlinkProvider(String providerId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Prevent unlinking if it's the only provider
      if (currentUser.providerData.length <= 1) {
        debugPrint('❌ [AccountLinking] Cannot unlink last provider');
        return false;
      }

      await currentUser.unlink(providerId);
      debugPrint('✅ [AccountLinking] Unlinked provider: $providerId');
      return true;
    } catch (e) {
      debugPrint('❌ [AccountLinking] Error unlinking provider: $e');
      return false;
    }
  }

  /// Debug: Print current user's linking status
  void printUserLinkingStatus() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ [AccountLinking] No user logged in');
      return;
    }

    debugPrint('👤 [AccountLinking] User ID: ${currentUser.uid}');
    debugPrint('📧 [AccountLinking] Email: ${currentUser.email ?? "Not linked"}');
    debugPrint('📱 [AccountLinking] Phone: ${currentUser.phoneNumber ?? "Not linked"}');
    debugPrint('🔗 [AccountLinking] Linked Providers:');
    
    for (final provider in currentUser.providerData) {
      debugPrint('   - ${provider.providerId}: ${provider.uid}');
    }
  }
}
