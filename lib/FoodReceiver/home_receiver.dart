import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:capstone_project/role_select.dart';
import 'package:capstone_project/controllers/navigation_controller.dart';
import 'package:capstone_project/screens/map_screen.dart';
import 'package:capstone_project/screens/profile_screen.dart';
import 'package:capstone_project/screens/chat_list_screen.dart';
import 'package:capstone_project/widgets/enhanced_notification_popup.dart';
import 'package:capstone_project/widgets/donation_card.dart';
import 'package:capstone_project/services/donation_service.dart';
import 'package:capstone_project/services/notification_service.dart';
import 'package:capstone_project/services/terms_service.dart';
import 'package:capstone_project/services/location_tracking_service.dart';
import 'package:capstone_project/models/donation_model.dart';
import 'package:capstone_project/widgets/terms_and_conditions_popup.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart'; // Add this import for SystemNavigator

class ReceiverHome extends StatefulWidget {
  const ReceiverHome({super.key});

  @override
  State<ReceiverHome> createState() => _ReceiverHomeState();
}

class _ReceiverHomeState extends State<ReceiverHome> {
  bool sentOnce = false;
  final NavigationController navigationController = Get.put(NavigationController());
  final DonationService _donationService = DonationService();
  final NotificationService _notificationService = Get.put(NotificationService());
  final TermsService _termsService = TermsService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    });
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(donation.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: _getImageProvider(donation.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
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
              Row(
                children: [
                  Icon(
                    donation.deliveryType == 'pickup' 
                        ? Icons.location_on_rounded 
                        : Icons.delivery_dining_rounded,
                    color: const Color(0xFF22c55e),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Type: ${donation.deliveryType == 'pickup' ? 'Pickup' : 'Delivery'}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: Color(0xFF22c55e),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pickup: ${_formatDateTime(donation.pickupTime)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF22c55e),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Donor: ${donation.donorEmail.split('@')[0]}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (donation.status == 'available')
            ElevatedButton(
              onPressed: () => _claimDonation(donation),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22c55e),
                foregroundColor: Colors.white,
              ),
              child: const Text('Claim Donation'),
            ),
        ],
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

      // Show claim confirmation dialog
      final confirmed = await _showClaimConfirmationDialog(donation);
      if (!confirmed) return;

      await _donationService.claimDonation(donation.id, user.uid);

      if (!mounted) return;

      // Only pop if a dialog is open (i.e., if this is called from a dialog)
      // Use ModalRoute to check if we're inside a dialog route
      final isDialog = ModalRoute.of(context)?.settings.name == null;
      if (isDialog && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      // Start live tracking if pickup
      if (donation.deliveryType == 'pickup') {
        try {
          final locationTrackingService = LocationTrackingService();
          await locationTrackingService.startDonationTracking(donation.id);
        } catch (e) {
          debugPrint('Error starting live tracking: $e');
        }
      }
      _showClaimSuccessDialog(donation);
    } catch (e, stack) {
      debugPrint('Error in _claimDonation: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error claiming donation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  // (No longer needed, direct import used)
  throw UnimplementedError();
  }

  Future<bool> _showClaimConfirmationDialog(DonationModel donation) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Claim Donation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to claim "${donation.title}"?'),
              const SizedBox(height: 16),
              if (donation.deliveryType == 'pickup')
                const Text(
                  'This is a pickup donation. You will need to go to the market to collect the food.',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                )
              else
                const Text(
                  'This is a delivery donation. Please wait for the donor to deliver the food to you.',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22c55e),
                foregroundColor: Colors.white,
              ),
              child: const Text('Claim'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showClaimSuccessDialog(DonationModel donation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Donation Claimed!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text('You have successfully claimed "${donation.title}"'),
              const SizedBox(height: 16),
              if (donation.deliveryType == 'pickup')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.location_on, color: Colors.orange),
                      SizedBox(height: 8),
                      Text(
                        'Go to Market',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      Text(
                        'Please go to the market to collect your food donation.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.delivery_dining, color: Colors.blue),
                      SizedBox(height: 8),
                      Text(
                        'Wait for Delivery',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      Text(
                        'Please wait for the donor to deliver the food to you.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'You can now chat with the donor to coordinate the pickup/delivery.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to messages tab
                navigationController.changePage(2);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22c55e),
                foregroundColor: Colors.white,
              ),
              child: const Text('View Messages'),
            ),
          ],
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

  Widget _buildHomeScreen(User? user, bool isUnverified) {
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
              if (_notificationService.receiverNotificationCount > 0)
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
                      '${_notificationService.receiverNotificationCount}',
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
                if (isUnverified)
                  _VerifyBanner(onResend: _sendVerificationIfNeeded, onRefresh: _refreshVerification),
                Text(
                  'Hello, ${user?.email ?? 'Receiver'}',
                  style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                     (donation.foodType?.toLowerCase().contains(_searchQuery) ?? false) ||
                                     (donation.marketAddress?.toLowerCase().contains(_searchQuery) ?? false) ||
                                     donation.donorEmail.toLowerCase().contains(_searchQuery);
                            }).toList();
                      
                      if (donations.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isNotEmpty ? Icons.search_off : Icons.restaurant_rounded,
                                color: Colors.grey.withOpacity(0.6),
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ? 'No results found' : 'No donations available',
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

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
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
            Icon(
              icon,
              color: isSelected ? const Color(0xFF22c55e) : Colors.black54,
              size: 24,
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