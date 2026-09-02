// 📁 lib/services/cinema_service.dart
// Real-time cinema and theatre management service

import 'package:db_compat/db_compat.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../core/logging_service.dart';

class CinemaService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch all cinemas that are showing a specific movie
  /// Sorted by distance (nearest first, when user position is available)
  static Future<List<Map<String, dynamic>>> getNearbyCinemas({
    required String movieId,
    Position? userPosition,
  }) async {
    try {
      Log.i('CinemaService', '--- SEARCHING CINEMAS VIA SHOWS ---');
      Log.i('CinemaService', 'Movie ID: $movieId');

      // 1. Find all active shows for this movie
      var showsSnapshot = await _firestore
          .collection('shows')
          .where('movieId', isEqualTo: movieId)
          .where('isActive', isEqualTo: true)
          .get();

      if (showsSnapshot.docs.isEmpty) {
        Log.w(
          'CinemaService',
          '⚠️ No active shows found for movie $movieId in "shows" collection.',
        );
        return [];
      }

      // 2. Extract unique theatre IDs
      Set<String> theatreIds = showsSnapshot.docs
          .map((doc) => doc.data()['theatreId'] as String)
          .where((id) => id.isNotEmpty)
          .toSet();

      if (theatreIds.isEmpty) return [];

      // 3. Fetch theatre details for these IDs
      List<DocumentSnapshot> theatreDocs = [];
      List<String> idsList = theatreIds.toList();

      // Firestore 'whereIn' supports up to 30 elements
      for (var i = 0; i < idsList.length; i += 30) {
        var end = (i + 30 < idsList.length) ? i + 30 : idsList.length;
        var chunk = idsList.sublist(i, end);
        var snapshot = await _firestore
            .collection('theatres')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        theatreDocs.addAll(snapshot.docs);
      }

      Log.i(
        'CinemaService',
        'Found ${theatreDocs.length} unique theatres showing this movie',
      );

      List<Map<String, dynamic>> cinemas = [];

      for (var doc in theatreDocs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['isActive'] == false) continue; // Skip inactive theatres

        // Robust coordinate parsing
        double cinemaLat = 0.0;
        double cinemaLng = 0.0;
        bool hasCoordinates = false;

        try {
          if (data['latitude'] != null) {
            cinemaLat = (data['latitude'] is String)
                ? double.parse(data['latitude'])
                : (data['latitude'] as num).toDouble();
          }
          if (data['longitude'] != null) {
            cinemaLng = (data['longitude'] is String)
                ? double.parse(data['longitude'])
                : (data['longitude'] as num).toDouble();
          }
          hasCoordinates = cinemaLat != 0.0 || cinemaLng != 0.0;
        } catch (e) {
          Log.w(
            'CinemaService',
            'Error parsing coordinates for ${data['cinemaName']}: $e',
          );
        }

        // Distance is optional - only computed when user position is available
        double? distance;
        if (userPosition != null && hasCoordinates) {
          distance =
              Geolocator.distanceBetween(
                userPosition.latitude,
                userPosition.longitude,
                cinemaLat,
                cinemaLng,
              ) /
              1000;
        }

        cinemas.add({
          'id': doc.id,
          'cinemaName':
              data['name'] ?? data['cinemaName'] ?? 'Unnamed Cinema',
          'city': data['city'] ?? 'Unknown City',
          'latitude': cinemaLat,
          'longitude': cinemaLng,
          'formats': data['formats'] ?? ['2D'],
          'distance': distance,
        });
      }

      // Sort by distance (nearest first, theatres without distance last)
      cinemas.sort((a, b) {
        final ad = (a['distance'] as double?) ?? double.maxFinite;
        final bd = (b['distance'] as double?) ?? double.maxFinite;
        return ad.compareTo(bd);
      });

      return cinemas;
    } catch (e) {
      Log.e('CinemaService', 'CRITICAL Error in getNearbyCinemas: $e', ex: e);
      return [];
    }
  }

  /// Get real-time show timings for a specific theatre and movie
  static Future<List<Map<String, dynamic>>> getShowTimings({
    required String theatreId,
    required String movieId,
    required String date,
  }) async {
    try {
      Log.i(
        'CinemaService',
        'DEBUG: Fetching shows for Theatre: $theatreId, Movie: $movieId, Date: $date',
      );

      // Parse the date string (YYYY-MM-DD)
      final parts = date.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      // Fetch shows for this theatre and movie
      var snapshot = await _firestore
          .collection('shows')
          .where('theatreId', isEqualTo: theatreId)
          .where('movieId', isEqualTo: movieId)
          .where('isActive', isEqualTo: true)
          .get();

      final shows = snapshot.docs
          .where((doc) {
            final data = doc.data();
            if (data['startTime'] == null) return false;

            final startTime = (data['startTime'] as Timestamp).toDate();
            // Check if the show is on the selected date
            return startTime.year == year &&
                startTime.month == month &&
                startTime.day == day;
          })
          .map((doc) {
            final data = doc.data();
            final startTime = (data['startTime'] as Timestamp).toDate();
            return {
              'id': doc.id,
              'time': DateFormat('hh:mm a').format(startTime),
              'format': data['format'] ?? '2D',
              'pricing':
                  data['pricing'] ??
                  {
                    'Silver': 150.0,
                    'Gold': 250.0,
                    'Platinum': 350.0,
                    'Recliner': 500.0,
                  },
              'availableSeats': data['availableSeats'] ?? 0,
              'totalSeats': data['totalSeats'] ?? 100,
              'seatLayout':
                  data['seatLayout'] ??
                  {
                    'rows': 8,
                    'seatsPerRow': 10,
                    'rowLabels': ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'],
                    'rowCategories': [
                      'Silver',
                      'Silver',
                      'Silver',
                      'Gold',
                      'Gold',
                      'Gold',
                      'Platinum',
                      'Platinum',
                    ],
                    'centerAisleAfter': 0,
                    'centerAisleWidth': 40,
                    'centerAisleRowLimit': 8,
                    'walkPathAfterRow': 0,
                    'walkPathWidth': 40,
                  },
            };
          })
          .toList();

      return shows;
    } catch (e) {
      Log.e('CinemaService', 'Error fetching show timings: $e', ex: e);
      return [];
    }
  }

  /// Get seat layout for a theatre
  static Future<Map<String, dynamic>> getSeatLayout(String theatreId) async {
    try {
      final doc = await _firestore.collection('theatres').doc(theatreId).get();

      if (!doc.exists) {
        return {
          'rows': 8,
          'seatsPerRow': 10,
          'rowLabels': ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'],
        };
      }

      final data = doc.data()!;
      return data['seatLayout'] ??
          {
            'rows': 8,
            'seatsPerRow': 10,
            'rowLabels': ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'],
            'centerAisleAfter': 0,
            'centerAisleWidth': 40,
            'centerAisleRowLimit': 8,
            'walkPathAfterRow': 0,
            'walkPathWidth': 40,
          };
    } catch (e) {
      Log.e('CinemaService', 'Error fetching seat layout: $e', ex: e);
      return {
        'rows': 8,
        'seatsPerRow': 10,
        'rowLabels': ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'],
        'centerAisleAfter': 0,
        'centerAisleWidth': 40,
        'centerAisleRowLimit': 8,
        'walkPathAfterRow': 0,
        'walkPathWidth': 40,
      };
    }
  }

  /// Get booked seats for a specific show
  static Future<List<String>> getBookedSeats({required String showId}) async {
    try {
      final snapshot = await _firestore
          .collection('movie_bookings')
          .where('showId', isEqualTo: showId)
          .where('status', isEqualTo: 'confirmed')
          .get();

      List<String> bookedSeats = [];
      for (var doc in snapshot.docs) {
        final seats = doc.data()['seats'] as List<dynamic>? ?? [];
        bookedSeats.addAll(seats.cast<String>());
      }

      return bookedSeats.toSet().toList(); // Remove duplicates
    } catch (e) {
      Log.e('CinemaService', 'Error fetching booked seats: $e', ex: e);
      return [];
    }
  }

  /// Watch booked seats in real-time
  static Stream<List<String>> watchBookedSeats({required String showId}) {
    // Also include locked seats in the realtime listener
    return _firestore.collection('shows').doc(showId).snapshots().map((doc) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      final seatStatus = data['seatStatus'] as Map<String, dynamic>? ?? {};

      List<String> bookedSeats = [];
      seatStatus.forEach((key, value) {
        if (value == 'booked') {
          bookedSeats.add(key);
        }
      });
      return bookedSeats;
    });
  }

  /// Watch all cinemas that are showing a specific movie (Real-time)
  static Stream<List<Map<String, dynamic>>> watchNearbyCinemas({
    required String movieId,
    Position? userPosition,
  }) {
    // 1. Listen to active shows for this movie
    return _firestore
        .collection('shows')
        .where('movieId', isEqualTo: movieId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((showsSnapshot) async {
          if (showsSnapshot.docs.isEmpty) return [];

          // 2. Extract unique theatre IDs
          Set<String> theatreIds = showsSnapshot.docs
              .map((doc) => doc.data()['theatreId'] as String)
              .where((id) => id.isNotEmpty)
              .toSet();

          if (theatreIds.isEmpty) return [];

          // 3. Fetch theatre details for these IDs
          List<DocumentSnapshot> theatreDocs = [];
          List<String> idsList = theatreIds.toList();

          for (var i = 0; i < idsList.length; i += 30) {
            var end = (i + 30 < idsList.length) ? i + 30 : idsList.length;
            var chunk = idsList.sublist(i, end);
            var snapshot = await _firestore
                .collection('theatres')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            theatreDocs.addAll(snapshot.docs);
          }

          List<Map<String, dynamic>> cinemas = [];

          for (var doc in theatreDocs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['isActive'] == false) continue;

            double cinemaLat = 0.0;
            double cinemaLng = 0.0;
            bool hasCoordinates = false;

            try {
              if (data['latitude'] != null) {
                cinemaLat = (data['latitude'] is String)
                    ? double.parse(data['latitude'])
                    : (data['latitude'] as num).toDouble();
              }
              if (data['longitude'] != null) {
                cinemaLng = (data['longitude'] is String)
                    ? double.parse(data['longitude'])
                    : (data['longitude'] as num).toDouble();
              }
              hasCoordinates = cinemaLat != 0.0 || cinemaLng != 0.0;
            } catch (e) {
              Log.w('CinemaService', 'Error parsing coordinates: $e');
            }

            double? distance;
            if (userPosition != null && hasCoordinates) {
              distance =
                  Geolocator.distanceBetween(
                    userPosition.latitude,
                    userPosition.longitude,
                    cinemaLat,
                    cinemaLng,
                  ) /
                  1000;
            }

            cinemas.add({
              'id': doc.id,
              'cinemaName':
                  data['name'] ?? data['cinemaName'] ?? 'Unnamed Cinema',
              'city': data['city'] ?? 'Unknown City',
              'latitude': cinemaLat,
              'longitude': cinemaLng,
              'formats': data['formats'] ?? ['2D'],
              'distance': distance,
            });
          }

          cinemas.sort((a, b) {
            final ad = (a['distance'] as double?) ?? double.maxFinite;
            final bd = (b['distance'] as double?) ?? double.maxFinite;
            return ad.compareTo(bd);
          });
          return cinemas;
        });
  }

  /// Calculate distance between two coordinates
  static double calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }
}
