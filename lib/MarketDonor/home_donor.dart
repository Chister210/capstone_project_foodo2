import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:capstone_project/role_select.dart';
import 'package:capstone_project/controllers/navigation_controller.dart';
import 'package:capstone_project/screens/map_screen.dart';
import 'package:capstone_project/screens/profile_screen.dart';
import 'package:capstone_project/screens/chat_list_screen.dart';
import 'package:capstone_project/widgets/enhanced_notification_popup.dart';
import 'package:capstone_project/widgets/donation_form.dart';
import 'package:capstone_project/widgets/donation_card.dart';
import 'package:capstone_project/screens/chat_screen.dart';
import 'package:capstone_project/services/donation_service.dart';
import 'package:capstone_project/services/donor_notification_service.dart';
import 'package:capstone_project/services/messaging_service.dart';
import 'package:capstone_project/services/terms_service.dart';
import 'package:capstone_project/models/donation_model.dart';
import 'package:capstone_project/widgets/terms_and_conditions_popup.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // added
import 'dart:async';

class DonorHome extends StatefulWidget {
  final String? displayName;
  const DonorHome({super.key, this.displayName});

  @override
  State<DonorHome> createState() => _DonorHomeState();
}

class _DonorHomeState extends State<DonorHome> {
  final NavigationController navigationController = Get.put(NavigationController());
  final DonationService _donationService = DonationService();
  final DonorNotificationService _donorNotifications = Get.put(DonorNotificationService());
  final MessagingService _messagingService = MessagingService();
  final TermsService _termsService = TermsService();

  String? _displayName; // cached display name
  StreamSubscription? _donationClaimedSubscription;
  final Set<String> _processedNotificationIds = {};
  DateTime _appStartTime = DateTime.now(); // Track when app was opened

