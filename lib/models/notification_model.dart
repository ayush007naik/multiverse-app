import 'package:db_compat/db_compat.dart';

/// Notification model for push notifications and in-app notifications
class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? actionUrl;
  final String? imageUrl;
  final int priority;
  final String? campaignId;
  final String? templateId;
  final String? deepLink;
  final String? category;
  final String? offerCode;
  final String? ctaLabel;
  final String? ctaUrl;
  final DateTime? expiresAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? openedAt;
  final DateTime? clickedAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
    this.actionUrl,
    this.imageUrl,
    this.priority = 2,
    this.campaignId,
    this.templateId,
    this.deepLink,
    this.category,
    this.offerCode,
    this.ctaLabel,
    this.ctaUrl,
    this.expiresAt,
    this.sentAt,
    this.deliveredAt,
    this.openedAt,
    this.clickedAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    Timestamp? ts(String key) => d[key] as Timestamp?;
    return NotificationModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      type: d['type'] ?? '',
      title: d['title'] ?? '',
      message: d['message'] ?? '',
      data: d['data'],
      isRead: d['isRead'] ?? false,
      createdAt: ts('createdAt')?.toDate() ?? DateTime.now(),
      readAt: ts('readAt')?.toDate(),
      actionUrl: d['actionUrl'],
      imageUrl: d['imageUrl'],
      priority: d['priority'] ?? 2,
      campaignId: d['campaignId'],
      templateId: d['templateId'],
      deepLink: d['deepLink'],
      category: d['category'],
      offerCode: d['offerCode'],
      ctaLabel: d['ctaLabel'],
      ctaUrl: d['ctaUrl'],
      expiresAt: ts('expiresAt')?.toDate(),
      sentAt: ts('sentAt')?.toDate(),
      deliveredAt: ts('deliveredAt')?.toDate(),
      openedAt: ts('openedAt')?.toDate(),
      clickedAt: ts('clickedAt')?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'actionUrl': actionUrl,
      'imageUrl': imageUrl,
      'priority': priority,
      'campaignId': campaignId,
      'templateId': templateId,
      'deepLink': deepLink,
      'category': category,
      'offerCode': offerCode,
      'ctaLabel': ctaLabel,
      'ctaUrl': ctaUrl,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'openedAt': openedAt != null ? Timestamp.fromDate(openedAt!) : null,
      'clickedAt': clickedAt != null ? Timestamp.fromDate(clickedAt!) : null,
    };
  }

  NotificationModel copyWith({
    bool? isRead,
    DateTime? readAt,
    DateTime? openedAt,
    DateTime? clickedAt,
  }) {
    return NotificationModel(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      actionUrl: actionUrl,
      imageUrl: imageUrl,
      priority: priority,
      campaignId: campaignId,
      templateId: templateId,
      deepLink: deepLink,
      category: category,
      offerCode: offerCode,
      ctaLabel: ctaLabel,
      ctaUrl: ctaUrl,
      expiresAt: expiresAt,
      sentAt: sentAt,
      deliveredAt: deliveredAt,
      openedAt: openedAt ?? this.openedAt,
      clickedAt: clickedAt ?? this.clickedAt,
    );
  }

  /// Get notification icon based on type
  String get icon {
    switch (type) {
      case 'new_booking':
        return '📋';
      case 'new_offer':
        return '💰';
      case 'counter_offer':
        return '🔄';
      case 'payment_success':
        return '✅';
      case 'provider_arriving':
        return '🚗';
      case 'service_completed':
        return '🎉';
      case 'booking_cancelled':
        return '❌';
      default:
        return '🔔';
    }
  }

  /// Get notification color
  String get color {
    switch (type) {
      case 'new_booking':
        return '#2196F3'; // Blue
      case 'new_offer':
        return '#FF9800'; // Orange
      case 'counter_offer':
        return '#9C27B0'; // Purple
      case 'payment_success':
        return '#4CAF50'; // Green
      case 'provider_arriving':
        return '#00BCD4'; // Cyan
      case 'service_completed':
        return '#8BC34A'; // Light Green
      case 'booking_cancelled':
        return '#F44336'; // Red
      default:
        return '#757575'; // Grey
    }
  }
}
