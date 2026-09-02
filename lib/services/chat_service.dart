import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import '../core/logging_service.dart';

/// Chat Service
/// Handles real-time messaging between customer and provider
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _chatRooms => _firestore.collection('chat_rooms');
  CollectionReference get _messages => _firestore.collection('messages');
  // ========== CHAT ROOM MANAGEMENT ==========

  /// Get or create chat room for a booking
  Future<String> getOrCreateChatRoom({
    required String bookingId,
    required String customerId,
    required String providerId,
  }) async {
    try {
      // Check if chat room already exists
      final existingRoom = await _chatRooms
          .where('bookingId', isEqualTo: bookingId)
          .limit(1)
          .get();

      if (existingRoom.docs.isNotEmpty) {
        return existingRoom.docs.first.id;
      }

      // Create new chat room
      final chatRoom = ChatRoom(
        id: '',
        bookingId: bookingId,
        customerId: customerId,
        providerId: providerId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _chatRooms.add(chatRoom.toMap());
      Log.i('ChatService', '✅ Chat room created: ${docRef.id}');

      return docRef.id;
    } catch (e) {
      Log.e('ChatService', '❌ Error creating chat room: $e', ex: e);
      rethrow;
    }
  }

  /// Get chat room for booking
  Future<ChatRoom?> getChatRoom(String bookingId) async {
    try {
      final snapshot = await _chatRooms
          .where('bookingId', isEqualTo: bookingId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return ChatRoom.fromFirestore(snapshot.docs.first);
    } catch (e) {
      Log.e('ChatService', '❌ Error getting chat room: $e', ex: e);
      return null;
    }
  }

  /// Listen to chat room
  Stream<ChatRoom?> listenToChatRoom(String bookingId) {
    return _chatRooms
        .where('bookingId', isEqualTo: bookingId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return ChatRoom.fromFirestore(snapshot.docs.first);
        });
  }

  // ========== SENDING MESSAGES ==========

  /// Send a text message
  Future<String> sendTextMessage({
    required String bookingId,
    required String receiverId,
    required String text,
  }) async {
    try {
      final senderId = _auth.currentUser?.uid;
      if (senderId == null) throw Exception('User not authenticated');

      final message = ChatMessage(
        id: '',
        bookingId: bookingId,
        senderId: senderId,
        receiverId: receiverId,
        messageType: 'text',
        text: text,
        createdAt: DateTime.now(),
      );

      final docRef = await _messages.add(message.toMap());

      // Update chat room
      await _updateChatRoom(bookingId, text);

      // Mark as read if receiver is viewing chat
      // (Will be handled by UI)

      Log.i('ChatService', '✅ Message sent: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      Log.e('ChatService', '❌ Error sending message: $e', ex: e);
      rethrow;
    }
  }

  /// Send an image message
  Future<String> sendImageMessage({
    required String bookingId,
    required String receiverId,
    required String imageUrl,
    String? caption,
  }) async {
    try {
      final senderId = _auth.currentUser?.uid;
      if (senderId == null) throw Exception('User not authenticated');

      final message = ChatMessage(
        id: '',
        bookingId: bookingId,
        senderId: senderId,
        receiverId: receiverId,
        messageType: 'image',
        text: caption,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      final docRef = await _messages.add(message.toMap());
      await _updateChatRoom(bookingId, caption ?? '📷 Photo');

      Log.i('ChatService', '✅ Image message sent: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      Log.e('ChatService', '❌ Error sending image: $e', ex: e);
      rethrow;
    }
  }

  /// Send system message (booking status updates, etc.)
  Future<String> sendSystemMessage({
    required String bookingId,
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final message = ChatMessage(
        id: '',
        bookingId: bookingId,
        senderId: 'system',
        receiverId: 'both',
        messageType: 'system',
        text: text,
        metadata: metadata,
        createdAt: DateTime.now(),
      );

      final docRef = await _messages.add(message.toMap());
      Log.i('ChatService', '✅ System message sent: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      Log.e('ChatService', '❌ Error sending system message: $e', ex: e);
      rethrow;
    }
  }

  /// Send offer message
  Future<String> sendOfferMessage({
    required String bookingId,
    required String providerId,
    required String customerId,
    required double offerPrice,
    String? message,
    String? eta,
    List<String>? includedServices,
  }) async {
    try {
      final chatMessage = ChatMessage(
        id: '',
        bookingId: bookingId,
        senderId: providerId,
        receiverId: customerId,
        messageType: 'offer',
        text: message,
        metadata: {
          'offerPrice': offerPrice,
          'eta': eta,
          'includedServices': includedServices,
        },
        createdAt: DateTime.now(),
      );

      final docRef = await _messages.add(chatMessage.toMap());
      await _updateChatRoom(
        bookingId,
        '💰 New offer: ₹${offerPrice.toStringAsFixed(0)}',
      );

      Log.i('ChatService', '✅ Offer message sent: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      Log.e('ChatService', '❌ Error sending offer message: $e', ex: e);
      rethrow;
    }
  }

  // ========== REAL-TIME MESSAGE LISTENERS ==========

  /// Listen to messages for a booking in real-time
  Stream<List<ChatMessage>> listenToMessages(String bookingId) {
    return _messages
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList();
        });
  }

  /// Listen to unread message count for a booking
  Stream<int> listenToUnreadCount(String bookingId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _messages
        .where('bookingId', isEqualTo: bookingId)
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Listen to all user's chat rooms
  Stream<List<ChatRoom>> listenToUserChatRooms() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _chatRooms
        .where('customerId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatRoom.fromFirestore(doc))
              .toList();
        });
  }

  // ========== MESSAGE MANAGEMENT ==========

  /// Mark messages as read
  Future<void> markMessagesAsRead(String bookingId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final snapshot = await _messages
          .where('bookingId', isEqualTo: bookingId)
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      Log.e('ChatService', '❌ Error marking messages as read: $e', ex: e);
    }
  }

  /// Mark all messages in chat as read
  Future<void> markAllMessagesRead(String bookingId) async {
    await markMessagesAsRead(bookingId);
  }

  /// Delete message (only for sender)
  Future<void> deleteMessage(String messageId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final doc = await _messages.doc(messageId).get();
      if (!doc.exists) return;

      final message = ChatMessage.fromFirestore(doc);
      if (message.senderId != userId) {
        throw Exception('You can only delete your own messages');
      }

      await _messages.doc(messageId).delete();
    } catch (e) {
      Log.e('ChatService', '❌ Error deleting message: $e', ex: e);
      rethrow;
    }
  }

  // ========== TYPING INDICATOR ==========

  /// Update typing status
  Future<void> updateTypingStatus({
    required String bookingId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      await _chatRooms
          .where('bookingId', isEqualTo: bookingId)
          .limit(1)
          .get()
          .then((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              final chatRoomId = snapshot.docs.first.id;
              _firestore.collection('chat_rooms').doc(chatRoomId).update({
                'typingUsers.$userId': isTyping,
                'typingUpdatedAt': FieldValue.serverTimestamp(),
              });
            }
          });
    } catch (e) {
      Log.e('ChatService', '❌ Error updating typing status: $e', ex: e);
    }
  }

  /// Listen to typing status
  Stream<Map<String, bool>> listenToTypingStatus(String bookingId) {
    return _chatRooms
        .where('bookingId', isEqualTo: bookingId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return {};
          final data = snapshot.docs.first.data();
          final typingUsers = data['typingUsers'] as Map<String, dynamic>?;
          return typingUsers?.map(
                (key, value) => MapEntry(key, value as bool),
              ) ??
              {};
        });
  }

  // ========== HELPER METHODS ==========

  /// Update chat room with last message
  Future<void> _updateChatRoom(String bookingId, String lastMessage) async {
    try {
      final snapshot = await _chatRooms
          .where('bookingId', isEqualTo: bookingId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return;

      final chatRoomId = snapshot.docs.first.id;
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': lastMessage,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      });
    } catch (e) {
      Log.e('ChatService', '❌ Error updating chat room: $e', ex: e);
    }
  }

  /// Reset unread count when user opens chat
  Future<void> resetUnreadCount(String bookingId) async {
    try {
      final snapshot = await _chatRooms
          .where('bookingId', isEqualTo: bookingId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return;

      final chatRoomId = snapshot.docs.first.id;
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'unreadCount': 0,
      });
    } catch (e) {
      Log.e('ChatService', '❌ Error resetting unread count: $e', ex: e);
    }
  }

  /// Get message count for analytics
  Future<int> getMessageCount(String bookingId) async {
    try {
      final snapshot = await _messages
          .where('bookingId', isEqualTo: bookingId)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      Log.e('ChatService', '❌ Error getting message count: $e', ex: e);
      return 0;
    }
  }
}
