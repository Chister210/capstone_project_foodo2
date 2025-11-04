import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../models/user_model.dart';
import '../services/image_compression_service.dart';
// import '../services/feedback_service.dart'; // Removed - feedback service deleted
// import '../widgets/feedback_display.dart'; // Removed - feedback display deleted
import 'donation_history_screen.dart';
import 'edit_profile_screen.dart';
import '../role_select.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  UserModel? _user;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final raw = userDoc.exists ? (userDoc.data() as Map<String,dynamic>) : <String,dynamic>{};
      print('DEBUG userDoc raw: $raw');
      print('DEBUG auth user.displayName: ${user.displayName}, email: ${user.email}');

      // Force display name from Firestore (check common name fields)
      final candidate = (raw['displayName'] ??
              raw['name'] ??
              raw['fullName'] ??
              raw['firstName'] ??
              raw['marketName'] ??
              raw['username']);
      // ignore obvious role values that were accidentally stored in name
      final badRoles = {'donor', 'receiver', 'market', 'admin', 'user'};
      final docName = (candidate != null && !badRoles.contains(candidate.toString().toLowerCase()))
          ? candidate
          : null;
      // guaranteed non-null trimmed string (fallback to auth email prefix)
      final displayName =
          (docName != null && docName.toString().trim().isNotEmpty)
              ? docName.toString().trim()
              : (user.displayName ?? user.email?.split('@')[0] ?? 'User');

      // Update user document with resolved display name (if different)
      if (displayName != user.displayName) {
        await user.updateProfile(displayName: displayName);
        // Refresh user data
        await _loadUserData();
        return;
      }

      // still keep the UserModel for other fields but don't rely on it for the displayed name
      setState(() {
        _user = UserModel.fromFirestore(userDoc);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Error',
        'Failed to load user data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        await _updateProfilePicture(image);
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        await _updateProfilePicture(image);
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to take picture: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _updateProfilePicture(XFile imageFile) async {
    setState(() => _isUpdating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Compress and convert image to base64
      final imageUrl = await ImageCompressionService().compressAndEncodeImage(
        File(imageFile.path),
        maxWidth: 300,
        maxHeight: 300,
        quality: 85,
      );

      // Update user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'photoUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local user model
      setState(() {
        _user = _user?.copyWith(photoUrl: imageUrl);
      });

      Get.snackbar(
        'Success',
        'Profile picture updated successfully!',
        backgroundColor: const Color(0xFF22c55e),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update profile picture: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Get.offAll(const RoleSelect());
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to sign out: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(user: _user!),
      ),
    );
    if (result == true) {
      // Reload user data after editing
      _loadUserData();
    }
  }

  Widget _buildProfilePicture() {
    if (_user?.photoUrl != null && _user!.photoUrl!.isNotEmpty) {
      try {
        final uri = Uri.tryParse(_user!.photoUrl!);
        Uint8List? bytes;
        if (uri != null && uri.data != null) {
          bytes = uri.data!.contentAsBytes();
        } else {
          // Try to decode as base64 if not a data URI
          bytes = base64Decode(_user!.photoUrl!);
        }
        // Validate bytes are not empty and are a valid image
        if (bytes.isNotEmpty) {
          return CircleAvatar(
            radius: 60,
            backgroundImage: MemoryImage(bytes),
          );
        } else {
          throw Exception('Invalid image bytes');
        }
      } catch (e) {
        // Fallback to default avatar on any error
        return const CircleAvatar(
          radius: 60,
          backgroundColor: Color(0xFF22c55e),
          child: Icon(Icons.person, size: 60, color: Colors.white),
        );
      }
    }
    return const CircleAvatar(
      radius: 60,
      backgroundColor: Color(0xFF22c55e),
      child: Icon(Icons.person, size: 60, color: Colors.white),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, {bool isEditable = true}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEditable ? _navigateToEditProfile : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22c55e).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF22c55e), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isEditable)
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeneficiaryTypeCard() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.id)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final beneficiaryType = data?['beneficiaryTypeName'] ?? data?['beneficiaryType'] ?? 'Not set';
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _navigateToEditProfile,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22c55e).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.category, color: Color(0xFF22c55e), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Beneficiary Type',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            beneficiaryType.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF22c55e).withOpacity(0.1),
            const Color(0xFF16a34a).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF22c55e).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22c55e),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return const Scaffold(
        body: Center(
          child: Text('User data not found'),
        ),
      );
    }

    // Prefer user model displayName, then auth displayName, then email prefix
    final displayName = _user?.displayName
        ?? FirebaseAuth.instance.currentUser?.displayName
        ?? FirebaseAuth.instance.currentUser?.email?.split('@')[0]
        ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
                  colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            child: Column(
              children: [
                  Stack(
                    children: [
                      _buildProfilePicture(),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                    color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: _isUpdating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.camera_alt, color: Color(0xFF22c55e)),
                            onPressed: _isUpdating ? null : _showImagePickerDialog,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _navigateToEditProfile,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit, color: Colors.white70, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                      Text(
                    _user!.userType == 'donor' ? 'Market Donor' : 'Food Receiver',
                        style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                        ),
                      ),
                  if (_user!.userType == 'donor') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${_user!.points} Points',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                   ],
                 ),
               ),

            // User information
            const SizedBox(height: 16),
            _buildInfoCard('Email', _user!.email, Icons.email),
            if (_user!.phone != null && _user!.phone!.isNotEmpty)
              _buildInfoCard('Phone', _user!.phone!, Icons.phone)
            else
              _buildInfoCard('Phone', 'Not set', Icons.phone),
            if (_user!.address != null && _user!.address!.isNotEmpty)
              _buildInfoCard('Address', _user!.address!, Icons.location_on)
            else
              _buildInfoCard('Address', 'Not set', Icons.location_on),
            
            // Donor specific information
            if (_user!.userType == 'donor') ...[
              if (_user!.marketName != null && _user!.marketName!.isNotEmpty)
                _buildInfoCard('Market Name', _user!.marketName!, Icons.storefront)
              else
                _buildInfoCard('Market Name', 'Not set', Icons.storefront),
              if (_user!.marketAddress != null && _user!.marketAddress!.isNotEmpty)
                _buildInfoCard('Market Address', _user!.marketAddress!, Icons.business)
              else
                _buildInfoCard('Market Address', 'Not set', Icons.business),
            ],
            
            // Receiver specific information
            if (_user!.userType == 'receiver') ...[
              _buildBeneficiaryTypeCard(),
            ],

            // Account information
            const SizedBox(height: 16),
            _buildInfoCard(
              'Member Since',
              '${_user!.createdAt.day}/${_user!.createdAt.month}/${_user!.createdAt.year}',
              Icons.calendar_today,
              isEditable: false,
            ),
            _buildInfoCard(
              'Account Status',
              _user!.isActive ? 'Active' : 'Inactive',
              Icons.check_circle,
              isEditable: false,
            ),

            // Donor specific actions
            if (_user!.userType == 'donor') ...[
              const SizedBox(height: 16),
              _buildActionCard(
                title: 'My Donations',
                subtitle: 'View and manage your donations',
                icon: Icons.fastfood,
                onTap: () => Get.to(() => const DonationHistoryScreen()),
              ),
              
              // Feedback Section for Donors
              const SizedBox(height: 16),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpansionTile(
                  leading: const Icon(Icons.rate_review, color: Color(0xFF22c55e)),
                  title: const Text('Feedback & Ratings'),
                  subtitle: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(_user!.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Text('Loading...');
                      }
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      final avgRating = data?['averageOverallRating'] ?? 0.0;
                      final feedbackCount = data?['totalFeedbackCount'] ?? 0;
                      
                      if (feedbackCount == 0) {
                        return const Text('No feedback yet');
                      }
                      
                      return Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${avgRating.toStringAsFixed(1)}/5.0',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text('($feedbackCount reviews)'),
                        ],
                      );
                    },
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.feedback_outlined, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Feedback feature has been removed',
                                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Update Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePickerOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _takePicture();
                  },
                ),
                _buildImagePickerOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: const Color(0xFF22c55e)),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}