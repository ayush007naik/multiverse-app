import 'package:db_compat/db_compat.dart';

class Theatre {
  final String id;
  final String ownerId;
  final String cinemaName;
  final String city;
  final String address;
  final String phone;
  final String email;
  final String logoUrl;
  final String bannerUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final bool isActive;
  final Map<String, dynamic> socialLinks;
  final List<String> screens;

  Theatre({
    required this.id,
    required this.ownerId,
    required this.cinemaName,
    required this.city,
    required this.address,
    required this.phone,
    required this.email,
    this.logoUrl = '',
    this.bannerUrl = '',
    required this.status,
    this.isActive = true,
    this.socialLinks = const {},
    this.screens = const [],
  });

  factory Theatre.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Theatre(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      cinemaName: data['cinemaName'] ?? '',
      city: data['city'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      logoUrl: data['logoUrl'] ?? '',
      bannerUrl: data['bannerUrl'] ?? '',
      status: data['status'] ?? 'pending',
      isActive: data['isActive'] ?? true,
      socialLinks: data['socialLinks'] ?? {},
      screens: List<String>.from(data['screens'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'cinemaName': cinemaName,
      'city': city,
      'address': address,
      'phone': phone,
      'email': email,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'status': status,
      'isActive': isActive,
      'socialLinks': socialLinks,
      'screens': screens,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
