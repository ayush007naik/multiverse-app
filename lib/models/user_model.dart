import 'package:db_compat/db_compat.dart';

/// User model for the marketplace platform
/// Stores user profile, role, and preferences
class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'customer', 'provider', 'admin'
  final String? profileImage;
  final DateTime createdAt;
  final DateTime? lastActive;
  final bool isOnline;
  final Map<String, dynamic>? location; // {latitude, longitude}
  final List<String> fcmTokens;
  final Map<String, dynamic>? metadata;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImage,
    required this.createdAt,
    this.lastActive,
    this.isOnline = false,
    this.location,
    this.fcmTokens = const [],
    this.metadata,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'customer',
      profileImage: data['profileImage'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActive: data['lastActive'] != null 
          ? (data['lastActive'] as Timestamp).toDate() 
          : null,
      isOnline: data['isOnline'] ?? false,
      location: data['location'],
      fcmTokens: List<String>.from(data['fcmTokens'] ?? []),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'profileImage': profileImage,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': lastActive != null 
          ? Timestamp.fromDate(lastActive!) 
          : FieldValue.serverTimestamp(),
      'isOnline': isOnline,
      'location': location,
      'fcmTokens': fcmTokens,
      'metadata': metadata,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? profileImage,
    DateTime? lastActive,
    bool? isOnline,
    Map<String, dynamic>? location,
    List<String>? fcmTokens,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
      isOnline: isOnline ?? this.isOnline,
      location: location ?? this.location,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      metadata: metadata,
    );
  }
}
