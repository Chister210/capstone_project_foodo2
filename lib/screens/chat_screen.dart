import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import '../models/message_model.dart';
import '../models/donation_model.dart';
import '../services/messaging_service.dart';
import '../services/donation_service.dart';
import '../services/location_tracking_service.dart';
import '../screens/feedback_screen.dart';
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
  DonationModel? _donation; // Current donation data
  StreamSubscription<DocumentSnapshot>? _donationSubscription; // Listen for donation changes
  bool _donorConfirmPopupShown = false; // Track if donor popup was shown
  bool _successPopupShown = false; // Track if success popup was shown

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _markMessagesAsRead();
    _loadChatAndDonationInfo();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _donationSubscription?.cancel();
    super.dispose();
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
            
            // Load donation data and set up listener
            if (donationId != null) {
              // Reset popup flags when loading a new chat/donation
              // This allows popups to show for repeat transactions
              _donorConfirmPopupShown = false;
              _successPopupShown = false;
              
              _loadDonationData(donationId);
              _setupDonationListener(donationId);
            }
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
            
            // Load donation data and set up listener
            if (donationIdFromChatId != null) {
              // Reset popup flags when loading a new chat/donation
              // This allows popups to show for repeat transactions
              _donorConfirmPopupShown = false;
              _successPopupShown = false;
              
              _loadDonationData(donationIdFromChatId);
              _setupDonationListener(donationIdFromChatId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading chat info: $e');
    }
  }

  // Load donation data
  Future<void> _loadDonationData(String donationId) async {
    try {
      final donationDoc = await FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId)
          .get();
      
      if (donationDoc.exists && mounted) {
        setState(() {
          _donation = DonationModel.fromFirestore(donationDoc);
        });
      }
    } catch (e) {
      debugPrint('Error loading donation data: $e');
    }
  }

  // Set up listener for donation changes (to show popups for both donor and receiver)
  void _setupDonationListener(String donationId) {
    _donationSubscription?.cancel();
    
    // Set up listener for both donors and receivers to show success popup
    
    _donationSubscription = FirebaseFirestore.instance
        .collection('donations')
        .doc(donationId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      
      final donation = DonationModel.fromFirestore(snapshot);
      
      // Update donation state immediately
      if (mounted) {
        setState(() {
          _donation = donation;
        });
      }
      
      // Get receiverId from chat to check confirmation for this specific transaction
      // Use async callback to fetch chat data (can't use await in stream listener)
      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get()
          .then((chatDoc) {
        if (!mounted || !chatDoc.exists) return;
        
        final chatData = chatDoc.data()!;
        final receiverId = chatData['receiverId'] as String?;
        final donorId = chatData['donorId'] as String?;
        
        // Determine if current user is the donor for this chat
        final isDonor = donorId == _currentUserId;
        
        debugPrint('🔍 Donation listener: isDonor=$isDonor, currentUserId=$_currentUserId, donorId=$donorId');
        
        if (receiverId != null && mounted) {
          // Check if this specific receiver confirmed (for this transaction)
          final receiverConfirmations = donation.receiverConfirmations ?? {};
          final donorConfirmations = donation.donorConfirmations ?? {};
          
          final receiverConfirmed = receiverConfirmations[receiverId] == true;
          final donorConfirmed = donorConfirmations[receiverId] == true;
          
          debugPrint('🔍 Confirmation status: receiverConfirmed=$receiverConfirmed, donorConfirmed=$donorConfirmed, popupShown=$_donorConfirmPopupShown');
          
          // Reset popup flags appropriately for new transactions
          // This allows popups to show again when the same user claims again
          if (!receiverConfirmed && !donorConfirmed) {
            // Both confirmations are false - reset both flags for new transaction
            if (_donorConfirmPopupShown || _successPopupShown) {
              debugPrint('🔄 Resetting popup flags for new transaction');
            }
            _donorConfirmPopupShown = false;
            _successPopupShown = false;
          } else if (donorConfirmed) {
            // Donor confirmed - reset donor popup flag (already shown)
            if (_donorConfirmPopupShown) {
              _donorConfirmPopupShown = false;
            }
          }
          
          // Check if receiver just confirmed for this transaction (receiver confirmed, but donor hasn't for this receiver yet)
          // Only show popup if current user is the donor
          if (isDonor && receiverConfirmed && !donorConfirmed && !_donorConfirmPopupShown && mounted) {
            // Show popup to donor for this specific receiver
            debugPrint('📢 Showing donor confirmation popup for receiver: $receiverId');
            Future.microtask(() {
              if (mounted && !_donorConfirmPopupShown) {
                _showDonorConfirmationPopup(donation, receiverId);
                _donorConfirmPopupShown = true;
              }
            });
          }
          
          // Check if transaction is completed and show success popup for both parties
          // Show when both have confirmed, even if status hasn't been updated to 'completed' yet
          if (receiverConfirmed && donorConfirmed && !_successPopupShown && mounted) {
            // Show success popup for both receiver and donor
            debugPrint('🎉 Showing success popup - both confirmed');
            Future.microtask(() {
              if (mounted && !_successPopupShown) {
                _showSuccessPopup(donation);
              }
            });
          }
        }
      }).catchError((e) {
        debugPrint('Error getting chat data in listener: $e');
      });
      
      // Fallback: check global confirmation (for backward compatibility - only for donors)
      // Also check if current user is the donor of this donation
      final isDonorByDonation = donation.donorId == _currentUserId;
      if (!_donorConfirmPopupShown && 
          (_userType == 'donor' || isDonorByDonation) &&
          mounted) {
        final receiverConfirmations = donation.receiverConfirmations ?? {};
        final donorConfirmations = donation.donorConfirmations ?? {};
        
        // Check if any receiver confirmed but donor hasn't confirmed for them
        final hasPendingConfirmation = receiverConfirmations.entries.any((entry) {
          return entry.value == true && (donorConfirmations[entry.key] != true);
        });
        
        if (hasPendingConfirmation) {
          // Find the first receiver that needs confirmation
          try {
            final pendingReceiver = receiverConfirmations.entries
                .firstWhere((entry) => entry.value == true && (donorConfirmations[entry.key] != true));
            
            debugPrint('📢 Fallback: Showing donor confirmation popup for receiver: ${pendingReceiver.key}');
            Future.microtask(() {
              if (mounted && !_donorConfirmPopupShown) {
                _showDonorConfirmationPopup(donation, pendingReceiver.key);
                _donorConfirmPopupShown = true;
              }
            });
          } catch (e) {
            debugPrint('No pending receiver found: $e');
          }
        }
      }
      
      // Additional check for success popup when status is completed
      // This is a backup to ensure success popup shows even if the above check missed it
      if (donation.status == 'completed' && mounted && !_successPopupShown) {
        // Get receiverId from chat to check if this transaction is completed
        FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .get()
            .then((chatDoc) {
          if (!mounted || !chatDoc.exists) return;
          
          final chatData = chatDoc.data()!;
          final receiverId = chatData['receiverId'] as String?;
          
          if (receiverId != null && mounted && !_successPopupShown) {
            final receiverConfirmations = donation.receiverConfirmations ?? {};
            final donorConfirmations = donation.donorConfirmations ?? {};
            
            // Check if this specific transaction is completed
            final isTransactionCompleted = receiverConfirmations[receiverId] == true &&
                                          donorConfirmations[receiverId] == true;
            
            if (isTransactionCompleted && !_successPopupShown && mounted) {
              debugPrint('🎉 Backup: Showing success popup - status is completed');
              Future.microtask(() {
                if (mounted && !_successPopupShown) {
                  _showSuccessPopup(donation);
                }
              });
            }
          }
        }).catchError((e) {
          debugPrint('Error checking completion status: $e');
        });
      }
      
      // Reset success popup flag if donation is no longer completed and confirmations are reset
      // This allows the popup to show again for new transactions
      // Also check if this specific transaction is no longer confirmed
      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get()
          .then((chatDoc) {
        if (!mounted || !chatDoc.exists) return;
        
        final chatData = chatDoc.data()!;
        final receiverId = chatData['receiverId'] as String?;
        
        if (receiverId != null) {
          final receiverConfirmationsGlobal = donation.receiverConfirmations ?? {};
          final donorConfirmationsGlobal = donation.donorConfirmations ?? {};
          
          // Check if this specific transaction is no longer confirmed (both false)
          final thisReceiverConfirmed = receiverConfirmationsGlobal[receiverId] == true;
          final thisDonorConfirmed = donorConfirmationsGlobal[receiverId] == true;
          
          // Reset success popup if this transaction is not confirmed anymore
          if (!thisReceiverConfirmed || !thisDonorConfirmed) {
            if (_successPopupShown) {
              debugPrint('🔄 Resetting success popup flag - transaction not confirmed');
              _successPopupShown = false;
            }
          }
        }
      }).catchError((e) {
        debugPrint('Error checking reset conditions: $e');
      });
      
      // Update donation state
      if (mounted) {
        setState(() {
          _donation = donation;
        });
      }
    });
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteChatDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Chat History'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Receiver confirmation button (only when donation is claimed and not completed for this receiver)
          if (_userType == 'receiver' && 
              _donationId != null && 
              _donation != null &&
              _currentUserId != null &&
              (_donation!.claimedBy == _currentUserId || 
               (_donation!.quantityClaims?.containsKey(_currentUserId) ?? false)) &&
              _donation!.status != 'completed')
            Builder(
              builder: (context) {
                // Check if this specific receiver has already confirmed
                final receiverConfirmations = _donation!.receiverConfirmations ?? {};
                final hasConfirmed = receiverConfirmations[_currentUserId] == true;
                
                if (!hasConfirmed) {
                  return _buildReceiverConfirmationButton();
                }
                return const SizedBox.shrink();
              },
            ),
          
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

  // Build receiver confirmation button
  Widget _buildReceiverConfirmationButton() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22c55e).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Did you receive the donation?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _showReceiverConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF22c55e),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Yes, I Received It',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Show receiver confirmation dialog
  Future<void> _showReceiverConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22c55e).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_circle, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Confirm Donation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Have you received the donation "${_donation?.title ?? 'this donation'}"?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!, width: 2),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22c55e).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Yes, Confirm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && _donationId != null && _currentUserId != null) {
      setState(() => _isProcessing = true);
      try {
        await _donationService.confirmDonationReceived(_donationId!, _currentUserId!);
        
        // Update local state immediately to hide the button
        if (mounted && _donation != null) {
          final updatedReceiverConfirmations = Map<String, bool>.from(_donation!.receiverConfirmations ?? {});
          updatedReceiverConfirmations[_currentUserId!] = true;
          
          setState(() {
            _donation = _donation!.copyWith(
              receiverConfirmations: updatedReceiverConfirmations,
            );
          });
        }
        
        // Also reload from Firestore to ensure consistency
        if (_donationId != null) {
          await _loadDonationData(_donationId!);
        }
        
        if (mounted) {
          Get.snackbar(
            'Success',
            'Confirmation sent to donor',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
        }
      } catch (e) {
        if (mounted) {
          Get.snackbar(
            'Error',
            'Failed to confirm: $e',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  // Show donor confirmation popup for a specific receiver
  void _showDonorConfirmationPopup(DonationModel donation, String receiverId) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3b82f6), Color(0xFF2563eb)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3b82f6).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.notifications_active, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Receiver Confirmed Donation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${_receiverName ?? 'The receiver'} confirmed they received "${donation.title}". Please confirm to complete the donation.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!, width: 2),
                        ),
                      ),
                      child: Text(
                        'Later',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22c55e).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _confirmAsDonor(donation, receiverId);
                          },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Confirm Completion',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Get receiver name helper
  Future<String> _getReceiverName(String receiverId) async {
    try {
      final receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      if (receiverDoc.exists) {
        final receiverData = receiverDoc.data()!;
        return receiverData['displayName'] ?? receiverData['email']?.split('@')[0] ?? 'Receiver';
      }
    } catch (e) {
      debugPrint('Error getting receiver name: $e');
    }
    return _receiverName ?? 'Receiver';
  }

  // Confirm as donor for a specific receiver
  Future<void> _confirmAsDonor(DonationModel donation, String receiverId) async {
    if (_donationId == null || _currentUserId == null) return;
    
    setState(() => _isProcessing = true);
    try {
      await _donationService.confirmDonationCompleted(_donationId!, _currentUserId!, receiverId);
      
      // Reload donation to get updated status
      await _loadDonationData(_donationId!);
      
      // The success popup will be shown by the listener when status becomes 'completed'
      // This ensures both receiver and donor see it
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed to confirm: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Show success popup for both parties
  void _showSuccessPopup(DonationModel donation) {
    if (!mounted || _successPopupShown) return;
    
    // Mark as shown to prevent duplicate popups
    _successPopupShown = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lottie animation
              SizedBox(
                width: 150,
                height: 150,
                child: Lottie.asset(
                  'assets/lottie_files/food_claimed.json',
                  fit: BoxFit.contain,
                  repeat: false,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _userType == 'donor' ? 'Donation Completed!' : 'Donation Successful!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _userType == 'donor'
                    ? 'Your donation "${donation.title}" is completed. You earned 10 points!'
                    : 'The donation "${donation.title}" has been successfully completed. Thank you for using Foodo!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              // Show feedback option for receivers
              if (_userType == 'receiver') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber[200]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Share your feedback about the food quality',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.amber[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22c55e).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      
                      // Navigate to feedback screen for receivers
                      if (_userType == 'receiver' && _donationId != null && _currentUserId != null) {
                        // Small delay to ensure success popup is closed
                        await Future.delayed(const Duration(milliseconds: 300));
                        
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FeedbackScreen(
                                donationId: _donationId!,
                                donationTitle: donation.title,
                                donorId: donation.donorId,
                              ),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _userType == 'receiver' ? 'Rate & Continue' : 'Close',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show delete chat history dialog
  Future<void> _showDeleteChatDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Chat History',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to delete all messages in this chat? This action cannot be undone.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!, width: 2),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Color(0xFFdc2626)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isProcessing
                            ? null
                            : () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Delete',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        await _messagingService.deleteChat(widget.chatId);
        if (mounted) {
          Get.snackbar(
            'Success',
            'Chat history deleted successfully',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
        }
      } catch (e) {
        if (mounted) {
          Get.snackbar(
            'Error',
            'Failed to delete chat: $e',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

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

