import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/receiver_notification_service.dart';
import '../services/donor_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EnhancedNotificationPopup extends StatelessWidget {
  final String userType;

  const EnhancedNotificationPopup({
    super.key,
    required this.userType,
  });

  @override
  Widget build(BuildContext context) {
    // Choose service based on userType
    final bool isDonor = userType == 'donor';
    final donorService = Get.find<DonorNotificationService>();
    final receiverService = Get.find<ReceiverNotificationService>();
    
    return Container(
      width: 350,
      height: 500, // Fixed height for better UX
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(isDonor ? donorService.unreadCount.value : receiverService.unreadCount.value),
          
          // Notification List
          _buildNotificationList(isDonor ? donorService.notifications : receiverService.notifications,
              onMarkRead: (id) async {
            // Mark as read directly in Firestore
            await FirebaseFirestore.instance.collection('notifications').doc(id).update({'isRead': true});
          }),
          
          // Footer
          _buildFooter(context, isDonor),
        ],
      ),
    );
  }

  Widget _buildHeader(int unreadCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF22c55e),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              unreadCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> items, {required Future<void> Function(String id) onMarkRead}) {
    return Expanded(
      child: Obx(() {
        final notifications = items;
        
        if (notifications.isEmpty) {
          return _buildEmptyState();
        }
        
        return RefreshIndicator(
          onRefresh: () async {
            // Simple refresh - Firestore streams update automatically
            await Future.delayed(const Duration(milliseconds: 1000));
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationItem(
                notification: notification,
                onTap: () => _handleNotificationTap(notification, onMarkRead),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDonor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () async {
                // Mark all as read for the current user
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  final qs = await FirebaseFirestore.instance
                      .collection('notifications')
                      .where('userId', isEqualTo: uid)
                      .where('isRead', isEqualTo: false)
                      .get();
                  final batch = FirebaseFirestore.instance.batch();
                  for (final d in qs.docs) {
                    batch.update(d.reference, {'isRead': true});
                  }
                  await batch.commit();
                }
                Get.snackbar(
                  'Success',
                  'All notifications marked as read',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: const Color(0xFF22c55e),
                  colorText: Colors.white,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF22c55e),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Mark All Read',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22c55e),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Removed old NotificationService helpers

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            color: Colors.grey,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'No notifications',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'New notifications will appear here',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification, Future<void> Function(String id) onMarkRead) async {
    // Mark notification as read
    if (notification['id'] != null) {
      await onMarkRead(notification['id']);
    }
    
    // Handle different notification types with specific actions
    _handleNotificationAction(notification);
  }

  void _handleNotificationAction(Map<String, dynamic> notification) {
    final String type = notification['type'] ?? '';
    final String title = notification['title'] ?? 'Notification';
    final String message = notification['message'] ?? '';

    switch (type) {
      case 'donation_claimed':
        Get.snackbar(
          title,
          message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF22c55e),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        // Optional: Navigate to donation details
        // Get.to(() => DonationDetailsPage(donationId: notification['donationId']));
        break;
        
      case 'new_donation':
        Get.snackbar(
          title,
          message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF3b82f6),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        // Optional: Navigate to donations list
        // Get.to(() => AvailableDonationsPage());
        break;
        
      case 'donation_completed':
        Get.snackbar(
          title,
          message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF8b5cf6),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        break;
        
      case 'message_received':
        Get.snackbar(
          title,
          message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFFf59e0b),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        // Optional: Navigate to chat
        // Get.to(() => ChatPage(chatId: notification['chatId']));
        break;
        
      default:
        Get.snackbar(
          title,
          message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF6b7280),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        break;
    }
  }
}

class _NotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = notification['isRead'] as bool? ?? false;
    final timestamp = _parseTimestamp(notification);
    final title = _getNotificationTitle(notification);
    final message = _getNotificationMessage(notification);

    return Material(
      color: isRead ? Colors.transparent : const Color(0xFF22c55e).withOpacity(0.05),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getNotificationColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _getNotificationIcon(),
                  color: _getNotificationColor(),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Notification Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF22c55e),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(timestamp),
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _parseTimestamp(Map<String, dynamic> notification) {
    final rawTimestamp = notification['timestamp'] ?? notification['createdAt'];
    
    try {
      if (rawTimestamp == null) {
        return DateTime.now();
      } else if (rawTimestamp is DateTime) {
        return rawTimestamp;
      } else if (rawTimestamp is String) {
        return DateTime.tryParse(rawTimestamp) ?? DateTime.now();
      } else if (rawTimestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
      } else if (rawTimestamp is Map && rawTimestamp.containsKey('seconds')) {
        return DateTime.fromMillisecondsSinceEpoch((rawTimestamp['seconds'] as int) * 1000);
      } else if (rawTimestamp.runtimeType.toString() == 'Timestamp') {
        return (rawTimestamp as dynamic).toDate();
      }
    } catch (e) {
      print('Error parsing timestamp: $e');
    }
    
    return DateTime.now();
  }

  String _getNotificationTitle(Map<String, dynamic> notification) {
    final String? title = notification['title'] as String?;
    return (title?.trim().isNotEmpty == true) ? title! : 'Notification';
  }

  String _getNotificationMessage(Map<String, dynamic> notification) {
    final String? message = notification['message'] as String?;
    return (message?.trim().isNotEmpty == true) ? message! : 'You have a new notification.';
  }

  IconData _getNotificationIcon() {
    switch (notification['type']) {
      case 'donation_claimed':
        return Icons.check_circle_rounded;
      case 'new_donation':
        return Icons.restaurant_rounded;
      case 'donation_completed':
        return Icons.celebration_rounded;
      case 'message_received':
        return Icons.chat_rounded;
      case 'donation_expired':
        return Icons.warning_rounded;
      case 'donation_cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor() {
    switch (notification['type']) {
      case 'donation_claimed':
        return const Color(0xFF22c55e);
      case 'new_donation':
        return const Color(0xFF3b82f6);
      case 'donation_completed':
        return const Color(0xFF8b5cf6);
      case 'message_received':
        return const Color(0xFFf59e0b);
      case 'donation_expired':
        return const Color(0xFFef4444);
      case 'donation_cancelled':
        return const Color(0xFFdc2626);
      default:
        return const Color(0xFF6b7280);
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    }
  }
}