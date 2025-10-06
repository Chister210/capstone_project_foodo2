import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send a message
  Future<void> sendMessage({
    required String chatId,
    required String content,
    String messageType = 'text',
    String? imageUrl,
    GeoPoint? location,
    String? locationAddress,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) throw Exception('User data not found');

      final userData = userDoc.data()!;
      
      final message = MessageModel(
        id: '', // Will be set by Firestore
        chatId: chatId,
        senderId: user.uid,
        senderName: userData['displayName'] ?? user.displayName ?? 'User',
        senderType: userData['userType'] ?? 'unknown',
        content: content,
        messageType: messageType,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
        location: location,
        locationAddress: locationAddress,
      );

      // Add message to chat
      await _firestore.collection('chats').doc(chatId).collection('messages').add(message.toFirestore());

      // Update chat with last message info
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Get messages for a chat
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }

  // Get user's chats
  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('donorId', isEqualTo: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatModel.fromFirestore(doc))
            .toList());
  }

  // Get receiver's chats
  Stream<List<ChatModel>> getReceiverChats(String receiverId) {
    return _firestore
        .collection('chats')
        .where('receiverId', isEqualTo: receiverId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatModel.fromFirestore(doc))
            .toList());
  }

  // Create a new chat
  Future<String> createChat({
    required String donationId,
    required String donorId,
    required String receiverId,
    required String donorName,
    required String receiverName,
  }) async {
    try {
      final chatId = '${donorId}_${receiverId}_$donationId';
      
      final chat = ChatModel(
        id: chatId,
        donationId: donationId,
        donorId: donorId,
        receiverId: receiverId,
        donorName: donorName,
        receiverName: receiverName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastMessage: 'Chat started',
        lastMessageTime: DateTime.now(),
        lastMessageSenderId: receiverId,
        donorActive: false,
        receiverActive: true,
      );

      await _firestore.collection('chats').doc(chatId).set(chat.toFirestore());
      return chatId;
    } catch (e) {
      throw Exception('Failed to create chat: $e');
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      final messagesQuery = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesQuery.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Update user online status
  Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  // Send location message
  Future<void> sendLocationMessage({
    required String chatId,
    required GeoPoint location,
    required String locationAddress,
  }) async {
    await sendMessage(
      chatId: chatId,
      content: 'Shared location: $locationAddress',
      messageType: 'location',
      location: location,
      locationAddress: locationAddress,
    );
  }

  // Get unread message count for user
  Stream<int> getUnreadMessageCount(String userId) {
    return _firestore
        .collection('chats')
        .where('donorId', isEqualTo: userId)
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      int totalUnread = 0;
      
      for (final chatDoc in chatsSnapshot.docs) {
        final messagesQuery = await _firestore
            .collection('chats')
            .doc(chatDoc.id)
            .collection('messages')
            .where('senderId', isNotEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();
        
        totalUnread += messagesQuery.docs.length;
      }
      
      return totalUnread;
    });
  }
}
