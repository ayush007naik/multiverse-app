//  lib/services/logout_service.dart
// ✅ Reusable Logout Service

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/otp_auth_service.dart';

class LogoutService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Perform logout and navigate to login screen
  /// Clears navigation stack to prevent going back
  static Future<void> logout({
    required BuildContext context,
    required String loginScreenRoute,
  }) async {
    try {
      // Show loading dialog
      _showLoadingDialog(context);

      // Clear OTP session
      final otpAuthService = OtpAuthService();
      await otpAuthService.clearUserSession();
      otpAuthService.resetOtpState();

      // Sign out from Firebase
      await _auth.signOut();

      // Hide loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to login screen and clear all previous routes
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          loginScreenRoute,
          (route) => false,
        );
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Logged out successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Hide loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      debugPrint('Logout error: $e');
    }
  }

  /// Logout with MaterialPageRoute (if not using named routes)
  static Future<void> logoutWithRoute({
    required BuildContext context,
    required Widget loginScreen,
  }) async {
    try {
      // Show loading dialog
      _showLoadingDialog(context);

      // Clear OTP session
      final otpAuthService = OtpAuthService();
      await otpAuthService.clearUserSession();
      otpAuthService.resetOtpState();

      // Sign out from Firebase
      await _auth.signOut();

      // Hide loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to login screen and clear all previous routes
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => loginScreen),
          (route) => false,
        );
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Logged out successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Hide loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      debugPrint('Logout error: $e');
    }
  }

  /// Show loading dialog during logout
  static void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4D4F)),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Logging out...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Check if user is logged in
  static bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }

  /// Get current user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Get current user ID
  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Get current user email
  static String? getCurrentUserEmail() {
    return _auth.currentUser?.email;
  }

  /// Get current user phone
  static String? getCurrentUserPhone() {
    return _auth.currentUser?.phoneNumber;
  }
}
