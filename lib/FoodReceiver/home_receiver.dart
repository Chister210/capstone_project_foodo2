import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:capstone_project/role_select.dart';
import 'package:capstone_project/controllers/navigation_controller.dart';
import 'package:capstone_project/screens/map_screen.dart';
import 'package:capstone_project/screens/profile_screen.dart';
import 'package:capstone_project/screens/chat_list_screen.dart';
import 'package:capstone_project/screens/chat_screen.dart';
import 'package:capstone_project/screens/statistics_screen.dart';
import 'package:capstone_project/screens/public_feedback_screen.dart';
import 'package:capstone_project/utils/responsive_layout.dart';
import 'package:capstone_project/widgets/responsive_bottom_navigation.dart';
import 'package:capstone_project/services/user_service.dart';
import 'package:capstone_project/screens/receiver_donation_details_screen.dart';
import 'package:capstone_project/widgets/enhanced_notification_popup.dart';
import 'package:capstone_project/widgets/donation_card.dart';
import 'package:capstone_project/widgets/quantity_selector_dialog.dart';
import 'package:capstone_project/widgets/food_claim_dialog.dart';
import 'package:capstone_project/services/donation_service.dart';
import 'package:capstone_project/services/receiver_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_project/services/messaging_service.dart';
import 'package:capstone_project/services/terms_service.dart';
import 'package:capstone_project/services/location_tracking_service.dart';
import 'package:capstone_project/models/donation_model.dart';
import 'package:capstone_project/widgets/terms_and_conditions_popup.dart';
import 'dart:convert';
import 'package:flutter/services.dart'; // Add this import for SystemNavigator

class ReceiverHome extends StatefulWidget {
  final String? displayName;
  const ReceiverHome({super.key, this.displayName});

  @override
  State<ReceiverHome> createState() => _ReceiverHomeState();
}

class _ReceiverHomeState extends State<ReceiverHome> {
  bool sentOnce = false;
  final NavigationController navigationController = Get.put(NavigationController());
  final DonationService _donationService = DonationService();
  final ReceiverNotificationService _receiverNotifications = Get.put(ReceiverNotificationService());
  final MessagingService _messagingService = MessagingService();
  final TermsService _termsService = TermsService();
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _displayName; // Cached display name from Firestore

