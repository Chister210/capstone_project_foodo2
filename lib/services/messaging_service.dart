import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:get/get.dart'; // added
import '../models/message_model.dart';
import 'app_notification.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // reactive unread count used by UI
  final RxInt unreadCount = 0.obs; // add this

  StreamSubscription<int>? _unreadSub; // subscription handle

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

      // Send notification to the other user in the chat
      await _sendMessageNotification(chatId, user.uid, userData['displayName'] ?? 'User', content);
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

  // Get user's chats (for donors - all chats where they are the donor)
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

  // Get receiver's chats (for receivers - all chats where they are the receiver)
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

  // Delete a message (only sender can delete their own messages)
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get the message to verify ownership
      final messageDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final messageData = messageDoc.data()!;
      final senderId = messageData['senderId'] as String;

      // Only allow sender to delete their own message
      if (senderId != user.uid) {
        throw Exception('You can only delete your own messages');
      }

      // Delete the message
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();

      // If this was the last message, update chat's lastMessage
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        final lastMessageId = chatData['lastMessageSenderId'] as String?;
        
        // If deleted message was the last one, update chat with previous message
        if (lastMessageId == user.uid) {
          // Get the most recent remaining message
          final messagesQuery = await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          if (messagesQuery.docs.isNotEmpty) {
            final lastMsg = messagesQuery.docs.first;
            final lastMsgData = lastMsg.data();
            await _firestore.collection('chats').doc(chatId).update({
              'lastMessage': lastMsgData['content'] ?? 'No messages',
              'lastMessageTime': lastMsgData['timestamp'],
              'lastMessageSenderId': lastMsgData['senderId'] ?? '',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            // No messages left, set default
            await _firestore.collection('chats').doc(chatId).update({
              'lastMessage': 'No messages',
              'lastMessageTime': FieldValue.serverTimestamp(),
              'lastMessageSenderId': '',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
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

  // Send message notification to the other user in the chat
   Future<void> _sendMessageNotification(String chatId, String senderId, String senderName, String messageContent) async {
    try {
      // Get chat details to find the recipient
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data()!;
      String recipientId;
      String recipientUserType;

      // Determine recipient based on who sent the message
      if (chatData['donorId'] == senderId) {
        recipientId = chatData['receiverId'];
        recipientUserType = 'receiver';
      } else {
        recipientId = chatData['donorId'];
        recipientUserType = 'donor';
      }

      // Get recipient's user data to determine their user type
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      if (!recipientDoc.exists) return;

      final recipientData = recipientDoc.data()!;
      final recipientUserTypeFromDB = recipientData['userType'] ?? 'unknown';

      // Send simple notification document with sender's real name in the title
      await AppNotification.send(
        AppNotification(
          userId: recipientId,
          title: 'New Message from $senderName 💬',  // Updated: Include sender's real name in title
          message: messageContent.length > 50 ? '${messageContent.substring(0, 50)}...' : messageContent,  // Simplified: Just the content
          type: 'new_message',
          data: {
            'chatId': chatId,
            'senderId': senderId,
            'senderName': senderName,
          },
        ),
      );
    } catch (e) {
      print('Error sending message notification: $e');
    }
  }

  // Get unread message count for receiver
  Stream<int> getReceiverUnreadMessageCount(String receiverId) {
    return _firestore
        .collection('chats')
        .where('receiverId', isEqualTo: receiverId)
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      int totalUnread = 0;
      
      for (final chatDoc in chatsSnapshot.docs) {
        final messagesQuery = await _firestore
            .collection('chats')
            .doc(chatDoc.id)
            .collection('messages')
            .where('senderId', isNotEqualTo: receiverId)
            .where('isRead', isEqualTo: false)
            .get();
        
        totalUnread += messagesQuery.docs.length;
      }
      
      return totalUnread;
    });
  }

  // Monitor unread count for a receiver and update unreadCount
  void monitorReceiverUnreadCount(String receiverId) {
    // cancel previous subscription if any
    _unreadSub?.cancel();
    _unreadSub = getReceiverUnreadMessageCount(receiverId).listen((count) {
      unreadCount.value = count;
    }, onError: (e) {
      print('Error monitoring unread count: $e');
    });
  }

  // Optional: stop monitoring (call from widget dispose)
  void dispose() {
    _unreadSub?.cancel();
    _unreadSub = null;
  }
}
