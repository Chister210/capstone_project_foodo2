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
import 'package:capstone_project/services/donation_service.dart';
import 'package:capstone_project/services/notification_service.dart';
import 'package:capstone_project/services/terms_service.dart';
import 'package:capstone_project/models/donation_model.dart';
import 'package:capstone_project/widgets/terms_and_conditions_popup.dart';
import 'package:flutter/services.dart'; // Add this import for SystemNavigator

class DonorHome extends StatefulWidget {
  const DonorHome({super.key});

  @override
  State<DonorHome> createState() => _DonorHomeState();
}

class _DonorHomeState extends State<DonorHome> {
  final NavigationController navigationController = Get.put(NavigationController());
  final DonationService _donationService = DonationService();
  final NotificationService _notificationService = Get.put(NotificationService());
  final TermsService _termsService = TermsService();

  @override
  void initState() {
    super.initState();
    // Delay to ensure Scaffold is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTermsAcceptance();
      // NotificationService is automatically initialized via Get.put()
      // No need to call any method manually
    });
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      body: PageView(
        controller: navigationController.pageController,
        onPageChanged: (index) {
          navigationController.currentIndex.value = index;
        },
        children: [
          // Home Screen
          _buildHomeScreen(user),
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

  Widget _buildHomeScreen(User? user) {
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
              if (_notificationService.donorNotificationCount.value > 0)
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
                      '${_notificationService.donorNotificationCount.value}',
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
                  'Hello, ${user?.email ?? 'Donor'}',
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