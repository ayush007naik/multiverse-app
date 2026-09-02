import "package:firebase_auth/firebase_auth.dart";
import "package:db_compat/db_compat.dart";
import "package:flutter/material.dart";
import "dart:async";
import "signup_provider.dart";

enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticated,
  pendingApproval,
  error
}

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  AuthStatus _status = AuthStatus.unauthenticated;
  String? _errorMessage;
  Map<String, dynamic>? _partnerData;
  StreamSubscription? _partnerSub;

  User? get user => _user;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get partnerData => _partnerData;

  PartnerCategory get partnerCategory {
    final catStr = _partnerData?["category"]?.toString().toLowerCase() ?? "";
    if (catStr.contains("doctor")) return PartnerCategory.doctor;
    if (catStr.contains("dentist")) return PartnerCategory.dentist;
    if (catStr.contains("salon")) return PartnerCategory.salon;
    if (catStr.contains("lab")) return PartnerCategory.lab;
    if (catStr.contains("car")) return PartnerCategory.carService;
    return PartnerCategory.doctor; // Default
  }

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _partnerSub?.cancel();
      _partnerData = null;
    } else {
      _user = firebaseUser;
      _status = AuthStatus.authenticating;
      notifyListeners();
      await checkUserStatus();
    }
    notifyListeners();
  }

  Future<void> checkUserStatus() async {
    _user = _auth.currentUser;
    debugPrint("Checking status for user: ${_user?.uid}");
    
    if (_user == null) {
      _status = AuthStatus.unauthenticated;
      _partnerData = null;
      _partnerSub?.cancel();
      notifyListeners();
      return;
    }

    _partnerSub?.cancel();

    try {
      // 1. Check if they are already an active partner
      final partnerDocRef = _firestore.collection("partners").doc(_user!.uid);
      final partnerDoc = await partnerDocRef.get();
      
      if (partnerDoc.exists) {
        debugPrint("Partner profile found in 'partners' collection");
        _status = AuthStatus.authenticated;
        _startPartnerStream(partnerDocRef);
        notifyListeners();
        return;
      }

      // 2. Check if they have a pending application
      final appDocRef = _firestore.collection("partner_applications").doc(_user!.uid);
      final appDoc = await appDocRef.get();
      
      if (appDoc.exists) {
        debugPrint("Application found in 'partner_applications' collection");
        final appData = appDoc.data()!;
        final statusStr = appData["status"] ?? "pending";
        _status = (statusStr == "approved") ? AuthStatus.authenticated : AuthStatus.pendingApproval;
        _startPartnerStream(appDocRef);
        notifyListeners();
        return;
      }

      // 2b. Legacy/edge cases: partner profile or application stored under an
      // auto-id document with the real UID inside the `userId` field (spread
      // from the `data` catch-all, so query the top-level key).
      try {
        final appByUid = await _firestore.collection("partner_applications")
            .where("userId", isEqualTo: _user!.uid)
            .get();
        if (appByUid.docs.isNotEmpty) {
          debugPrint("Application found by userId in 'partner_applications'");
          final appData = appByUid.docs.first.data();
          final statusStr = appData["status"] ?? "pending";
          _status = (statusStr == "approved") ? AuthStatus.authenticated : AuthStatus.pendingApproval;
          _startPartnerStream(appByUid.docs.first.reference);
          notifyListeners();
          return;
        }

        final partnerByUid = await _firestore.collection("partners")
            .where("userId", isEqualTo: _user!.uid)
            .get();
        if (partnerByUid.docs.isNotEmpty) {
          debugPrint("Partner profile found by userId in 'partners'");
          _status = AuthStatus.authenticated;
          _startPartnerStream(partnerByUid.docs.first.reference);
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint("userId lookup failed: $e");
      }

      // 3. Fallback to email search for application (legacy or edge cases)
      try {
        final email = _user!.email;
        if (email != null) {
          final appQuery = await _firestore.collection("partner_applications")
              .where("basic_info.email", isEqualTo: email.trim())
              .get();
          
          if (appQuery.docs.isNotEmpty) {
            debugPrint("Application found by email in 'partner_applications'");
            final appData = appQuery.docs.first.data();
            final statusStr = appData["status"] ?? "pending";
            _status = (statusStr == "approved") ? AuthStatus.authenticated : AuthStatus.pendingApproval;
            _startPartnerStream(appQuery.docs.first.reference);
            notifyListeners();
            return;
          }
        }
      } catch (e) {
        debugPrint("Email lookup in partner_applications failed (permissions): $e");
      }

      // 4. Check global users collection for roles
      try {
        final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final List<dynamic> roles = userData['roles'] ?? [];
          final List<dynamic> registeredApps = userData['registered_apps'] ?? [];
          final String? globalRole = userData['role'];
          
          bool hasAppointmentRole = roles.contains('appointment_partner') || 
                                   registeredApps.contains('appointment_partner') ||
                                   roles.contains('appointment_pending') ||
                                   globalRole == 'appointment_partner' ||
                                   globalRole == 'appointment_pending';
                                   
          if (hasAppointmentRole) {
            debugPrint("User has appointment role in 'users' collection");
            if (roles.contains('appointment_partner') || globalRole == 'appointment_partner') {
              _status = AuthStatus.authenticated;
            } else {
              _status = AuthStatus.pendingApproval;
            }
            notifyListeners();
            return;
          } else {
            _status = AuthStatus.unauthenticated;
            _errorMessage = "Access denied. No appointment partner profile found.";
            await _auth.signOut();
          }
        } else {
          _status = AuthStatus.unauthenticated;
          _errorMessage = "Profile not found. Please sign up.";
          await _auth.signOut();
        }
      } catch (e) {
        debugPrint("Error reading user document: $e");
        _status = AuthStatus.error;
        _errorMessage = "Error verifying account: $e";
      }
    } catch (e) {
      debugPrint("Error checking user status: $e");
      _status = AuthStatus.error;
      _errorMessage = "Error verifying account: $e";
    }
    notifyListeners();
  }

  void _startPartnerStream(DocumentReference ref) {
    _partnerSub = ref.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _partnerData = snapshot.data();
        // Approved partners live in `partners/{uid}` with status 'active'
        // (written by admin approval), while applications use 'approved'.
        // Both mean the user has been approved and may use the dashboard.
        final statusStr = _partnerData?["status"] ?? "pending";
        if (statusStr == "approved" || statusStr == "active") {
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.pendingApproval;
        }
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _partnerSub?.cancel();
    super.dispose();
  }

  Future<bool> login(String email, String password) async {
    debugPrint("Attempting login for: $email");
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await checkUserStatus();
      return _status == AuthStatus.authenticated || _status == AuthStatus.pendingApproval;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      if (e.message != null && e.message!.contains("supplied auth credential is incorrect")) {
          _errorMessage = "Invalid login session. Please check your credentials or refresh the page.";
      } else {
          _errorMessage = e.message;
      }
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = "An unexpected error occurred.";
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _partnerSub?.cancel();
    await _auth.signOut();
  }

  /// Re-authenticates with [currentPassword] and updates the password to
  /// [newPassword]. Returns `true` on success; on failure the reason is in
  /// [errorMessage].
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _errorMessage = null;
    notifyListeners();

    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = "You are not signed in.";
      notifyListeners();
      return false;
    }
    final email = user.email;
    if (email == null) {
      _errorMessage = "No email address found on this account.";
      notifyListeners();
      return false;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? "Failed to change password. Please try again.";
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = "An unexpected error occurred. Please try again.";
      notifyListeners();
      return false;
    }
  }
}
