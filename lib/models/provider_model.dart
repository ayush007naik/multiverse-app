import 'package:db_compat/db_compat.dart';

/// Provider model for service professionals
/// Extended user profile with service details, availability, and ratings
class ProviderModel {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String? profileImage;
  final List<String> serviceCategories;
  final List<String> services;
  final String bio;
  final int yearsOfExperience;
  final double rating;
  final int totalReviews;
  final int completedJobs;
  final bool isAvailable;
  final bool isVerified;
  final bool isOnline;
  final Map<String, dynamic>? location; // {latitude, longitude, address}
  final Map<String, dynamic>? workingHours; // {monday: {start, end}, ...}
  final List<Map<String, dynamic>> documents; // KYC documents
  final double basePrice;
  final String? bannerImage;
  final DateTime createdAt;
  final DateTime? lastActive;

  ProviderModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.profileImage,
    this.serviceCategories = const [],
    this.services = const [],
    this.bio = '',
    this.yearsOfExperience = 0,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.completedJobs = 0,
    this.isAvailable = true,
    this.isVerified = false,
    this.isOnline = false,
    this.location,
    this.workingHours,
    this.documents = const [],
    this.basePrice = 0.0,
    this.bannerImage,
    required this.createdAt,
    this.lastActive,
  });

  factory ProviderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProviderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      profileImage: data['profileImage'],
      serviceCategories: List<String>.from(data['serviceCategories'] ?? []),
      services: List<String>.from(data['services'] ?? []),
      bio: data['bio'] ?? '',
      yearsOfExperience: data['yearsOfExperience'] ?? 0,
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
      completedJobs: data['completedJobs'] ?? 0,
      isAvailable: data['isAvailable'] ?? true,
      isVerified: data['isVerified'] ?? false,
      isOnline: data['isOnline'] ?? false,
      location: data['location'],
      workingHours: data['workingHours'],
      documents: List<Map<String, dynamic>>.from(data['documents'] ?? []),
      basePrice: (data['basePrice'] ?? 0.0).toDouble(),
      bannerImage: data['bannerImage'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActive: data['lastActive'] != null 
          ? (data['lastActive'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'profileImage': profileImage,
      'serviceCategories': serviceCategories,
      'services': services,
      'bio': bio,
      'yearsOfExperience': yearsOfExperience,
      'rating': rating,
      'totalReviews': totalReviews,
      'completedJobs': completedJobs,
      'isAvailable': isAvailable,
      'isVerified': isVerified,
      'isOnline': isOnline,
      'location': location,
      'workingHours': workingHours,
      'documents': documents,
      'basePrice': basePrice,
      'bannerImage': bannerImage,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': lastActive != null 
          ? Timestamp.fromDate(lastActive!) 
          : FieldValue.serverTimestamp(),
    };
  }

  ProviderModel copyWith({
    String? name,
    String? phone,
    String? profileImage,
    List<String>? serviceCategories,
    List<String>? services,
    String? bio,
    int? yearsOfExperience,
    double? rating,
    int? totalReviews,
    int? completedJobs,
    bool? isAvailable,
    bool? isVerified,
    bool? isOnline,
    Map<String, dynamic>? location,
    Map<String, dynamic>? workingHours,
    List<Map<String, dynamic>>? documents,
    double? basePrice,
    String? bannerImage,
  }) {
    return ProviderModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      serviceCategories: serviceCategories ?? this.serviceCategories,
      services: services ?? this.services,
      bio: bio ?? this.bio,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      completedJobs: completedJobs ?? this.completedJobs,
      isAvailable: isAvailable ?? this.isAvailable,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      location: location ?? this.location,
      workingHours: workingHours ?? this.workingHours,
      documents: documents ?? this.documents,
      basePrice: basePrice ?? this.basePrice,
      bannerImage: bannerImage ?? this.bannerImage,
      createdAt: createdAt,
      lastActive: lastActive,
    );
  }

  /// Get provider status text
  String get statusText {
    if (!isAvailable) return 'Unavailable';
    if (isOnline) return 'Online';
    return 'Offline';
  }

  /// Check if provider offers a specific service
  bool offersService(String service) {
    return services.contains(service) || 
           serviceCategories.any((cat) => services.any((s) => s.contains(cat)));
  }
}
