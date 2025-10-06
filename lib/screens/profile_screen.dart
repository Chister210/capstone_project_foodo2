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
import 'donation_history_screen.dart';
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

      if (userDoc.exists) {
        setState(() {
          _user = UserModel.fromFirestore(userDoc);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
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

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF22c55e)),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF22c55e)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
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
                  Text(
                    _user!.displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                          color: Colors.white,
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
              _buildInfoCard('Phone', _user!.phone!, Icons.phone),
            if (_user!.address != null && _user!.address!.isNotEmpty)
              _buildInfoCard('Address', _user!.address!, Icons.location_on),
            
            // Donor specific information
            if (_user!.userType == 'donor') ...[
              if (_user!.marketName != null && _user!.marketName!.isNotEmpty)
                _buildInfoCard('Market Name', _user!.marketName!, Icons.storefront),
              if (_user!.marketAddress != null && _user!.marketAddress!.isNotEmpty)
                _buildInfoCard('Market Address', _user!.marketAddress!, Icons.business),
            ],

            // Account information
            const SizedBox(height: 16),
            _buildInfoCard(
              'Member Since',
              '${_user!.createdAt.day}/${_user!.createdAt.month}/${_user!.createdAt.year}',
              Icons.calendar_today,
            ),
            _buildInfoCard(
              'Account Status',
              _user!.isActive ? 'Active' : 'Inactive',
              Icons.check_circle,
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