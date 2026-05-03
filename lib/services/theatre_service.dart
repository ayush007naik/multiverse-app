import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing theatre data in Firestore
/// Collection path: 'theatres'
class TheatreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a new theatre to the theatres collection
  Future<void> addTheatre({
    required String ownerId,
    required String name,
    required String address,
    bool isApproved = false,
  }) async {
    await _firestore.collection('theatres').add({
      'ownerId': ownerId,
      'name': name,
      'address': address,
      'isApproved': isApproved,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all theatres
  Stream<QuerySnapshot> getAllTheatres() {
    return _firestore.collection('theatres').snapshots();
  }

  /// Get theatres by owner ID
  Stream<QuerySnapshot> getTheatresByOwner(String ownerId) {
    return _firestore
        .collection('theatres')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots();
  }

  /// Update theatre approval status
  Future<void> updateTheatreApproval(String theatreId, bool isApproved) async {
    await _firestore.collection('theatres').doc(theatreId).update({
      'isApproved': isApproved,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
