import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:db_compat/db_compat.dart';
import '../services/signup_service.dart';
import '../services/logout_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SignupService _signupService = SignupService();

  User? _user;
  bool _isLoading = true;
  Map<String, dynamic>? _theatreData;
  Map<String, dynamic>? _agreementData;
  String? _requestStatus;
  String? _agreementError;
  bool _signupInProgress = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get theatreData => _theatreData;
  Map<String, dynamic>? get agreementData => _agreementData;
  String? get requestStatus => _requestStatus;
  String? get agreementError => _agreementError;
  bool get signupInProgress => _signupInProgress;

  /// Suppress notifyListeners() during signup to prevent AuthWrapper rebuilds
  void setSignupInProgress(bool value) {
    _signupInProgress = value;
  }

  StreamSubscription<QuerySnapshot>? _agreementSubscription;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        debugPrint(
          "Theatre auth session: uid=${user.uid}, email=${user.email ?? 'unknown'}",
        );

        // If signup is in progress, skip security checks and dashboard redirection
        // The wizard handles the flow and will eventually sign out or finish.
        if (_signupInProgress) {
          _isLoading = false;
          return;
        }

        _isLoading = true;
        notifyListeners();

        // Security check: verify this account has a theatre profile/request.
        // Do not depend on users/{uid}; some deployed rules/App Check setups deny
        // that collection before the dashboard is fully initialized.
        try {
          await _ensureFirestoreAuthReady(user);
          if (_auth.currentUser?.uid != user.uid) {
            _isLoading = false;
            return;
          }
          final theatreDoc =
              await _firestore.collection('theatres').doc(user.uid).get();
          if (_auth.currentUser?.uid != user.uid) {
            _isLoading = false;
            return;
          }
          if (!theatreDoc.exists) {
            final reqDoc = await _getTheatreRequestDoc(user.uid);
            if (_auth.currentUser?.uid != user.uid) {
              _isLoading = false;
              return;
            }
            if (!reqDoc.exists) await _denyTheatreAccess(user.uid);
            if (!reqDoc.exists) return;
          }
        } catch (e) {
          debugPrint(
            "Error verifying roles for uid=${user.uid}, "
            "email=${user.email ?? 'unknown'}: $e",
          );
          // If it's a permission error, it's likely a new user that hasn't been fully provisioned
          // but we should still check if they are in the partner requests
        }

        await _fetchTheatreDataInternal();
        _startAgreementListener(user.uid);
      } else {
        _theatreData = null;
        _agreementData = null;
        _agreementError = null;
        _agreementSubscription?.cancel();
      }
      _isLoading = false;
      if (!_signupInProgress) {
        notifyListeners();
      }
    });
  }

  Future<void> _ensureFirestoreAuthReady(User user) async {
    // On web, the Auth state can fire before Firestore has a usable ID token.
    // Force a token refresh before protected reads to avoid first-read denial.
    await user.getIdToken(true);
  }

  Future<void> _denyTheatreAccess(String expectedUid) async {
    // When staff accounts are created, createUserWithEmailAndPassword briefly
    // signs in as the new staff member before we re-auth as the admin. A stale
    // check for that staff user may finish after the admin session is already
    // active, so never sign out unless the session still belongs to the user
    // we are verifying.
    if (_auth.currentUser?.uid != expectedUid) return;
    await _auth.signOut();
    _isLoading = false;
    notifyListeners();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getTheatreRequestDoc(
    String uid,
  ) async {
    try {
      return await _firestore
          .collection('theatre_partner_requests')
          .doc(uid)
          .get();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _auth.currentUser?.getIdToken(true);
      return await _firestore
          .collection('theatre_partner_requests')
          .doc(uid)
          .get();
    }
  }

  void _startAgreementListener(String uid) {
    _agreementSubscription?.cancel();
    final query =
        _firestore.collection('theatre_agreements').where('theatreId', isEqualTo: uid);
    _agreementSubscription = query.snapshots().listen((snap) {
      _agreementError = null;
      if (snap.docs.isNotEmpty) {
        final docs = snap.docs.map((d) => d.data()).toList();
        // Prefer signed agreement
        final signedDoc = docs.firstWhere(
          (data) =>
              (data['status'] ?? '').toString().toLowerCase().trim() ==
              'signed',
          orElse: () => docs.first,
        );
        _agreementData = signedDoc;
        debugPrint(
          "Agreement updated via stream: status=${_agreementData!['status']}",
        );
      } else {
        _agreementData = null;
      }
      notifyListeners();
    }, onError: (Object error, StackTrace stackTrace) {
      _agreementData = null;
      _agreementError = _formatFirestoreError(error);
      debugPrint("Error listening to agreement data: $error");
      notifyListeners();

      if (error is FirebaseException && error.code == 'permission-denied') {
        Future<void>.delayed(const Duration(milliseconds: 750), () async {
          final currentUser = _auth.currentUser;
          if (currentUser == null || currentUser.uid != uid) return;
          await currentUser.getIdToken(true);
          _startAgreementListener(uid);
        });
      }
    });
  }

  String _formatFirestoreError(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Firestore permission denied. Please deploy updated Firestore '
          'rules for theatre_agreements.';
    }
    return error.toString();
  }

  @override
  void dispose() {
    _agreementSubscription?.cancel();
    super.dispose();
  }

  Future<void> fetchTheatreData() async {
    if (_user == null) return;
    try {
      await _auth.currentUser?.getIdToken(true);
      final doc = await _firestore.collection('theatres').doc(_user!.uid).get();
      if (doc.exists) {
        _theatreData = doc.data();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching theatre data: $e");
    }
  }

  Future<void> fetchAgreementData() async {
    // This is now handled by the stream, but we can manually trigger if needed
    if (_user == null) return;
    try {
      await _auth.currentUser?.getIdToken(true);
      final snap = await _firestore
          .collection('theatre_agreements')
          .where('theatreId', isEqualTo: _user!.uid)
          .get();
      _agreementError = null;
      if (snap.docs.isNotEmpty) {
        final docs = snap.docs.map((d) => d.data()).toList();
        final signedDoc = docs.firstWhere(
          (data) =>
              (data['status'] ?? '').toString().toLowerCase().trim() ==
              'signed',
          orElse: () => docs.first,
        );
        _agreementData = signedDoc;
      } else {
        _agreementData = null;
      }
      notifyListeners();
    } catch (e) {
      _agreementError = _formatFirestoreError(e);
      debugPrint("Error fetching agreement data: $e");
      notifyListeners();
    }
  }

  Future<void> _fetchTheatreDataInternal() async {
    if (_user == null) return;
    try {
      // 1. Try fetching from approved theatres
      await _auth.currentUser?.getIdToken(true);
      final doc = await _firestore.collection('theatres').doc(_user!.uid).get();
      if (doc.exists) {
        _theatreData = doc.data();
        return;
      }

      // 2. Try fetching from partner requests if not found in theatres
      final reqDoc = await _getTheatreRequestDoc(_user!.uid);
      if (reqDoc.exists) {
        final data = reqDoc.data()!;
        // Unify rejection reason for UI consistency with MainDashboard
        if (data['admin'] != null && data['admin']['reason'] != null) {
          data['rejectionReason'] = data['admin']['reason'];
        }
        _theatreData = data;
      }
    } catch (e) {
      debugPrint("Error fetching theatre data: $e");
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final String uid = credential.user!.uid;
      await _ensureFirestoreAuthReady(credential.user!);
      debugPrint(
        "Theatre login successful: uid=$uid, email=${credential.user?.email ?? email}",
      );

      final theatreDoc = await _firestore.collection('theatres').doc(uid).get();
      final requestDoc =
          theatreDoc.exists ? null : await _getTheatreRequestDoc(uid);

      if (!theatreDoc.exists && requestDoc?.exists != true) {
        await _auth.signOut();
        return "No theatre profile found for this account.";
      }

      await _fetchTheatreDataInternal();
      notifyListeners(); // Ensure AuthWrapper rebuilds to check isApproved
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await _auth.signOut();
        return 'Firestore permission denied while loading theatre profile. '
            'Deploy the updated Firestore rules and try again.';
      }
      return e.message ?? e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await LogoutService.signOutOnly();
  }

  bool get isApproved {
    if (_theatreData == null) return false;
    return _theatreData!['status'] == 'approved';
  }

  bool get isAgreementSigned {
    if (_agreementData == null) return false;
    final status = _agreementData!['status']?.toString().toLowerCase() ?? '';
    return status == 'signed';
  }

  Future<String?> checkSignupStatus(String email) async {
    return await _signupService.checkRequestStatus(email);
  }
}
