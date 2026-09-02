// vendor_dashboard/lib/services/logout_service.dart
// ✅ Centralized Logout Service for Vendor Dashboard

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';

class LogoutService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> _logLogout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _db.collection('activity_log').add({
          'userId': uid,
          'activity': 'Logged out',
          'device': 'Vendor Dashboard',
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  /// Perform logout and navigate to login screen
  static Future<void> logout({
    required BuildContext context,
    required String loginScreenRoute,
  }) async {
    try {
      _showLoadingDialog(context);

      await _logLogout();
      await _auth.signOut();

      if (context.mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushNamedAndRemoveUntil(loginScreenRoute, (route) => false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Logged out successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Sign out without navigation
  static Future<void> signOutOnly() async {
    await _logLogout();
    await _auth.signOut();
  }

  static void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4D4F)),
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 16),
              Text(
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
}