  Future<void> _sendVerificationIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !(user.emailVerified) && !sentOnce) {
      sentOnce = true;
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent. Please check your inbox.')),
      );
    }
  }

  Future<void> _loadDisplayName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists && mounted) {
          final data = userDoc.data();
          final nameFromDoc = data != null 
              ? (data['displayName'] ?? data['name']) 
              : null;
          
          // Fallback: use auth displayName or email
          final fallback = user.displayName ?? user.email?.split('@')[0] ?? 'Receiver';
          
          setState(() {
            _displayName = (nameFromDoc != null && nameFromDoc.toString().isNotEmpty)
                ? nameFromDoc.toString()
                : fallback;
          });
        } else if (mounted) {
          // If Firestore doc doesn't exist, use fallback
          final user = FirebaseAuth.instance.currentUser;
          setState(() {
            _displayName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Receiver';
          });
        }
      }
    } catch (e) {
      print('Error loading display name: $e');
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        setState(() {
          _displayName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Receiver';
        });
      }
    }
  }

  Future<void> _refreshVerification() async {
    await FirebaseAuth.instance.currentUser?.reload();
    setState(() {});
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate back to role selection and remove all previous routes
      Get.offAll(() => const RoleSelect());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Delay to ensure Scaffold is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendVerificationIfNeeded();
      _checkTermsAcceptance();
      _initializeNotificationService();
      _loadDisplayName(); // Fetch display name from Firestore
    });
  }

  Future<void> _initializeNotificationService() async {
    try {
      print('🔔 Initializing receiver notification service...');
      await _receiverNotifications.initialize();
      print('✅ Receiver notification service initialized');
    } catch (e) {
      print('❌ Error initializing receiver notification service: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
          // Exit app or redirect to login
          SystemNavigator.pop();
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
              child: const EnhancedNotificationPopup(userType: 'receiver'),
            ),
          ),
        ),
      ),
    );
  }

  void _showDonationDetails(DonationModel donation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiverDonationDetailsScreen(donation: donation),
      ),
    );
  }

  Future<void> _claimDonation(DonationModel donation) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to claim donations'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check availability
      final hasQuantity = donation.totalQuantity != null && donation.totalQuantity! > 0;
      final remainingQuantity = donation.remainingQuantity ?? donation.totalQuantity ?? 0;
      
      if (hasQuantity && remainingQuantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This donation has been fully claimed'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show modern claim dialog (combines quantity selection + confirmation)
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => FoodClaimDialog(
          donation: donation,
        ),
      );

      if (result == null || result['success'] != true) {
        return; // User cancelled
      }

      final claimQuantity = result['quantity'] as int?;

      // Claim the donation
      await _donationService.claimDonation(
        donation.id,
        user.uid,
        claimQuantity: claimQuantity,
      );

      if (!mounted) return;

      // Get updated donation with chatId
      final updatedDonation = await _donationService.getDonationById(donation.id);
      if (updatedDonation == null) {
        throw Exception('Failed to get updated donation');
      }

      // Start live tracking if pickup
      if (updatedDonation.deliveryType == 'pickup') {
        try {
          final locationTrackingService = LocationTrackingService();
          await locationTrackingService.startDonationTracking(updatedDonation.id);
        } catch (e) {
          debugPrint('Error starting live tracking: $e');
        }
      }

      // Show success dialog with "Go to Messages" button
      if (!mounted) return;
      try {
        await _showClaimSuccessDialog(updatedDonation, claimQuantity);
      } catch (e) {
        debugPrint('Error showing claim success dialog: $e');
        // Still show a basic success message if dialog fails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Donation claimed successfully! Go to Messages to communicate with the donor.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('Error in _claimDonation: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error claiming donation: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showClaimSuccessDialog(DonationModel donation, int? claimQuantity) async {
    // Show popup for every new claim
    // The popup should always appear when a user successfully claims a donation
    final user = FirebaseAuth.instance.currentUser;
    final receiverId = user?.uid;
    if (receiverId == null) return;
    
    // Note: We removed the popup tracking to allow users to claim donations multiple times
    // Each new claim should show the popup, even if it's the same donation or same donor
    
    final hasQuantity = donation.totalQuantity != null && donation.totalQuantity! > 0;
    // Extract and clean unit, removing any "0" values
    String unit = '';
    if (donation.quantity != null) {
      final quantityStr = donation.quantity!.trim();
      
      // Extract text after the first number (which is the quantity)
      final match = RegExp(r'^\d+\s*(.+)$').firstMatch(quantityStr);
      if (match != null) {
        unit = match.group(1)?.trim() ?? '';
        
        // Remove any standalone "0" values from the unit
        // Split by spaces, filter out "0", then rejoin
        final parts = unit.split(RegExp(r'\s+'))
            .where((part) => part.trim().isNotEmpty && part.trim() != '0')
            .toList();
        
        unit = parts.join(' ').trim();
        
        // Additional cleanup: remove any remaining "0" patterns
        unit = unit
            .replaceAll(RegExp(r'^\s*0+\s+'), '') // Remove leading "0 "
            .replaceAll(RegExp(r'\s+0+\s+'), ' ') // Remove " 0 " in middle
            .replaceAll(RegExp(r'\s+0+\s*$'), '') // Remove trailing " 0"
            .trim();
      }
    }
    final unitText = unit.isNotEmpty ? ' $unit' : '';
    final quantityText = hasQuantity && claimQuantity != null
        ? '$claimQuantity$unitText'
        : 'all';

    // Use the UNIQUE chatId format: donorId_receiverId_donationId
    // This ensures each receiver-donor pair gets their own chat
    final donorId = donation.donorId;
    final expectedChatId = '${donorId}_${receiverId}_${donation.id}';
    
    String? chatId = expectedChatId;
    String? donorName;

    // Ensure chat exists (it should be created during claim, but verify)
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(expectedChatId)
          .get();
      
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        donorName = chatData['donorName'] as String?;
        
        // If donorName is still null, fetch from users collection (use marketName)
        if (donorName == null) {
          final donorDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(donorId)
              .get();
          if (donorDoc.exists) {
            final donorData = donorDoc.data()!;
            donorName = donorData['marketName'] ?? donorData['displayName'] ?? donorData['email']?.split('@')[0] ?? 'Donor';
          }
        }
      } else {
        // Chat doesn't exist yet, create it now
        final MessagingService messagingService = MessagingService();
        
        // Get donor market name first (use marketName instead of displayName)
        final donorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(donorId)
            .get();
        if (donorDoc.exists) {
          final donorData = donorDoc.data()!;
          donorName = donorData['marketName'] ?? donorData['displayName'] ?? donorData['email']?.split('@')[0] ?? 'Donor';
        }
        
        // Get receiver name
        final receiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(receiverId)
            .get();
        final receiverData = receiverDoc.exists ? receiverDoc.data()! : {};
        final receiverName = receiverData['displayName'] ?? receiverData['email']?.split('@')[0] ?? 'Receiver';
        
        // Create the chat
        chatId = await messagingService.createChat(
          donationId: donation.id,
          donorId: donorId,
          receiverId: receiverId,
          donorName: donorName ?? 'Donor',
          receiverName: receiverName,
        );
      }
    } catch (e) {
      debugPrint('Error getting/creating chat: $e');
      // Fallback: try to get donor market name directly
      try {
        final donorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(donorId)
            .get();
        if (donorDoc.exists) {
          final donorData = donorDoc.data()!;
          donorName = donorData['marketName'] ?? donorData['displayName'] ?? donorData['email']?.split('@')[0] ?? 'Donor';
        }
      } catch (e2) {
        debugPrint('Error getting donor name: $e2');
      }
    }

    if (!mounted) return;

    // Store the widget's context for navigation
    final widgetContext = context;

    // Show popup dialog
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
                  'You claimed $quantityText of "${donation.title}"',
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
                              'Go to messages to start communicating with ${donorName ?? 'the donor'}!',
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
                        Navigator.pop(dialogContext); // Close dialog first
                        
                        // Use a small delay to ensure dialog is fully closed
                        await Future.delayed(const Duration(milliseconds: 100));
                        
                        // Always use the expected chatId format (donorId_receiverId_donationId)
                        if (receiverId != null) {
                          final finalChatId = chatId ?? '${donorId}_${receiverId}_${donation.id}';
                          final finalDonorName = donorName ?? 'Donor';
                          
                          if (mounted) {
                            Navigator.push(
                              widgetContext,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  chatId: finalChatId,
                                  otherUserName: finalDonorName,
                                  otherUserType: 'donor',
                                ),
                              ),
                            );
                          }
                        } else {
                          // Fallback: navigate to messages tab if chat not ready
                          if (mounted) {
                            navigationController.changePage(2); // Messages tab
                          }
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


  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  ImageProvider _getImageProvider(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      // Base64 image
      final base64String = imageUrl.split(',')[1];
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    } else {
      // Network image (fallback)
      return NetworkImage(imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isUnverified = (user?.emailVerified == false);
    
    return Scaffold(
      body: PageView(
        controller: navigationController.pageController,
        onPageChanged: (index) {
          navigationController.currentIndex.value = index;
        },
        children: [
          // Home Screen
          _buildHomeScreen(user, isUnverified),
          // Map Screen
          const MapScreen(),
          // Messages Screen
          const ChatListScreen(),
          // Profile Screen
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Obx(() {
        return ResponsiveBottomNavigation(
          currentIndex: navigationController.currentIndex.value,
          onTap: (index) => navigationController.changePage(index),
          items: const [
            NavigationItem(icon: Icons.home_rounded, label: 'Home'),
            NavigationItem(icon: Icons.map_rounded, label: 'Map'),
            NavigationItem(icon: Icons.chat_rounded, label: 'Messages', showCounter: true),
            NavigationItem(icon: Icons.person_rounded, label: 'Profile'),
          ],
          unreadCount: _messagingService.unreadCount.value,
        );
      }),
    );
  }

 Widget _buildHomeScreen(User? user, bool isUnverified) {
  // Priority: widget prop -> Firestore cached _displayName -> auth displayName -> email fallback
  final displayName = widget.displayName ?? _displayName ?? user?.displayName ?? user?.email?.split('@')[0] ?? 'Receiver';

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
        'Receiver Dashboard',
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
                if (_receiverNotifications.unreadCount.value > 0)
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
                        '${_receiverNotifications.unreadCount.value}',
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
                style: const TextStyle(
                    color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search available markets and donations...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Available Donations Section
              Row(
                children: [
                  const Icon(
                    Icons.restaurant_rounded,
                    color: Color(0xFF22c55e),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Available Donations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Donations List
              Expanded(
                child: StreamBuilder<List<DonationModel>>(
                  stream: _donationService.getAvailableDonations(),
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
                          ],
                        ),
                      );
                    }

                    final allDonations = snapshot.data ?? [];

                    // Filter donations based on search query
                    final donations = _searchQuery.isEmpty
                        ? allDonations
                        : allDonations.where((donation) {
                            return donation.title.toLowerCase().contains(_searchQuery) ||
                                donation.description.toLowerCase().contains(_searchQuery) ||
                                (donation.foodType
                                        ?.toLowerCase()
                                        .contains(_searchQuery) ??
                                    false) ||
                                (donation.marketAddress
                                        ?.toLowerCase()
                                        .contains(_searchQuery) ??
                                    false) ||
                                donation.donorEmail.toLowerCase().contains(_searchQuery);
                          }).toList();

                    if (donations.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.restaurant_rounded,
                              color: Colors.grey.withOpacity(0.6),
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No results found'
                                  : 'No donations available',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try searching with different keywords'
                                  : 'Check back later for new food donations',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.withOpacity(0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: donations.length,
                      itemBuilder: (context, index) {
                        final donation = donations[index];
                        return DonationCard(
                          donation: donation,
                          isDonorView: false,
                          onTap: () => _showDonationDetails(donation),
                          onClaim: () => _claimDonation(donation),
                        );
                      },
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

  Widget _buildMobileNavigationBar() {
    return Container(
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
          padding: ResponsiveLayout.getPadding(context),
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
                icon: Icons.analytics_rounded,
                label: 'Stats',
                index: 3,
                isSelected: navigationController.currentIndex.value == 3,
              ),
              _buildNavItem(
                icon: Icons.feedback_rounded,
                label: 'Feedback',
                index: 4,
                isSelected: navigationController.currentIndex.value == 4,
              ),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                index: 5,
                isSelected: navigationController.currentIndex.value == 5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletNavigationBar() {
    return Container(
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
          padding: ResponsiveLayout.getPadding(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                isSelected: navigationController.currentIndex.value == 0,
                isTablet: true,
              ),
              _buildNavItem(
                icon: Icons.map_rounded,
                label: 'Map',
                index: 1,
                isSelected: navigationController.currentIndex.value == 1,
                isTablet: true,
              ),
              _buildNavItem(
                icon: Icons.chat_rounded,
                label: 'Messages',
                index: 2,
                isSelected: navigationController.currentIndex.value == 2,
                showCounter: true,
                isTablet: true,
              ),
              _buildNavItem(
                icon: Icons.analytics_rounded,
                label: 'Statistics',
                index: 3,
                isSelected: navigationController.currentIndex.value == 3,
                isTablet: true,
              ),
              _buildNavItem(
                icon: Icons.feedback_rounded,
                label: 'Feedback',
                index: 4,
                isSelected: navigationController.currentIndex.value == 4,
                isTablet: true,
              ),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                index: 5,
                isSelected: navigationController.currentIndex.value == 5,
                isTablet: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopNavigationBar() {
    return Container(
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
          padding: ResponsiveLayout.getPadding(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                isSelected: navigationController.currentIndex.value == 0,
                isDesktop: true,
              ),
              const SizedBox(width: 24),
              _buildNavItem(
                icon: Icons.map_rounded,
                label: 'Map',
                index: 1,
                isSelected: navigationController.currentIndex.value == 1,
                isDesktop: true,
              ),
              const SizedBox(width: 24),
              _buildNavItem(
                icon: Icons.chat_rounded,
                label: 'Messages',
                index: 2,
                isSelected: navigationController.currentIndex.value == 2,
                showCounter: true,
                isDesktop: true,
              ),
              const SizedBox(width: 24),
              _buildNavItem(
                icon: Icons.analytics_rounded,
                label: 'Statistics',
                index: 3,
                isSelected: navigationController.currentIndex.value == 3,
                isDesktop: true,
              ),
              const SizedBox(width: 24),
              _buildNavItem(
                icon: Icons.feedback_rounded,
                label: 'Feedback',
                index: 4,
                isSelected: navigationController.currentIndex.value == 4,
                isDesktop: true,
              ),
              const SizedBox(width: 24),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                index: 5,
                isSelected: navigationController.currentIndex.value == 5,
                isDesktop: true,
              ),
            ],
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
    bool isTablet = false,
    bool isDesktop = false,
  }) {
    return GestureDetector(
      onTap: () => navigationController.changePage(index),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 20 : (isTablet ? 16 : 12),
          vertical: isDesktop ? 12 : (isTablet ? 10 : 8),
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF22c55e).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(ResponsiveLayout.getBorderRadius(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF22c55e) : Colors.black54,
                  size: ResponsiveLayout.getIconSize(context),
                ),
                if (showCounter)
                  StreamBuilder<int>(
                    stream: _messagingService.getReceiverUnreadMessageCount(FirebaseAuth.instance.currentUser?.uid ?? ''),
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
            SizedBox(height: ResponsiveLayout.getSpacing(context) / 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF22c55e) : Colors.black54,
                fontSize: isDesktop ? 14 : (isTablet ? 12 : 10),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: accent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black54, size: 18),
          ],
        ),
      ),
    );
  }
}

class _VerifyBanner extends StatelessWidget {
  final Future<void> Function() onResend;
  final Future<void> Function() onRefresh;

  const _VerifyBanner({required this.onResend, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8C00).withOpacity(0.1),
        border: Border.all(color: const Color(0xFFFF8C00).withOpacity(0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFFFF8C00)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Please verify your email to unlock all features.',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          TextButton(
            onPressed: onResend, 
            child: const Text('Resend', style: TextStyle(color: Color(0xFFFF8C00)))
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFF8C00))),
            child: const Text('Refresh', style: TextStyle(color: Color(0xFFFF8C00))),
          ),
        ],
      ),
    );
  }
}