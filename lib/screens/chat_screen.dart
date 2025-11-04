import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/message_model.dart';
import '../models/donation_model.dart';
import '../services/messaging_service.dart';
import '../services/donation_service.dart';
import '../services/location_tracking_service.dart';
import 'live_tracking_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserType;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserType,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final MessagingService _messagingService = MessagingService();
  final DonationService _donationService = DonationService();
  final LocationTrackingService _locationService = LocationTrackingService();
  final ScrollController _scrollController = ScrollController();
  
  String? _currentUserId;
  String? _donationId;
  String? _userType; // 'donor' or 'receiver'
  String? _receiverId; // For getting receiver name in donor view
  String? _receiverName; // Receiver name for donor button
  bool _isLoading = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _markMessagesAsRead();
    _loadChatAndDonationInfo();
  }


  Future<void> _loadChatAndDonationInfo() async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        final donationId = chatData['donationId'] as String?;
        final donorId = chatData['donorId'] as String?;
        final receiverId = chatData['receiverId'] as String?;
        String? userType;
        
        // Determine user type
        if (donorId == _currentUserId) {
          userType = 'donor';
        } else if (receiverId == _currentUserId) {
          userType = 'receiver';
        }
        
        // Get receiver name if user is donor
        String? receiverName;
        if (userType == 'donor' && receiverId != null) {
          receiverName = chatData['receiverName'] as String?;
          if (receiverName == null) {
            try {
              final receiverDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(receiverId)
                  .get();
              if (receiverDoc.exists) {
                receiverName = receiverDoc.data()?['displayName'] ?? 
                              receiverDoc.data()?['email']?.split('@')[0] ?? 
                              'Receiver';
              }
            } catch (e) {
              debugPrint('Error getting receiver name: $e');
            }
          }
        }
        
        // Set state immediately to ensure UI updates
        if (mounted) {
          setState(() {
            _donationId = donationId;
            _userType = userType;
            _receiverId = receiverId;
            _receiverName = receiverName;
          });
        }
        
      } else {
        // If chat doesn't exist, try to extract donationId from chatId format
        // Format: donorId_receiverId_donationId
        final parts = widget.chatId.split('_');
        if (parts.length >= 3) {
          final donationIdFromChatId = parts[2];
          String? userType;
          
          // Determine user type from chatId
          if (parts[0] == _currentUserId) {
            userType = 'donor';
          } else if (parts.length > 1 && parts[1] == _currentUserId) {
            userType = 'receiver';
          }
          
          if (mounted) {
            setState(() {
              _donationId = donationIdFromChatId;
              _userType = userType;
            });
            
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading chat info: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    if (_currentUserId != null) {
      await _messagingService.markMessagesAsRead(widget.chatId, _currentUserId!);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      await _messagingService.sendMessage(
        chatId: widget.chatId,
        content: _messageController.text.trim(),
      );
      
      _messageController.clear();
      
      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send message: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        await _messagingService.sendLocationMessage(
          chatId: widget.chatId,
          location: GeoPoint(position.latitude, position.longitude),
          locationAddress: '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        );
      } else {
        Get.snackbar(
          'Error',
          'Unable to get current location',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send location: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _startLiveTracking() async {
    try {
      // Get donation ID from chat
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      
      if (!chatDoc.exists) {
        Get.snackbar(
          'Error',
          'Chat not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      final chatData = chatDoc.data()!;
      final donationId = chatData['donationId'] as String?;
      
      if (donationId == null) {
        Get.snackbar(
          'Error',
          'Donation not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // Get other user ID
      final otherUserId = widget.otherUserType == 'donor' 
          ? chatData['donorId'] as String
          : chatData['receiverId'] as String;
      
      // Navigate to live tracking screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveTrackingScreen(
            donationId: donationId,
            otherUserId: otherUserId,
            otherUserName: widget.otherUserName,
            otherUserType: widget.otherUserType,
          ),
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to start live tracking: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildMessageBubble(MessageModel message) {
    final isMe = message.senderId == _currentUserId;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(message.senderId).get(),
      builder: (context, snapshot) {
        String displayName = message.senderName;
        String? photoUrl;
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          displayName = userData['displayName'] ?? message.senderName;
          photoUrl = userData['photoUrl'];
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onLongPress: isMe ? () => _showDeleteMessageDialog(message) : null,
              child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isMe) ...[
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF22c55e),
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.75,
                        minWidth: 0,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF22c55e) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          if (message.messageType == 'text')
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                message.content,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
                                  fontSize: 16,
                                ),
                                maxLines: 10,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else if (message.messageType == 'location')
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: Colors.white),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Location Shared',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    message.locationAddress ?? 'Unknown location',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: (FirebaseAuth.instance.currentUser?.photoURL != null && FirebaseAuth.instance.currentUser!.photoURL!.isNotEmpty)
                          ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                          : null,
                      child: (FirebaseAuth.instance.currentUser?.photoURL == null || FirebaseAuth.instance.currentUser!.photoURL!.isEmpty)
                          ? Text(
                              FirebaseAuth.instance.currentUser?.displayName?[0].toUpperCase() ?? 'U',
                              style: const TextStyle(color: Colors.black, fontSize: 12),
                            )
                          : null,
                    ),
                  ],
                ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.otherUserType == 'donor' ? 'Market Donor' : 'Food Receiver',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _sendLocation,
            tooltip: 'Share Location',
          ),
          IconButton(
            icon: const Icon(Icons.track_changes),
            onPressed: _startLiveTracking,
            tooltip: 'Live Tracking',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messagingService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(25)),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Color(0xFFF5F5F5),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF22c55e),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show delete message confirmation dialog
  Future<void> _showDeleteMessageDialog(MessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'Delete Message',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await _messagingService.deleteMessage(widget.chatId, message.id);
        if (mounted) {
          Get.snackbar(
            'Success',
            'Message deleted',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
        }
      } catch (e) {
        if (mounted) {
          Get.snackbar(
            'Error',
            'Failed to delete message: $e',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }
}

