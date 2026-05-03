import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OTP Authentication Service
/// 
/// Features:
/// - Phone OTP authentication with Firebase
/// - Email magic link (passwordless) authentication
/// - OTP cooldown timer (60 seconds)
/// - OTP retry limit (3 attempts)
/// - Session management to avoid repeated logins
/// - Spam prevention
class OtpAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // OTP Configuration
  static const int otpCooldownSeconds = 60;
  static const int maxOtpRetries = 3;
  static const String sessionKey = 'user_session_active';
  static const String lastOtpRequestKey = 'last_otp_request_time';
  static const String otpRetryCountKey = 'otp_retry_count';

  // OTP State
  String? _verificationId;
  int? _resendToken;
  DateTime? _lastOtpRequestTime;
  int _otpRetryCount = 0;
  bool _isCooldownActive = false;

  // Getters
  String? get verificationId => _verificationId;
  int? get resendToken => _resendToken;
  bool get isCooldownActive => _isCooldownActive;
  int get otpRetryCount => _otpRetryCount;
  int get remainingCooldownSeconds {
    if (_lastOtpRequestTime == null) return 0;
    
    final elapsed = DateTime.now().difference(_lastOtpRequestTime!).inSeconds;
    final remaining = otpCooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Check if user has an active session
  Future<bool> hasActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionActive = prefs.getBool(sessionKey) ?? false;
      
      // Also check Firebase Auth
      final currentUser = _auth.currentUser;
      
      debugPrint('🔍 [Session] Check: SharedPreferences=$sessionActive, Firebase=${currentUser != null}');
      
      return sessionActive && currentUser != null;
    } catch (e) {
      debugPrint('❌ [Session] Error checking session: $e');
      return false;
    }
  }

  /// Save user session after successful login
  Future<void> saveUserSession(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(sessionKey, true);
      await prefs.setString('user_uid', uid);
      await prefs.setString('session_started', DateTime.now().toIso8601String());
      
      debugPrint('✅ [Session] Saved session for user: $uid');
    } catch (e) {
      debugPrint('❌ [Session] Error saving session: $e');
    }
  }

  /// Clear user session on logout
  Future<void> clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(sessionKey);
      await prefs.remove('user_uid');
      await prefs.remove('session_started');
      await prefs.remove(lastOtpRequestKey);
      await prefs.remove(otpRetryCountKey);
      
      debugPrint('✅ [Session] Cleared user session');
    } catch (e) {
      debugPrint('❌ [Session] Error clearing session: $e');
    }
  }

  /// Check if OTP cooldown is active
  bool canRequestOtp() {
    if (_lastOtpRequestTime == null) return true;
    
    final elapsed = DateTime.now().difference(_lastOtpRequestTime!).inSeconds;
    final canRequest = elapsed >= otpCooldownSeconds;
    
    debugPrint('🔍 [OTP Cooldown] Last request: ${_lastOtpRequestTime}, Elapsed: ${elapsed}s, Can request: $canRequest');
    
    return canRequest;
  }

  /// Check if max OTP retries exceeded
  bool canRetryOtp() {
    return _otpRetryCount < maxOtpRetries;
  }

  /// Increment OTP retry count
  void incrementRetryCount() {
    _otpRetryCount++;
    debugPrint('🔢 [OTP Retry] Count: $_otpRetryCount/$maxOtpRetries');
  }

  /// Reset OTP retry count
  void resetRetryCount() {
    _otpRetryCount = 0;
    debugPrint('🔄 [OTP Retry] Reset count to 0');
  }

  /// Send Phone OTP with cooldown and retry protection
  Future<Map<String, dynamic>> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(PhoneAuthCredential credential) verificationCompleted,
    required void Function(FirebaseAuthException exception) verificationFailed,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
  }) async {
    try {
      // Check cooldown
      if (!canRequestOtp()) {
        final remaining = remainingCooldownSeconds;
        debugPrint('⏱️ [OTP] Cooldown active: ${remaining}s remaining');
        return {
          'success': false,
          'error': 'cooldown',
          'message': 'Please wait $remaining seconds before requesting another OTP',
          'cooldownSeconds': remaining,
        };
      }

      debugPrint('📱 [OTP] Sending OTP to: $phoneNumber');

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber.startsWith('+') ? phoneNumber : '+91$phoneNumber',
        forceResendingToken: _resendToken,
        verificationCompleted: verificationCompleted,
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ [OTP] Verification failed: ${e.code} - ${e.message}');
          verificationFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ [OTP] Code sent successfully');
          
          // Update state
          _verificationId = verificationId;
          _resendToken = resendToken;
          _lastOtpRequestTime = DateTime.now();
          _isCooldownActive = true;
          resetRetryCount();
          
          debugPrint('⏱️ [OTP] Cooldown started: ${otpCooldownSeconds}s');
          
          codeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        timeout: const Duration(seconds: 60),
      );

      return {
        'success': true,
        'message': 'OTP sent successfully',
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [OTP] Firebase error: ${e.code} - ${e.message}');
      
      String errorMessage = 'Failed to send OTP';
      if (e.code == 'invalid-phone-number') {
        errorMessage = 'Invalid phone number format';
      } else if (e.code == 'quota-exceeded') {
        errorMessage = 'Too many requests. Please try again later';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Please check connection';
      }
      
      return {
        'success': false,
        'error': e.code,
        'message': errorMessage,
      };
    } catch (e) {
      debugPrint('❌ [OTP] Unexpected error: $e');
      return {
        'success': false,
        'error': 'unknown',
        'message': 'Failed to send OTP. Please try again',
      };
    }
  }

  /// Verify Phone OTP with retry limit
  Future<Map<String, dynamic>> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    try {
      // Check retry limit
      if (!canRetryOtp()) {
        debugPrint('🚫 [OTP] Max retries exceeded');
        return {
          'success': false,
          'error': 'max_retries',
          'message': 'Maximum OTP attempts exceeded. Please request a new OTP',
          'retriesLeft': 0,
        };
      }

      debugPrint('🔐 [OTP] Verifying OTP...');

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Success - reset retry count
      resetRetryCount();
      _isCooldownActive = false;

      debugPrint('✅ [OTP] Verification successful: ${userCredential.user!.uid}');

      return {
        'success': true,
        'userCredential': userCredential,
        'message': 'OTP verified successfully',
      };
    } on FirebaseAuthException catch (e) {
      // Increment retry count on failure
      incrementRetryCount();
      
      debugPrint('❌ [OTP] Verification failed: ${e.code} (Attempt $_otpRetryCount/$maxOtpRetries)');
      
      String errorMessage = 'Invalid OTP';
      if (e.code == 'invalid-verification-code') {
        errorMessage = 'Invalid OTP code';
      } else if (e.code == 'session-expired') {
        errorMessage = 'OTP session expired. Please request new OTP';
      }
      
      final retriesLeft = maxOtpRetries - _otpRetryCount;
      
      return {
        'success': false,
        'error': e.code,
        'message': errorMessage,
        'retriesLeft': retriesLeft,
        'retryCount': _otpRetryCount,
      };
    } catch (e) {
      incrementRetryCount();
      debugPrint('❌ [OTP] Unexpected error: $e');
      
      return {
        'success': false,
        'error': 'unknown',
        'message': 'Verification failed. Please try again',
        'retriesLeft': maxOtpRetries - _otpRetryCount,
      };
    }
  }

  /// Send Email Magic Link (Passwordless)
  Future<Map<String, dynamic>> sendEmailMagicLink({
    required String email,
  }) async {
    try {
      // Check cooldown
      if (!canRequestOtp()) {
        final remaining = remainingCooldownSeconds;
        debugPrint('⏱️ [Email] Cooldown active: ${remaining}s remaining');
        return {
          'success': false,
          'error': 'cooldown',
          'message': 'Please wait $remaining seconds before requesting another link',
          'cooldownSeconds': remaining,
        };
      }

      debugPrint('📧 [Email] Sending magic link to: $email');

      // Use Firebase ActionCodeSettings for email link
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://multiverses-8d207.web.app/login',
        handleCodeInApp: true,
        iOSBundleId: 'com.example.multiversesss',
        androidPackageName: 'com.ayush.multiverse.multiverses',
        androidInstallApp: true,
        androidMinimumVersion: '1',
      );

      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );

      // Update state
      _lastOtpRequestTime = DateTime.now();
      _isCooldownActive = true;
      resetRetryCount();

      debugPrint('✅ [Email] Magic link sent successfully');

      return {
        'success': true,
        'message': 'Magic link sent to your email',
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [Email] Firebase error: ${e.code} - ${e.message}');
      
      String errorMessage = 'Failed to send magic link';
      if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Email already registered';
      }
      
      return {
        'success': false,
        'error': e.code,
        'message': errorMessage,
      };
    } catch (e) {
      debugPrint('❌ [Email] Unexpected error: $e');
      return {
        'success': false,
        'error': 'unknown',
        'message': 'Failed to send magic link. Please try again',
      };
    }
  }

  /// Verify Email Magic Link and sign in
  Future<Map<String, dynamic>> verifyEmailMagicLink({
    required String email,
    required String emailLink,
  }) async {
    try {
      debugPrint('🔐 [Email] Verifying magic link...');

      // Check if link is valid
      if (!_auth.isSignInWithEmailLink(emailLink)) {
        debugPrint('❌ [Email] Invalid email link');
        return {
          'success': false,
          'error': 'invalid_link',
          'message': 'Invalid magic link',
        };
      }

      final userCredential = await _auth.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );

      // Success
      _isCooldownActive = false;
      resetRetryCount();

      debugPrint('✅ [Email] Magic link verified: ${userCredential.user!.uid}');

      return {
        'success': true,
        'userCredential': userCredential,
        'message': 'Email verified successfully',
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [Email] Verification failed: ${e.code} - ${e.message}');
      
      return {
        'success': false,
        'error': e.code,
        'message': 'Failed to verify email link',
      };
    } catch (e) {
      debugPrint('❌ [Email] Unexpected error: $e');
      return {
        'success': false,
        'error': 'unknown',
        'message': 'Verification failed. Please try again',
      };
    }
  }

  /// Get current user info
  Map<String, dynamic>? getCurrentUserInfo() {
    final user = _auth.currentUser;
    if (user == null) return null;

    return {
      'uid': user.uid,
      'email': user.email,
      'phoneNumber': user.phoneNumber,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'emailVerified': user.emailVerified,
      'providers': user.providerData.map((p) => p.providerId).toList(),
    };
  }

  /// Reset OTP state (for cleanup)
  void resetOtpState() {
    _verificationId = null;
    _resendToken = null;
    _lastOtpRequestTime = null;
    _otpRetryCount = 0;
    _isCooldownActive = false;
    debugPrint('🔄 [OTP] State reset');
  }

  /// Debug: Print current OTP state
  void printOtpState() {
    debugPrint('📊 [OTP State]');
    debugPrint('   Verification ID: ${_verificationId != null ? "Set" : "Not set"}');
    debugPrint('   Retry Count: $_otpRetryCount/$maxOtpRetries');
    debugPrint('   Cooldown Active: $_isCooldownActive');
    debugPrint('   Remaining Cooldown: ${remainingCooldownSeconds}s');
    debugPrint('   Can Request OTP: ${canRequestOtp()}');
    debugPrint('   Can Retry OTP: ${canRetryOtp()}');
  }
}
