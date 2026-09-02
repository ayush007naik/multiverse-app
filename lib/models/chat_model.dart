import 'package:db_compat/db_compat.dart';

/// Chat message model for real-time messaging between customer and provider
class ChatMessage {
  final String id;
  final String bookingId;
  final String senderId;
  final String receiverId;
  final String messageType; // 'text', 'image', 'system', 'offer', 'counter_offer'
  final String? text;
  final String? imageUrl;
  final Map<String, dynamic>? metadata; // For offer/counter-offer data
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final List<String>? attachments; // File URLs

  ChatMessage({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.receiverId,
    this.messageType = 'text',
    this.text,
    this.imageUrl,
    this.metadata,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
    this.attachments,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      bookingId: data['bookingId'] ?? '',
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      messageType: data['messageType'] ?? 'text',
      text: data['text'],
      imageUrl: data['imageUrl'],
      metadata: data['metadata'],
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      readAt: data['readAt'] != null 
          ? (data['readAt'] as Timestamp).toDate() 
          : null,
      attachments: data['attachments'] != null 
          ? List<String>.from(data['attachments']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'senderId': senderId,
      'receiverId': receiverId,
      'messageType': messageType,
      'text': text,
      'imageUrl': imageUrl,
      'metadata': metadata,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'attachments': attachments,
    };
  }

  ChatMessage copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return ChatMessage(
      id: id,
      bookingId: bookingId,
      senderId: senderId,
      receiverId: receiverId,
      messageType: messageType,
      text: text,
      imageUrl: imageUrl,
      metadata: metadata,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      attachments: attachments,
    );
  }

  /// Check if message is sent by current user
  bool get isFromMe {
    // Will be set dynamically based on current user
    return true;
  }

  /// Get display time
  String get displayTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${createdAt.day}/${createdAt.month}';
    }
  }

  /// Check if message is recent (within 5 minutes)
  bool get isRecent {
    return DateTime.now().difference(createdAt).inMinutes < 5;
  }
}

/// Chat room model for managing conversations
class ChatRoom {
  final String id;
  final String bookingId;
  final String customerId;
  final String providerId;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatRoom({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      bookingId: data['bookingId'] ?? '',
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      lastMessage: data['lastMessage'],
      lastMessageTime: data['lastMessageTime'] != null 
          ? (data['lastMessageTime'] as Timestamp).toDate() 
          : null,
      unreadCount: data['unreadCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'customerId': customerId,
      'providerId': providerId,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null 
          ? Timestamp.fromDate(lastMessageTime!) 
          : null,
      'unreadCount': unreadCount,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
