import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderType; // 'donor' or 'receiver'
  final String content;
  final String messageType; // 'text', 'image', 'location'
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;
  final GeoPoint? location;
  final String? locationAddress;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.content,
    required this.messageType,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
    this.location,
    this.locationAddress,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderType: data['senderType'] ?? '',
      content: data['content'] ?? '',
      messageType: data['messageType'] ?? 'text',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      imageUrl: data['imageUrl'],
      location: data['location'] as GeoPoint?,
      locationAddress: data['locationAddress'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderType': senderType,
      'content': content,
      'messageType': messageType,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'location': location,
      'locationAddress': locationAddress,
    };
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderType,
    String? content,
    String? messageType,
    DateTime? timestamp,
    bool? isRead,
    String? imageUrl,
    GeoPoint? location,
    String? locationAddress,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderType: senderType ?? this.senderType,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      locationAddress: locationAddress ?? this.locationAddress,
    );
  }
}

class ChatModel {
  final String id;
  final String donationId;
  final String donorId;
  final String receiverId;
  final String donorName;
  final String receiverName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSenderId;
  final bool donorActive;
  final bool receiverActive;

  ChatModel({
    required this.id,
    required this.donationId,
    required this.donorId,
    required this.receiverId,
    required this.donorName,
    required this.receiverName,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSenderId,
    this.donorActive = false,
    this.receiverActive = false,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      donationId: data['donationId'] ?? '',
      donorId: data['donorId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      donorName: data['donorName'] ?? '',
      receiverName: data['receiverName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      donorActive: data['donorActive'] ?? false,
      receiverActive: data['receiverActive'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'donationId': donationId,
      'donorId': donorId,
      'receiverId': receiverId,
      'donorName': donorName,
      'receiverName': receiverName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessageSenderId': lastMessageSenderId,
      'donorActive': donorActive,
      'receiverActive': receiverActive,
    };
  }
}
