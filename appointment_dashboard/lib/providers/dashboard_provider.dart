import "package:db_compat/db_compat.dart";
import "package:flutter/material.dart";
import "dart:async";

class DashboardProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  Map<String, dynamic> _stats = {
    "total_sessions": 0,
    "revenue": 0,
    "clients_count": 0,
    "rating": 0.0,
  };
  List<Map<String, dynamic>> _recentAppointments = [];
  List<Map<String, dynamic>> _allAppointments = [];
  List<Map<String, dynamic>> _medicalRecords = [];
  List<Map<String, dynamic>> _services = [];
  List<String> _selectedSubCategories = [];
  bool _isAcceptingAppointments = true;
  Map<String, dynamic> _schedule = {};
  double _bookingAmount = 0.0;
  DateTime? _lastBookingAmountUpdate;

  StreamSubscription? _appointmentsSub;
  StreamSubscription? _partnerSub;
  StreamSubscription? _recordsSub;

  bool _appointmentsLoaded = false;
  bool _partnerLoaded = false;

  bool get isLoading => _isLoading;
  Map<String, dynamic> get stats => _stats;
  List<Map<String, dynamic>> get recentAppointments => _recentAppointments;
  List<Map<String, dynamic>> get allAppointments => _allAppointments;
  List<Map<String, dynamic>> get medicalRecords => _medicalRecords;
  List<Map<String, dynamic>> get services => _services;
  List<String> get selectedSubCategories => _selectedSubCategories;
  bool get isAcceptingAppointments => _isAcceptingAppointments;
  Map<String, dynamic> get schedule => _schedule;
  double get bookingAmount => _bookingAmount;
  DateTime? get lastBookingAmountUpdate => _lastBookingAmountUpdate;

  void startRealtimeUpdates(String partnerId) {
    final cleanId = partnerId.trim();
    debugPrint("Starting real-time updates for partner: $cleanId");
    _isLoading = true;
    _appointmentsLoaded = false;
    _partnerLoaded = false;
    notifyListeners();

    // 1. Listen to Appointments
    _appointmentsSub?.cancel();
    _appointmentsSub = _firestore
        .collection("appointments")
        .where("partnerId", isEqualTo: cleanId)
        .snapshots()
        .listen((snapshot) {
      int totalSessions = snapshot.docs.length;
      int revenue = 0;
      Set<String> uniqueClients = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final price = data["price"] ?? data["bookingAmount"] ?? 0;
        if (price is num) {
          revenue += price.toInt();
        }
        final userId = data["userId"];
        if (userId != null && userId.toString().isNotEmpty) {
          uniqueClients.add(userId.toString());
        }
      }

      _stats = {
        ..._stats,
        "total_sessions": totalSessions,
        "revenue": revenue,
        "clients_count": uniqueClients.length,
      };

      final sortedDocs = snapshot.docs.toList()
        ..sort((a, b) {
          final aTime = (a.data()["timestamp"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime = (b.data()["timestamp"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

      _allAppointments = sortedDocs.map((doc) => {
        "id": doc.id,
        ...doc.data(),
      }).toList();

      _recentAppointments = _allAppointments.take(10).toList();

      _appointmentsLoaded = true;
      if (_partnerLoaded) _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error in appointments stream: $e");
      _isLoading = false;
      notifyListeners();
    });

    // 2. Listen to Partner Profile
    _startPartnerStream(cleanId);

    // 3. Listen to Medical Records
    _recordsSub?.cancel();
    _recordsSub = _firestore
        .collection("medical_records")
        .where("partnerId", isEqualTo: cleanId)
        .snapshots()
        .listen((snapshot) {
      _medicalRecords = snapshot.docs.map((doc) => {
        "id": doc.id,
        ...doc.data(),
      }).toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error in medical records stream: $e");
    });
  }

  void _startPartnerStream(String partnerId) async {
    _partnerSub?.cancel();
    
    // Check which collection has the data
    try {
      final partnerDoc = await _firestore.collection("partners").doc(partnerId).get();
      DocumentReference ref;
      
      if (partnerDoc.exists) {
        ref = _firestore.collection("partners").doc(partnerId);
      } else {
        // Check partners collection by userId first
        final partnerQuery = await _firestore.collection("partners")
            .where("userId", isEqualTo: partnerId)
            .get();
            
        if (partnerQuery.docs.isNotEmpty) {
          ref = partnerQuery.docs.first.reference;
        } else {
          // Then try partner_applications
          final appQuery = await _firestore.collection("partner_applications")
              .where("userId", isEqualTo: partnerId)
              .get();
          if (appQuery.docs.isNotEmpty) {
            ref = appQuery.docs.first.reference;
          } else {
            ref = _firestore.collection("partner_applications").doc(partnerId);
          }
        }
      }

      _partnerSub = ref.snapshots().listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data != null) {
            if (data["services"] != null && data["services"] is List) {
              _services = (data["services"] as List).whereType<Map<String, dynamic>>().toList();
            }
            if (data["selectedSubCategories"] != null) {
              _selectedSubCategories = List<String>.from(data["selectedSubCategories"]);
            } else if (data["professional_details"]?["specialization"] != null) {
              // Fallback to legacy single specialization if multiple selection isn't set yet
              _selectedSubCategories = [data["professional_details"]["specialization"]];
            }
            
            _isAcceptingAppointments = data["isAcceptingAppointments"] ?? true;
            _bookingAmount = (data["bookingAmount"] is num ? (data["bookingAmount"] as num).toDouble() : double.tryParse(data["bookingAmount"]?.toString() ?? "") ?? 0.0);
            if (data["lastBookingAmountUpdate"] != null) {
              _lastBookingAmountUpdate = (data["lastBookingAmountUpdate"] as Timestamp).toDate();
            }
            _schedule = data["schedule"] ?? {};
            _stats = {
              ..._stats,
              "rating": (data["rating"] ?? 0.0).toDouble(),
            };
            _partnerLoaded = true;
            if (_appointmentsLoaded) _isLoading = false;
            notifyListeners();
          }
        }
      });
    } catch (e) {
      debugPrint("Error starting partner stream: $e");
    }
  }

  @override
  void dispose() {
    _appointmentsSub?.cancel();
    _partnerSub?.cancel();
    _recordsSub?.cancel();
    super.dispose();
  }

  Future<void> _updateProfileData(String partnerId, Map<String, dynamic> data) async {
    final cleanId = partnerId.trim();
    int updateCount = 0;
    List<String> errors = [];

    // Helper to safely update a document and catch permission errors
    Future<void> safeUpdate(DocumentReference ref) async {
      try {
        await ref.update(data);
        updateCount++;
      } catch (e) {
        debugPrint("Update failed for ${ref.path}: $e");
        errors.add(e.toString());
      }
    }

    // 1. Update in partners collection (by doc ID)
    final partnerRef = _firestore.collection("partners").doc(cleanId);
    try {
      final partnerDoc = await partnerRef.get();
      if (partnerDoc.exists) {
        await safeUpdate(partnerRef);
      }
    } catch (e) {
      debugPrint("Error checking partner doc $cleanId: $e");
    }

    // 2. Update in partners collection (by userId field)
    try {
      final partnerQuery = await _firestore.collection("partners")
          .where("userId", isEqualTo: cleanId)
          .get();
      for (var doc in partnerQuery.docs) {
        if (doc.id != cleanId) {
          await safeUpdate(doc.reference);
        }
      }
    } catch (e) {
      debugPrint("Error querying partners by userId: $e");
    }

    // 3. Update in partner_applications (by userId field)
    try {
      final appQuery = await _firestore.collection("partner_applications")
          .where("userId", isEqualTo: cleanId)
          .get();
      for (var doc in appQuery.docs) {
        if (doc.id != cleanId) {
           await safeUpdate(doc.reference);
        }
      }
    } catch (e) {
      debugPrint("Error querying partner_applications by userId: $e");
    }

    // 4. Update in partner_applications (by doc ID)
    if (cleanId.isNotEmpty) {
      final appRef = _firestore.collection("partner_applications").doc(cleanId);
      try {
        final appDoc = await appRef.get();
        if (appDoc.exists) {
          await safeUpdate(appRef);
        }
      } catch (e) {
        debugPrint("Error checking app doc $cleanId: $e");
      }
    }

    if (updateCount == 0) {
      if (errors.isNotEmpty) {
        throw Exception("Permission Denied: Could not update any profile documents. Please check if you are logged in correctly.");
      } else {
        throw Exception("Profile not found in any collection.");
      }
    }
  }

  Future<void> toggleAppointmentStatus(String partnerId, bool value) async {
    try {
      await _updateProfileData(partnerId, {"isAcceptingAppointments": value});
      _isAcceptingAppointments = value;
      notifyListeners();
    } catch (e) {
      debugPrint("Error toggling status: $e");
    }
  }

  Future<void> updateSchedule(String partnerId, Map<String, dynamic> newSchedule) async {
    try {
      await _updateProfileData(partnerId, {"schedule": newSchedule});
      _schedule = newSchedule;
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating schedule: $e");
    }
  }

  Future<void> updateServices(String partnerId, List<Map<String, dynamic>> updatedServices) async {
    try {
      await _updateProfileData(partnerId, {"services": updatedServices});
      _services = updatedServices;
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating services: $e");
    }
  }

  Future<void> updateBookingAmount(String partnerId, double amount) async {
    try {
      final now = DateTime.now();
      await _updateProfileData(partnerId, {
        "bookingAmount": amount,
        "lastBookingAmountUpdate": Timestamp.fromDate(now),
      });
      _bookingAmount = amount;
      _lastBookingAmountUpdate = now;
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating booking amount: $e");
    }
  }

  Future<void> updateSubCategories(String partnerId, List<String> categories) async {
    try {
      await _updateProfileData(partnerId, {
        "selectedSubCategories": categories,
        "professional_details.specialization": categories.isNotEmpty ? categories.first : "",
      });
      _selectedSubCategories = categories;
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating sub-categories: $e");
    }
  }

  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await _firestore.collection("appointments").doc(appointmentId).update({
        "status": status,
      });
    } catch (e) {
      debugPrint("Error updating appointment status: $e");
    }
  }

  Future<void> uploadMedicalRecord(Map<String, dynamic> record) async {
    try {
      await _firestore.collection("medical_records").add({
        ...record,
        "timestamp": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error uploading medical record: $e");
      rethrow;
    }
  }

  Future<void> refreshData(String partnerId) async {
    startRealtimeUpdates(partnerId);
  }

  Future<void> fetchDashboardData(String partnerId) async {
    startRealtimeUpdates(partnerId);
  }
}
