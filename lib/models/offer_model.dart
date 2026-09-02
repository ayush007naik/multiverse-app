import 'package:db_compat/db_compat.dart';

/// Offer model for provider bids on bookings
/// Supports counter-offer negotiation system
class OfferModel {
  final String id;
  final String bookingId;
  final String providerId;
  final String providerName;
  final String? providerImage;
  final double providerRating;
  final int completedJobs;
  
  // Offer details
  final double offeredPrice;
  final String? eta; // Estimated time of arrival
  final String? message;
  final List<String>? includedServices;
  
  // Counter-offer system
  final bool isCounterOffer;
  final int counterOfferNumber;
  final String? parentOfferId; // Reference to previous offer in negotiation
  final double? counterOfferPrice;
  final String? counterOfferMessage;
  
  // Status
  final String status; // 'pending', 'accepted', 'rejected', 'countered'
  final DateTime createdAt;
  final DateTime? expiresAt;
  
  // Provider metadata at time of offer
  final Map<String, dynamic>? providerLocation;
  final bool isProviderOnline;

  OfferModel({
    required this.id,
    required this.bookingId,
    required this.providerId,
    required this.providerName,
    this.providerImage,
    this.providerRating = 0.0,
    this.completedJobs = 0,
    required this.offeredPrice,
    this.eta,
    this.message,
    this.includedServices,
    this.isCounterOffer = false,
    this.counterOfferNumber = 0,
    this.parentOfferId,
    this.counterOfferPrice,
    this.counterOfferMessage,
    this.status = 'pending',
    required this.createdAt,
    this.expiresAt,
    this.providerLocation,
    this.isProviderOnline = true,
  });

  factory OfferModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OfferModel(
      id: doc.id,
      bookingId: data['bookingId'] ?? '',
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
       providerImage: data['providerImage'],
       providerRating: (data['providerRating'] ?? 0.0).toDouble(),
       completedJobs: data['completedJobs'] != null
           ? int.tryParse(data['completedJobs'].toString()) ?? (data['completedJobs'] as int)
           : 0,
       offeredPrice: (data['offeredPrice'] ?? 0.0).toDouble(),
      eta: data['eta'],
      message: data['message'],
      includedServices: data['includedServices'] != null 
          ? List<String>.from(data['includedServices']) 
          : null,
      isCounterOffer: data['isCounterOffer'] ?? false,
      counterOfferNumber: data['counterOfferNumber'] ?? 0,
      parentOfferId: data['parentOfferId'],
      counterOfferPrice: data['counterOfferPrice']?.toDouble(),
      counterOfferMessage: data['counterOfferMessage'],
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null 
          ? (data['expiresAt'] as Timestamp).toDate() 
          : null,
      providerLocation: data['providerLocation'],
      isProviderOnline: data['isProviderOnline'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'providerId': providerId,
      'providerName': providerName,
      'providerImage': providerImage,
      'providerRating': providerRating,
      'completedJobs': completedJobs,
      'offeredPrice': offeredPrice,
      'eta': eta,
      'message': message,
      'includedServices': includedServices,
      'isCounterOffer': isCounterOffer,
      'counterOfferNumber': counterOfferNumber,
      'parentOfferId': parentOfferId,
      'counterOfferPrice': counterOfferPrice,
      'counterOfferMessage': counterOfferMessage,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null 
          ? Timestamp.fromDate(expiresAt!) 
          : null,
      'providerLocation': providerLocation,
      'isProviderOnline': isProviderOnline,
    };
  }

  OfferModel copyWith({
    double? offeredPrice,
    String? eta,
    String? message,
    String? status,
    bool? isCounterOffer,
    int? counterOfferNumber,
    double? counterOfferPrice,
    String? counterOfferMessage,
  }) {
    return OfferModel(
      id: id,
      bookingId: bookingId,
      providerId: providerId,
      providerName: providerName,
      providerImage: providerImage,
      providerRating: providerRating,
      completedJobs: completedJobs,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      eta: eta ?? this.eta,
      message: message ?? this.message,
      includedServices: includedServices,
      isCounterOffer: isCounterOffer ?? this.isCounterOffer,
      counterOfferNumber: counterOfferNumber ?? this.counterOfferNumber,
      parentOfferId: parentOfferId,
      counterOfferPrice: counterOfferPrice ?? this.counterOfferPrice,
      counterOfferMessage: counterOfferMessage ?? this.counterOfferMessage,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: expiresAt,
      providerLocation: providerLocation,
      isProviderOnline: isProviderOnline,
    );
  }

  /// Calculate discount from customer's budget
  double? calculateDiscount(double? budget) {
    if (budget == null) return null;
    return ((budget - offeredPrice) / budget * 100);
  }

  /// Check if offer is still valid
  bool get isValid {
    if (status != 'pending') return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  /// Get display price
  String get displayPrice {
    return '₹${offeredPrice.toStringAsFixed(0)}';
  }
}
