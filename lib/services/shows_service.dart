import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing show data in Firestore
/// Collection path: 'shows'
class ShowsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a new show to the shows collection
  Future<void> addShow({
    required String theatreId,
    required String movieId,
    required DateTime dateTime,
    required int price,
    required List<Map<String, dynamic>> seatsLayout,
  }) async {
    await _firestore.collection('shows').add({
      'theatreId': theatreId,
      'movieId': movieId,
      'dateTime': dateTime,
      'price': price,
      'seatsLayout': seatsLayout,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all shows
  Stream<QuerySnapshot> getAllShows() {
    return _firestore.collection('shows').snapshots();
  }

  /// Get shows by theatre ID
  Stream<QuerySnapshot> getShowsByTheatre(String theatreId) {
    return _firestore
        .collection('shows')
        .where('theatreId', isEqualTo: theatreId)
        .snapshots();
  }

  /// Get shows by movie ID
  Stream<QuerySnapshot> getShowsByMovie(String movieId) {
    return _firestore
        .collection('shows')
        .where('movieId', isEqualTo: movieId)
        .snapshots();
  }

  /// Get shows by theatre and movie
  Stream<QuerySnapshot> getShowsByTheatreAndMovie(String theatreId, String movieId) {
    return _firestore
        .collection('shows')
        .where('theatreId', isEqualTo: theatreId)
        .where('movieId', isEqualTo: movieId)
        .snapshots();
  }
}
