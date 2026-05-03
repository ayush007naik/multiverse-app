import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'google_sign_in_diagnostics.dart';

// ─────────────────────────────────────────
//  User roles
// ─────────────────────────────────────────
enum UserRole { user, theatreOwner, admin }

extension UserRoleX on UserRole {
  String get value => switch (this) {
    UserRole.user => 'user',
    UserRole.theatreOwner => 'theatre_owner',
    UserRole.admin => 'admin',
  };

  static UserRole fromString(String? s) => switch (s) {
    'theatre_owner' => UserRole.theatreOwner,
    'admin' => UserRole.admin,
    _ => UserRole.user,
  };
}

// ─────────────────────────────────────────
//  AuthService
// ─────────────────────────────────────────
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Convenience getters ──────────────────
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ════════════════════════════════════════
  //  EMAIL – regular user signup
  // ════════════════════════════════════════
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _createUserDoc(
      uid: cred.user!.uid,
      name: name,
      email: email,
      role: UserRole.user,
    );
    return cred;
  }

  // ════════════════════════════════════════
  //  EMAIL – login (existing, unchanged)
  // ════════════════════════════════════════
  Future<UserCredential> loginWithEmail(
      String email, String password) async {
    return _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  // ════════════════════════════════════════
  //  THEATRE OWNER – signup
  //  Creates user doc + pending theatre doc
  // ════════════════════════════════════════
  Future<UserCredential> signUpTheatreOwner({
    required String email,
    required String password,
    required String ownerName,
    required String theatreName,
    required String address,
    required int totalRows,
    required int totalCols,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;

    // 1. User document
    await _createUserDoc(
      uid: uid,
      name: ownerName,
      email: email,
      role: UserRole.theatreOwner,
    );

    // 2. Theatre document – pending admin approval
    await _db.collection('theatres').add({
      'ownerId': uid,
      'ownerName': ownerName,
      'name': theatreName,
      'address': address,
      'totalRows': totalRows,
      'totalCols': totalCols,
      'isApproved': false,          // Admin approves later
      'isRejected': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  // ════════════════════════════════════════
  //  GOOGLE – sign in (your existing logic)
  //  Also ensures Firestore user doc exists
  // ════════════════════════════════════════
  Future<UserCredential?> signInWithGoogle() async {
    try {
      GoogleSignInDiagnostics.logConfigSummary();

      final GoogleSignInAccount? googleUser =
      await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
      await _auth.signInWithCredential(credential);

      // Create Firestore doc only on first Google login
      await _ensureUserDocExists(
        uid: userCred.user!.uid,
        name: userCred.user!.displayName ?? 'User',
        email: userCred.user!.email ?? '',
      );

      return userCred;
    } on PlatformException catch (e, st) {
      GoogleSignInDiagnostics.logFailure(e, st,
          source: 'auth_service/platform');
      rethrow;
    } catch (e) {
      GoogleSignInDiagnostics.logFailure(e, StackTrace.current,
          source: 'auth_service/unexpected');
      rethrow;
    }
  }

  // ════════════════════════════════════════
  //  PHONE OTP – send (unchanged)
  // ════════════════════════════════════════
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken)
    codeSent,
    required void Function(PhoneAuthCredential credential)
    verificationCompleted,
    required void Function(FirebaseAuthException exception)
    verificationFailed,
    required void Function(String verificationId)
    codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  // ════════════════════════════════════════
  //  PHONE OTP – verify
  //  Also ensures Firestore user doc exists
  // ════════════════════════════════════════
  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
    String name = 'User',          // pass name if known
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCred = await _auth.signInWithCredential(credential);

    await _ensureUserDocExists(
      uid: userCred.user!.uid,
      name: name,
      email: userCred.user!.email ?? '',
    );

    return userCred;
  }

  // ════════════════════════════════════════
  //  ROLE – fetch current user's role
  // ════════════════════════════════════════
  Future<UserRole> getCurrentRole() async {
    final uid = currentUser?.uid;
    if (uid == null) return UserRole.user;
    final doc = await _db.collection('users').doc(uid).get();
    return UserRoleX.fromString(doc.data()?['role']);
  }

  // ════════════════════════════════════════
  //  THEATRE OWNER – fetch theatre status
  // ════════════════════════════════════════
  Future<Map<String, dynamic>?> getMyTheatre() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final snap = await _db
        .collection('theatres')
        .where('ownerId', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }

  // ════════════════════════════════════════
  //  LOGOUT (your existing logic)
  // ════════════════════════════════════════
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ════════════════════════════════════════
  //  PRIVATE HELPERS
  // ════════════════════════════════════════

  /// Creates a fresh Firestore user doc
  Future<void> _createUserDoc({
    required String uid,
    required String name,
    required String email,
    required UserRole role,
  }) async {
    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'role': role.value,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Creates user doc only if it doesn't already exist
  /// Used after Google / Phone sign-in (may be returning user)
  Future<void> _ensureUserDocExists({
    required String uid,
    required String name,
    required String email,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'name': name,
        'email': email,
        'role': UserRole.user.value,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