  @override
  void initState() {
    super.initState();
    _appStartTime = DateTime.now(); // Record app start time
    // Delay to ensure Scaffold is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTermsAcceptance();
      _loadDisplayName(); // fetch display name from Firestore / Auth
      _setupDonationClaimedListener(); // Setup listener for donation claimed
    });
  }
  
  void _setupDonationClaimedListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Listen to notifications collection for NEW donation_claimed notifications only
    _donationClaimedSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'donation_claimed')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      for (var doc in snapshot.docChanges) {
        // Only process NEW notifications (added, not existing ones)
        if (doc.type == DocumentChangeType.added) {
          final notificationId = doc.doc.id;
          
          // Only process if not already shown
          if (!_processedNotificationIds.contains(notificationId)) {
            final data = doc.doc.data() as Map<String, dynamic>;
            final createdAt = data['createdAt'] as Timestamp?;
            
            // Only show popup if notification was created after app start (new notification)
            if (createdAt != null) {
              final notificationTime = createdAt.toDate();
              
              // Check if notification is newer than app start time (with 5 second buffer)
              if (notificationTime.isAfter(_appStartTime.subtract(const Duration(seconds: 5)))) {
                _processedNotificationIds.add(notificationId);
                
                final notificationData = data['data'] as Map<String, dynamic>? ?? {};
                
                // Small delay to ensure UI is ready
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    _showDonationClaimedDialog(notificationData, notificationId);
                  }
                });
              }
            }
          }
        }
      }
    });
  }
  
  Future<void> _showDonationClaimedDialog(Map<String, dynamic> data, String notificationId) async {
    final donationId = data['donationId'] as String?;
    final receiverName = data['receiverName'] as String? ?? 'Receiver';
    final donationTitle = data['donationTitle'] as String? ?? 'Your donation';
    final chatId = data['chatId'] as String?;
    final receiverId = data['receiverId'] as String?;
    
    if (donationId == null) return;
    
    // Get receiver name from Firestore if needed
    String finalReceiverName = receiverName;
    if (finalReceiverName == 'Receiver' && receiverId != null) {
      try {
        final receiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(receiverId)
            .get();
        if (receiverDoc.exists) {
          final receiverData = receiverDoc.data()!;
          finalReceiverName = receiverData['displayName'] ?? 
                            receiverData['email']?.toString().split('@')[0] ?? 
                            'Receiver';
        }
      } catch (e) {
        debugPrint('Error fetching receiver name: $e');
      }
    }
    
    // Wait for chatId if not available yet
    String? finalChatId = chatId;
    if ((finalChatId == null || finalChatId.isEmpty)) {
      int retries = 0;
      while ((finalChatId == null || finalChatId.isEmpty) && retries < 5) {
        await Future.delayed(const Duration(milliseconds: 300));
        try {
          final donationDoc = await FirebaseFirestore.instance
              .collection('donations')
              .doc(donationId)
              .get();
          if (donationDoc.exists) {
            final donationData = donationDoc.data()!;
            finalChatId = donationData['chatId'] as String?;
          }
        } catch (e) {
          debugPrint('Error fetching chatId: $e');
        }
        retries++;
      }
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey[50]!,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                const Text(
                  'Donation Claimed!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Content
                Text(
                  '$finalReceiverName claimed "$donationTitle"',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Message box with gradient
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[50]!, Colors.blue[100]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[300]!, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[600],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Go to messages to start communicating with $finalReceiverName!',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Action button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
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
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        
                        // Mark notification as read
                        FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(notificationId)
                            .update({'isRead': true});
                        
                        await Future.delayed(const Duration(milliseconds: 200));
                        
                        if (!mounted) return;
                        
                        if (finalChatId != null && finalChatId.isNotEmpty) {
                          // Navigate to specific chat
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                chatId: finalChatId!,
                                otherUserName: finalReceiverName,
                                otherUserType: 'receiver',
                              ),
                            ),
                          );
                        } else {
                          // Fallback: go to messages tab
                          navigationController.changePage(2);
                        }
                      },
                      icon: const Icon(Icons.chat, size: 20),
                      label: const Text(
                        'Go to Messages',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _donationClaimedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkTermsAcceptance() async {
    try {
      final needsTerms = await _termsService.needsTermsAcceptance();
      if (needsTerms && mounted) {
        _showTermsPopup();
      }
    } catch (e) {
      print('Error checking terms acceptance: $e');
    }
  }

  void _showTermsPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TermsAndConditionsPopup(
        onAccepted: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Terms accepted! Welcome to Foodo.'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onDeclined: () {
          Navigator.pop(context);
          // Navigate back to role selection instead of closing app
          Get.offAll(() => const RoleSelect());
        },
      ),
    );
  }

  void _showNotificationPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping on popup
              child: const EnhancedNotificationPopup(userType: 'donor'),
            ),
          ),
        ),
      ),
    );
  }

  void _showDonationForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DonationForm(
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Donation created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDonationDetails(DonationModel donation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(donation.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fixed image section with null check
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: donation.hasImage ? Colors.transparent : Colors.grey[100],
                ),
                child: donation.hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          donation.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImagePlaceholder();
                          },
                        ),
                      )
                    : _buildImagePlaceholder(),
              ),
              const SizedBox(height: 16),
              Text(
                'Description:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(donation.description),
              const SizedBox(height: 16),
              
              // Food Type and Quantity
              if (donation.foodType != null || donation.quantity != null) ...[
                Row(
                  children: [
                    if (donation.foodType != null)
                      _buildDetailRow(
                        icon: Icons.category_rounded,
                        text: 'Type: ${donation.foodType}',
                      ),
                    if (donation.foodType != null && donation.quantity != null)
                      const SizedBox(width: 16),
                    if (donation.quantity != null)
                      _buildDetailRow(
                        icon: Icons.scale_rounded,
                        text: 'Quantity: ${donation.quantity}',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              // Delivery Type
              _buildDetailRow(
                icon: donation.deliveryType == 'pickup' 
                    ? Icons.location_on_rounded 
                    : Icons.delivery_dining_rounded,
                text: 'Type: ${donation.deliveryType == 'pickup' ? 'Pickup' : 'Delivery'}',
              ),
              const SizedBox(height: 8),
              
              // Pickup Time
              _buildDetailRow(
                icon: Icons.schedule_rounded,
                text: 'Pickup: ${_formatDateTime(donation.pickupTime)}',
              ),
              const SizedBox(height: 8),
              
              // Status
              _buildDetailRow(
                icon: Icons.info_rounded,
                text: 'Status: ${donation.status.toUpperCase()}',
              ),
              
              // Allergens
              if (donation.allergens != null && donation.allergens!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Allergens:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: donation.allergens!.map((allergen) {
                    return Chip(
                      label: Text(allergen),
                      backgroundColor: const Color(0xFFef4444).withOpacity(0.1),
                      labelStyle: const TextStyle(
                        color: Color(0xFFef4444),
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          // Donation claimed status indicator
          if ((donation.status == 'claimed' || donation.status == 'in_progress') && 
              donation.claimedBy != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Completion confirmation removed
                Get.snackbar(
                  'Info',
                  'Confirmation feature has been removed',
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22c55e),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Completion'),
            ),
          if (donation.status == 'available')
            ElevatedButton(
              onPressed: () async {
                try {
                  await _donationService.updateDonationStatus(donation.id, 'expired');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Donation marked as expired'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Mark Expired'),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fastfood_rounded,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'No Image Available',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF22c55e),
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }


  Future<void> _loadDisplayName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Try Firestore users collection first
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      final nameFromDoc = data != null ? (data['displayName'] ?? data['name']) : null;

      // safer fallback: use displayName if available, otherwise derive from email if present
      final fallback = user.displayName ?? user.email?.split('@')[0] ?? 'Donor';

      setState(() {
        _displayName = (nameFromDoc != null && nameFromDoc.toString().isNotEmpty)
            ? nameFromDoc.toString()
            : fallback;
      });
    } catch (e) {
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _displayName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Donor';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // priority: explicit prop from main.dart -> cached _displayName -> auth displayName -> email fallback
    final displayName = widget.displayName ?? _displayName ?? user?.displayName ?? user?.email?.split('@')[0] ?? 'Donor';
    return Scaffold(
      body: PageView(
        controller: navigationController.pageController,
        onPageChanged: (index) {
          navigationController.currentIndex.value = index;
        },
        children: [
          // Home Screen
          _buildHomeScreen(user, displayName),
          // Map Screen
          const MapScreen(),
          // Messages Screen
          const ChatListScreen(),
          // Profile Screen
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Obx(() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                  isSelected: navigationController.currentIndex.value == 0,
                ),
                _buildNavItem(
                  icon: Icons.map_rounded,
                  label: 'Map',
                  index: 1,
                  isSelected: navigationController.currentIndex.value == 1,
                ),
                _buildNavItem(
                  icon: Icons.chat_rounded,
                  label: 'Messages',
                  index: 2,
                  isSelected: navigationController.currentIndex.value == 2,
                  showCounter: true,
                ),
                _buildNavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  index: 3,
                  isSelected: navigationController.currentIndex.value == 3,
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildHomeScreen(User? user, String displayName) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Color(0xFFF1F5F9),
                Color(0xFFE0F7FA),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: const Text(
          'Donor Dashboard',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // Notification Icon
          Obx(() => Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded),
                onPressed: _showNotificationPopup,
                tooltip: 'Notifications',
              ),
              if (_donorNotifications.unreadCount.value > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF22c55e),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '${_donorNotifications.unreadCount.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          )),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Color(0xFFF1F5F9),
              Color(0xFFE0F7FA),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hello, $displayName',
                  style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // Create Donation Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showDonationForm(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22c55e),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_rounded),
                    label: const Text(
                      'Create New Donation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Active Donations Section
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_rounded,
                      color: Color(0xFF22c55e),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'My Donations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    // Refresh button
                    IconButton(
                      onPressed: () {
                        // Force refresh the stream
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                      color: const Color(0xFF22c55e),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Donations List
                Expanded(
                  child: StreamBuilder<List<DonationModel>>(
                    stream: _donationService.getDonationsByDonor(user!.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF22c55e),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_rounded,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading donations: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => setState(() {}),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22c55e),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      final donations = snapshot.data ?? [];
                      
                      if (donations.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_rounded,
                                color: Colors.grey.withOpacity(0.6),
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No donations yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first donation to help reduce food waste',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.withOpacity(0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _showDonationForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22c55e),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Create Donation'),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return RefreshIndicator(
                        onRefresh: () async {
                          setState(() {});
                        },
                        child: ListView.builder(
                          itemCount: donations.length,
                          itemBuilder: (context, index) {
                            final donation = donations[index];
                            return DonationCard(
                              donation: donation,
                              isDonorView: true,
                              onTap: () => _showDonationDetails(donation),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
    bool showCounter = false,
  }) {
    return GestureDetector(
      onTap: () => navigationController.changePage(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF22c55e).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF22c55e) : Colors.black54,
                  size: 24,
                ),
                if (showCounter)
                  StreamBuilder<int>(
                    stream: _messagingService.getUnreadMessageCount(FirebaseAuth.instance.currentUser?.uid ?? ''),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      if (unreadCount > 0) {
                        return Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF22c55e),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF22c55e) : Colors.black54,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}