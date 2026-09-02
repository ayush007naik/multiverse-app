import 'dart:async';
import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';

class AppointmentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _allApplications = [];
  List<Map<String, dynamic>> _agreements = [];
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;
  StreamSubscription<QuerySnapshot>? _appsSub;
  StreamSubscription<QuerySnapshot>? _agreementsSub;

  List<Map<String, dynamic>> get pendingApplications => 
      _allApplications.where((app) => app['status'] == 'pending').toList();
  
  List<Map<String, dynamic>> get approvedApplications => 
      _allApplications.where((app) => app['status'] == 'approved').toList();
      
  List<Map<String, dynamic>> get rejectedApplications => 
      _allApplications.where((app) => app['status'] == 'rejected').toList();

  List<Map<String, dynamic>> get agreements => _agreements;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AppointmentProvider() {
    _listenToApplications();
    _listenToAgreements();
  }

  @override
  void dispose() {
    _disposed = true;
    _appsSub?.cancel();
    _agreementsSub?.cancel();
    super.dispose();
  }

  void _listenToApplications() {
    _appsSub?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _appsSub = _firestore
        .collection('partner_applications')
        .snapshots()
        .listen((snapshot) {
      debugPrint('Received ${snapshot.docs.length} total applications');
      _allApplications = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error listening to applications: $error');
      _error = error.toString();
      _isLoading = false;
      notifyListeners();
      if (!_disposed) {
        Future.delayed(const Duration(seconds: 3), () {
          if (!_disposed) _listenToApplications();
        });
      }
    });
  }

  void _listenToAgreements() {
    _agreementsSub?.cancel();
    _agreementsSub = _firestore
        .collection('partners')
        .orderBy('approved_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      _agreements = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error listening to agreements: $error');
    });
  }

  Future<void> updateApplicationStatus(String id, String status) async {
    try {
      await _firestore.collection('partner_applications').doc(id).update({
        'status': status,
        'updated_at': DateTime.now().toUtc(),
      });
      
      if (status == 'approved') {
        final doc = await _firestore.collection('partner_applications').doc(id).get();
        final data = doc.data();
        if (data != null) {
          final String userId = data["userId"] ?? id;
          // Ensure we use the userId as the document ID for the partner profile
          await _firestore.collection('partners').doc(userId).set({
            ...data,
            'status': 'active',
            'approved_at': DateTime.now().toUtc(),
          });
          
          // Update global users collection - promote to 'appointment_partner' role.
          // db_compat skips FieldValue sentinels and has no arrayUnion support,
          // so preserve any existing roles and write plain lists.
          final roles = <String>[];
          final registeredApps = <String>[];
          try {
            final existingUser = await _firestore.collection('users').doc(userId).get();
            if (existingUser.exists) {
              final ud = existingUser.data()!;
              roles.addAll((ud['roles'] as List<dynamic>?)
                      ?.map((r) => r.toString()) ??
                  const []);
              registeredApps.addAll((ud['registered_apps'] as List<dynamic>?)
                      ?.map((r) => r.toString()) ??
                  const []);
              roles.remove('appointment_pending');
            }
          } catch (e) {
            debugPrint('Error reading existing user for approval: $e');
          }
          roles.add('appointment_partner');
          registeredApps.add('appointment_partner');
          await _firestore.collection('users').doc(userId).set({
            'role': 'appointment_partner',
            'roles': roles,
            'registered_apps': registeredApps,
            'updatedAt': DateTime.now().toUtc(),
          }, SetOptions(merge: true));

          // If the original application had a different ID, also update the applications collection
          if (id != userId) {
             await _firestore.collection('partner_applications').doc(id).update({
               'partnerProfileCreated': true,
             });
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }
}
