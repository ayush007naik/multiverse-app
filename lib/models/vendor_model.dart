import 'package:db_compat/db_compat.dart';

/// Vendor Model - Represents a vendor in the system
class VendorModel {
  final String id;
  final String shopName;
  final String ownerName;
  final String email;
  final String phone;
  final String category;
  final String location;
  final double deliveryRadius;
  final String? shopImage;
  final String status; // pending, approved, rejected
  final bool isApproved;
  final bool isOnline;
  final bool isShopOpen;
  final double rating;
  final int totalOrders;
  final double totalEarnings;
  final Map<String, dynamic>? shopTimings;
  final String? shopBanner;
  final String? description;
  final List<String>? categories;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;
  final DateTime? lastLogout;

  VendorModel({
    required this.id,
    required this.shopName,
    required this.ownerName,
    required this.email,
    required this.phone,
    required this.category,
    required this.location,
    required this.deliveryRadius,
    this.shopImage,
    this.status = 'pending',
    this.isApproved = false,
    this.isOnline = false,
    this.isShopOpen = false,
    this.rating = 0.0,
    this.totalOrders = 0,
    this.totalEarnings = 0.0,
    this.shopTimings,
    this.shopBanner,
    this.description,
    this.categories,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
    this.lastLogout,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopName': shopName,
      'ownerName': ownerName,
      'email': email,
      'phone': phone,
      'category': category,
      'location': location,
      'deliveryRadius': deliveryRadius,
      'shopImage': shopImage,
      'status': status,
      'isApproved': isApproved,
      'isOnline': isOnline,
      'isShopOpen': isShopOpen,
      'rating': rating,
      'totalOrders': totalOrders,
      'totalEarnings': totalEarnings,
      'shopTimings': shopTimings,
      'shopBanner': shopBanner,
      'description': description,
      'categories': categories ?? [],
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'lastLogout': lastLogout != null ? Timestamp.fromDate(lastLogout!) : null,
    };
  }

  factory VendorModel.fromMap(Map<String, dynamic> map, String documentId) {
    return VendorModel(
      id: documentId,
      shopName: map['shopName'] ?? '',
      ownerName: map['ownerName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      category: map['category'] ?? '',
      location: map['location'] is Map 
          ? (map['location']['label'] ?? map['location']['address'] ?? '') 
          : (map['location'] ?? ''),
      deliveryRadius: (map['deliveryRadius'] ?? 0).toDouble(),
      shopImage: map['shopImage'],
      status: map['status'] ?? 'pending',
      isApproved: map['isApproved'] ?? false,
      isOnline: map['isOnline'] ?? false,
      isShopOpen: map['isShopOpen'] ?? false,
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalOrders: map['totalOrders'] ?? 0,
      totalEarnings: (map['totalEarnings'] ?? 0.0).toDouble(),
      shopTimings: map['shopTimings'],
      shopBanner: map['shopBanner'],
      description: map['description'],
      categories: map['categories'] != null 
          ? List<String>.from(map['categories']) 
          : null,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (map['lastLogin'] as Timestamp?)?.toDate(),
      lastLogout: (map['lastLogout'] as Timestamp?)?.toDate(),
    );
  }

  VendorModel copyWith({
    String? shopName,
    String? ownerName,
    String? email,
    String? phone,
    String? category,
    String? location,
    double? deliveryRadius,
    String? shopImage,
    String? status,
    bool? isApproved,
    bool? isOnline,
    bool? isShopOpen,
    double? rating,
    int? totalOrders,
    double? totalEarnings,
    Map<String, dynamic>? shopTimings,
    String? shopBanner,
    String? description,
    List<String>? categories,
    DateTime? updatedAt,
  }) {
    return VendorModel(
      id: id,
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      category: category ?? this.category,
      location: location ?? this.location,
      deliveryRadius: deliveryRadius ?? this.deliveryRadius,
      shopImage: shopImage ?? this.shopImage,
      status: status ?? this.status,
      isApproved: isApproved ?? this.isApproved,
      isOnline: isOnline ?? this.isOnline,
      isShopOpen: isShopOpen ?? this.isShopOpen,
      rating: rating ?? this.rating,
      totalOrders: totalOrders ?? this.totalOrders,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      shopTimings: shopTimings ?? this.shopTimings,
      shopBanner: shopBanner ?? this.shopBanner,
      description: description ?? this.description,
      categories: categories ?? this.categories,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin,
      lastLogout: lastLogout,
    );
  }
}
