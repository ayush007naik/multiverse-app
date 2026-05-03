import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing movie data in Firestore
/// Collection path: 'movies'
class MovieService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a new movie to the movies collection
  Future<void> addMovie({
    required String title,
    required String genre,
    required int duration,
    required double rating,
    required String language,
    required String posterUrl,
    required String description,
    required String status,
  }) async {
    await _firestore.collection('movies').add({
      'title': title,
      'genre': genre,
      'duration': duration,
      'rating': rating,
      'language': language,
      'posterUrl': posterUrl,
      'description': description,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all movies
  Stream<QuerySnapshot> getAllMovies() {
    return _firestore.collection('movies').snapshots();
  }

  /// Get movies by status
  Stream<QuerySnapshot> getMoviesByStatus(String status) {
    return _firestore
        .collection('movies')
        .where('status', isEqualTo: status)
        .snapshots();
  }

  /// Get theatres for a specific movie
  Stream<QuerySnapshot> getTheatresForMovie(String movieId) {
    return _firestore
        .collection('movies')
        .doc(movieId)
        .collection('theatres')
        .snapshots();
  }

  /// Add theatre to a movie
  Future<void> addTheatreToMovie({
    required String movieId,
    required String name,
    required String address,
    required int ticketPrice,
    required int totalSeats,
    required List<String> showTimes,
  }) async {
    await _firestore
        .collection('movies')
        .doc(movieId)
        .collection('theatres')
        .add({
      'name': name,
      'address': address,
      'ticketPrice': ticketPrice,
      'totalSeats': totalSeats,
      'showTimes': showTimes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
