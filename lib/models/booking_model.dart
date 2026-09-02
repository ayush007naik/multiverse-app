import 'package:db_compat/db_compat.dart';

/// Booking model for service requests
/// Tracks the entire lifecycle from request to completion
class BookingModel {
  final String id;
  final String customerId;
  final String? providerId;
  final String serviceCategory;
  final String serviceType;
  final String description;
  final List<String>? images;
  final double? budget;
  final DateTime? preferredDate;
  final String? preferredTime;
  final Map<String, dynamic> address;
  final Map<String, dynamic>? customerLocation;
  
  // Status tracking
  final String status; // 'searching_providers', 'offers_incoming', 'offer_accepted', 
                       // 'payment_pending', 'provider_assigned', 'on_the_way', 
                       // 'arrived', 'service_started', 'service_completed', 'cancelled'
  final double? acceptedPrice;
  final int? acceptedOfferId;
  
  // Payment
  final String? paymentId;
  final String paymentStatus; // 'pending', 'processing', 'paid', 'failed', 'refunded'
  final double? totalAmount;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  
  // Metadata
  final int offersCount;
  final bool isCounterOfferActive;
  final String? cancellationReason;

  BookingModel({
    required this.id,
    required this.customerId,
    this.providerId,
    required this.serviceCategory,
    required this.serviceType,
    required this.description,
    this.images,
    this.budget,
    this.preferredDate,
    this.preferredTime,
    required this.address,
    this.customerLocation,
    this.status = 'searching_providers',
    this.acceptedPrice,
    this.acceptedOfferId,
    this.paymentId,
    this.paymentStatus = 'pending',
    this.totalAmount,
    required this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.completedAt,
    this.offersCount = 0,
    this.isCounterOfferActive = false,
    this.cancellationReason,
  });

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'],
      serviceCategory: data['serviceCategory'] ?? '',
      serviceType: data['serviceType'] ?? '',
      description: data['description'] ?? '',
      images: data['images'] != null 
          ? List<String>.from(data['images']) 
          : null,
      budget: data['budget']?.toDouble(),
      preferredDate: data['preferredDate'] != null 
          ? (data['preferredDate'] as Timestamp).toDate() 
          : null,
      preferredTime: data['preferredTime'],
      address: Map<String, dynamic>.from(data['address'] ?? {}),
      customerLocation: data['customerLocation'],
       status: data['status'] ?? 'searching_providers',
       acceptedPrice: data['acceptedPrice']?.toDouble(),
       acceptedOfferId: data['acceptedOfferId'] != null
           ? int.tryParse(data['acceptedOfferId'].toString()) ?? (data['acceptedOfferId'] as int)
           : null,
       paymentId: data['paymentId'],
      paymentStatus: data['paymentStatus'] ?? 'pending',
      totalAmount: data['totalAmount']?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      acceptedAt: data['acceptedAt'] != null 
          ? (data['acceptedAt'] as Timestamp).toDate() 
          : null,
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
       offersCount: data['offersCount'] != null
           ? int.tryParse(data['offersCount'].toString()) ?? (data['offersCount'] as int)
           : 0,
      isCounterOfferActive: data['isCounterOfferActive'] ?? false,
      cancellationReason: data['cancellationReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'providerId': providerId,
      'serviceCategory': serviceCategory,
      'serviceType': serviceType,
      'description': description,
      'images': images,
      'budget': budget,
      'preferredDate': preferredDate != null 
          ? Timestamp.fromDate(preferredDate!) 
          : null,
      'preferredTime': preferredTime,
      'address': address,
      'customerLocation': customerLocation,
      'status': status,
      'acceptedPrice': acceptedPrice,
      'acceptedOfferId': acceptedOfferId,
      'paymentId': paymentId,
      'paymentStatus': paymentStatus,
      'totalAmount': totalAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null 
          ? Timestamp.fromDate(updatedAt!) 
          : FieldValue.serverTimestamp(),
      'acceptedAt': acceptedAt != null 
          ? Timestamp.fromDate(acceptedAt!) 
          : null,
      'completedAt': completedAt != null 
          ? Timestamp.fromDate(completedAt!) 
          : null,
      'offersCount': offersCount,
      'isCounterOfferActive': isCounterOfferActive,
      'cancellationReason': cancellationReason,
    };
  }

  BookingModel copyWith({
    String? providerId,
    String? status,
    double? acceptedPrice,
    int? acceptedOfferId,
    String? paymentId,
    String? paymentStatus,
    double? totalAmount,
    int? offersCount,
    bool? isCounterOfferActive,
    String? cancellationReason,
  }) {
    return BookingModel(
      id: id,
      customerId: customerId,
      providerId: providerId ?? this.providerId,
      serviceCategory: serviceCategory,
      serviceType: serviceType,
      description: description,
      images: images,
      budget: budget,
      preferredDate: preferredDate,
      preferredTime: preferredTime,
      address: address,
      customerLocation: customerLocation,
      status: status ?? this.status,
      acceptedPrice: acceptedPrice ?? this.acceptedPrice,
      acceptedOfferId: acceptedOfferId ?? this.acceptedOfferId,
      paymentId: paymentId ?? this.paymentId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      acceptedAt: acceptedAt,
      completedAt: completedAt,
      offersCount: offersCount ?? this.offersCount,
      isCounterOfferActive: isCounterOfferActive ?? this.isCounterOfferActive,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case 'searching_providers':
        return 'Searching Providers...';
      case 'offers_incoming':
        return 'Receiving Offers';
      case 'offer_accepted':
        return 'Offer Accepted';
      case 'payment_pending':
        return 'Payment Pending';
      case 'provider_assigned':
        return 'Provider Assigned';
      case 'on_the_way':
        return 'Provider On The Way';
      case 'arrived':
        return 'Provider Arrived';
      case 'service_started':
        return 'Service In Progress';
      case 'service_completed':
        return 'Service Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Check if booking is active
  bool get isActive {
    return ![
      'service_completed',
      'cancelled',
    ].contains(status);
  }

  /// Check if payment is required
  bool get requiresPayment {
    return paymentStatus == 'pending' && 
           (status == 'offer_accepted' || status == 'payment_pending');
  }
}
