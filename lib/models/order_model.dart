/// Standardized Order Model for the complete order system
class OrderModel {
  final String id;
  final String userId;
  final String shopId;
  final String? vendorId;
  final String? riderId;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double deliveryFee;
  final double gst;
  final double total;
  final String status;
  final Map<String, dynamic>? address;
  final String? customerName;
  final String? customerPhone;
  final double? customerLat;
  final double? customerLng;
  final String? paymentMethod;
  final String? paymentStatus;
  final double vendorEarning;
  final double platformEarning;
  final double deliveryEarning;
  final double gstOnCommission;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.userId,
    required this.shopId,
    this.vendorId,
    this.riderId,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.gst,
    required this.total,
    required this.status,
    this.address,
    this.customerName,
    this.customerPhone,
    this.customerLat,
    this.customerLng,
    this.paymentMethod,
    this.paymentStatus,
    this.vendorEarning = 0.0,
    this.platformEarning = 0.0,
    this.deliveryEarning = 0.0,
    this.gstOnCommission = 0.0,
    required this.createdAt,
  });

  /// Create OrderModel from Firestore document
  factory OrderModel.fromFirestore(Map<String, dynamic> data, String id) {
    return OrderModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      shopId: data['shopId'] as String? ?? '',
      vendorId: data['vendorId'] as String?,
      riderId: data['riderId'] as String?,
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      gst: (data['gst'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? 'pending',
      address: data['address'] as Map<String, dynamic>?,
      customerName: data['customerName'] as String?,
      customerPhone: data['customerPhone'] as String?,
      customerLat: (data['customerLat'] as num?)?.toDouble(),
      customerLng: (data['customerLng'] as num?)?.toDouble(),
      paymentMethod: data['paymentMethod'] as String?,
      paymentStatus: data['paymentStatus'] as String?,
      vendorEarning: (data['vendorEarning'] as num?)?.toDouble() ?? 0.0,
      platformEarning: (data['platformEarning'] as num?)?.toDouble() ?? 0.0,
      deliveryEarning: (data['deliveryEarning'] as num?)?.toDouble() ?? 0.0,
      gstOnCommission: (data['gstOnCommission'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert OrderModel to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'shopId': shopId,
      'vendorId': vendorId,
      'riderId': riderId,
      'items': items,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'gst': gst,
      'total': total,
      'status': status,
      'address': address,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'vendorEarning': vendorEarning,
      'platformEarning': platformEarning,
      'deliveryEarning': deliveryEarning,
      'gstOnCommission': gstOnCommission,
      'createdAt': createdAt,
    };
  }

  /// Create a copy with updated fields
  OrderModel copyWith({
    String? id,
    String? userId,
    String? shopId,
    String? vendorId,
    String? riderId,
    List<Map<String, dynamic>>? items,
    double? subtotal,
    double? deliveryFee,
    double? gst,
    double? total,
    String? status,
    Map<String, dynamic>? address,
    String? customerName,
    String? customerPhone,
    double? customerLat,
    double? customerLng,
    DateTime? createdAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      shopId: shopId ?? this.shopId,
      vendorId: vendorId ?? this.vendorId,
      riderId: riderId ?? this.riderId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      gst: gst ?? this.gst,
      total: total ?? this.total,
      status: status ?? this.status,
      address: address ?? this.address,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerLat: customerLat ?? this.customerLat,
      customerLng: customerLng ?? this.customerLng,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Status constants - COMPLETE FLOW
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusPacked = 'packed';
  static const String statusPreparing = 'preparing'; // Alias for packed
  static const String statusReady = 'ready';
  static const String statusOnTheWay = 'on_the_way';
  static const String statusPicked = 'picked'; // Alias for on_the_way
  static const String statusOutOfDelivery = 'out_for_delivery'; // Alias for on_the_way
  static const String statusDelivered = 'delivered';
  static const String statusCancelled = 'cancelled';
  static const String statusRejected = 'rejected';

  /// Check if order can be accepted by vendor
  bool canAccept() => status == statusPending;

  /// Check if vendor can mark as preparing/packed
  bool canStartPreparing() => status == statusAccepted;

  /// Check if vendor can mark as ready
  bool canMarkReady() => status == statusPreparing || status == statusPacked;

  /// Check if order can be picked by delivery
  bool canPick() => status == statusReady;

  /// Check if delivery can mark as out for delivery
  bool canMarkOutForDelivery() => status == statusAccepted;

  /// Check if order can be delivered
  bool canDeliver() => status == statusOnTheWay || status == statusPicked || status == statusOutOfDelivery;

  /// Get status color for UI
  static int getStatusColor(String status) {
    switch (status) {
      case statusPending:
        return 0xFFFF4D4F; // Brand Red
      case statusAccepted:
        return 0xFF4CAF50; // Green
      case statusPicked:
        return 0xFF2196F3; // Blue
      case statusDelivered:
        return 0xFF9C27B0; // Purple
      case statusCancelled:
        return 0xFFE53935; // Red
      default:
        return 0xFF888888; // Grey
    }
  }

  /// Get status display text
  static String getStatusText(String status) {
    switch (status) {
      case statusPending:
        return 'Pending';
      case statusAccepted:
        return 'Accepted';
      case statusPicked:
        return 'Picked Up';
      case statusDelivered:
        return 'Delivered';
      case statusCancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }
}