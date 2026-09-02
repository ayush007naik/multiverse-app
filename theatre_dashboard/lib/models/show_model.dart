import 'package:db_compat/db_compat.dart';

class Show {
  final String id;
  final String movieId;
  final String movieTitle;
  final String theatreId;
  final String screen;
  final DateTime startTime;
  final DateTime endTime;
  final Map<String, double> pricing; // {'Silver': 200, 'Gold': 300, ...}
  final int totalSeats;
  final int availableSeats;
  final bool isActive;

  Show({
    required this.id,
    required this.movieId,
    required this.movieTitle,
    required this.theatreId,
    required this.screen,
    required this.startTime,
    required this.endTime,
    required this.pricing,
    required this.totalSeats,
    required this.availableSeats,
    this.isActive = true,
  });

  factory Show.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Show(
      id: doc.id,
      movieId: data['movieId'] ?? '',
      movieTitle: data['movieTitle'] ?? '',
      theatreId: data['theatreId'] ?? '',
      screen: data['screen'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      pricing: Map<String, double>.from(data['pricing'] ?? {}),
      totalSeats: data['totalSeats'] ?? 0,
      availableSeats: data['availableSeats'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'movieId': movieId,
      'movieTitle': movieTitle,
      'theatreId': theatreId,
      'screen': screen,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'pricing': pricing,
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'isActive': isActive,
    };
  }
}
