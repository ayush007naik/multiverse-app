import 'package:db_compat/db_compat.dart';

class Movie {
  final String id;
  final String title;
  final String language;
  final String genre;
  final int duration;
  final DateTime releaseDate;
  final String certificate;
  final String description;
  final String posterUrl;
  final String bannerUrl;
  final String trailerUrl;
  final String status; // 'now_showing', 'coming_soon', 'ended'
  final bool isActive;

  Movie({
    required this.id,
    required this.title,
    required this.language,
    required this.genre,
    required this.duration,
    required this.releaseDate,
    required this.certificate,
    required this.description,
    required this.posterUrl,
    required this.bannerUrl,
    required this.trailerUrl,
    required this.status,
    this.isActive = true,
  });

  factory Movie.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Movie(
      id: doc.id,
      title: data['title'] ?? '',
      language: data['language'] ?? '',
      genre: data['genre'] ?? '',
      duration: data['duration'] ?? 0,
      releaseDate: (data['releaseDate'] as Timestamp).toDate(),
      certificate: data['certificate'] ?? '',
      description: data['description'] ?? '',
      posterUrl: data['posterUrl'] ?? '',
      bannerUrl: data['bannerUrl'] ?? '',
      trailerUrl: data['trailerUrl'] ?? '',
      status: data['status'] ?? 'coming_soon',
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'language': language,
      'genre': genre,
      'duration': duration,
      'releaseDate': Timestamp.fromDate(releaseDate),
      'certificate': certificate,
      'description': description,
      'posterUrl': posterUrl,
      'bannerUrl': bannerUrl,
      'trailerUrl': trailerUrl,
      'status': status,
      'isActive': isActive,
    };
  }
}
