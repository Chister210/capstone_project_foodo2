import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_model.dart';
import '../models/beneficiary_type.dart';
import '../utils/responsive_layout.dart';
import '../theme/app_theme.dart';


class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Donor specific controllers
  final _marketNameController = TextEditingController();
  final _marketAddressController = TextEditingController();
  
  // Receiver specific
  String? _selectedBeneficiaryType;

  // Fallback/local beneficiary options (safe: avoids relying on BeneficiaryType.values)
  // Replace with dynamic source if you have one (Firestore or model helper).
  final List<Map<String, String>> _beneficiaryOptions = const [
    {'id': 'individual', 'name': 'Individual'},
    {'id': 'family', 'name': 'Family'},
    {'id': 'organization', 'name': 'Organization'},
  ];
  
  // Donor location
  LatLng? _marketLocation;
  String? _marketLocationAddress;
  bool _isLoadingLocation = false;
  
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    _nameController.text = widget.user.displayName;
    _phoneController.text = widget.user.phone ?? '';
    _addressController.text = widget.user.address ?? '';
    _emailController.text = widget.user.email;
    
    if (widget.user.userType == 'donor') {
      _marketNameController.text = widget.user.marketName ?? '';
      _marketAddressController.text = widget.user.marketAddress ?? '';
      if (widget.user.marketLocation != null) {
        _marketLocation = LatLng(
          widget.user.marketLocation!.latitude,
          widget.user.marketLocation!.longitude,
        );
        _marketLocationAddress = widget.user.marketAddress;
      }
    }
    
    // Load beneficiary type for receiver
    if (widget.user.userType == 'receiver') {
      _loadBeneficiaryType();
    }
  }

  Future<void> _loadBeneficiaryType() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _selectedBeneficiaryType = data?['beneficiaryType'];
        });
      }
    } catch (e) {
      print('Error loading beneficiary type: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Get.snackbar('Error', 'User not found', backgroundColor: Colors.red);
        return;
      }

      final displayNameToSave = _nameController.text.trim();
      
      final updateData = <String, dynamic>{
        'displayName': displayNameToSave,
        'name': displayNameToSave, // Also update name field
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update Firebase Auth display name
      try {
        await user.updateDisplayName(displayNameToSave);
        await user.reload(); // Reload to get updated profile
      } catch (e) {
        print('Warning: Could not update Firebase Auth displayName: $e');
        // Continue with Firestore update even if Auth update fails
      }

      // Receiver specific updates
      if (widget.user.userType == 'receiver') {
        if (_selectedBeneficiaryType != null) {
          final beneficiaryType = BeneficiaryType.getById(_selectedBeneficiaryType!);
          updateData['beneficiaryType'] = _selectedBeneficiaryType;
          updateData['beneficiaryTypeName'] = beneficiaryType?.name ?? 'Individual';
        }
      }

      // Donor specific updates
      if (widget.user.userType == 'donor') {
        updateData['marketName'] = _marketNameController.text.trim().isEmpty 
            ? null 
            : _marketNameController.text.trim();
        updateData['marketAddress'] = _marketAddressController.text.trim().isEmpty 
            ? null 
            : _marketAddressController.text.trim();
        
        if (_marketLocation != null) {
          updateData['marketLocation'] = GeoPoint(
            _marketLocation!.latitude,
            _marketLocation!.longitude,
          );
        }
      }

      // Note: Email changes in Firebase Auth require re-authentication
      // For now, we'll update the email in Firestore but not in Firebase Auth
      // Users should re-authenticate via Firebase Console or settings to change Auth email
      if (_emailController.text.trim() != widget.user.email) {
        updateData['email'] = _emailController.text.trim();
        Get.snackbar(
          'Info',
          'Email updated in profile. To change your login email, please contact support or use account settings.',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      Get.snackbar(
        'Success',
        'Profile updated successfully!',
        backgroundColor: AppTheme.donorGreen,
        colorText: Colors.white,
      );

      // Reload and return
      Navigator.of(context).pop(true);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update profile: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _selectMarketLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Request location permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar(
          'Error',
          'Location services are disabled. Please enable them.',
          backgroundColor: Colors.red,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar(
            'Error',
            'Location permissions are denied.',
            backgroundColor: Colors.red,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          'Error',
          'Location permissions are permanently denied. Please enable in settings.',
          backgroundColor: Colors.red,
        );
        return;
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Use current location for now
      setState(() {
        _marketLocation = LatLng(position.latitude, position.longitude);
        _marketLocationAddress = _marketAddressController.text.trim().isEmpty 
            ? '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}'
            : _marketAddressController.text.trim();
      });
      
      Get.snackbar(
        'Success',
        'Location set to your current position. You can update the address manually.',
        backgroundColor: AppTheme.donorGreen,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to get location: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDonor = widget.user.userType == 'donor';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: isDonor ? AppTheme.donorGreen : AppTheme.receiverOrange,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: ResponsiveLayout.getPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              // Basic Information Section
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 12),
              
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!GetUtils.isEmail(value.trim())) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (value.trim().length < 10) {
                      return 'Please enter a valid phone number';
                    }
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _addressController,
                label: 'Address',
                icon: Icons.location_on,
                maxLines: 2,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (value.trim().length < 5) {
                      return 'Please enter a complete address';
                    }
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Receiver Specific Section
              if (widget.user.userType == 'receiver') ...[
                _buildSectionHeader('Receiver Information'),
                const SizedBox(height: 12),
                _buildBeneficiaryTypeDropdown(),
                const SizedBox(height: 24),
              ],
              
              // Donor Specific Section
              if (widget.user.userType == 'donor') ...[
                _buildSectionHeader('Market Information'),
                const SizedBox(height: 12),
                
                _buildTextField(
                  controller: _marketNameController,
                  label: 'Market Name',
                  icon: Icons.storefront,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your market name';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _marketAddressController,
                  label: 'Market Address',
                  icon: Icons.business,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your market address';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Market Location Picker
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.map, color: AppTheme.donorGreen),
                          const SizedBox(width: 8),
                          Text(
                            'Market Location',
                            style: TextStyle(
                              fontSize: ResponsiveLayout.getBodyFontSize(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_marketLocation != null)
                        Text(
                          'Location: ${_marketLocation!.latitude.toStringAsFixed(6)}, ${_marketLocation!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: ResponsiveLayout.getBodyFontSize(context) - 2,
                            color: Colors.grey[600],
                          ),
                        )
                      else
                        Text(
                          'No location selected',
                          style: TextStyle(
                            fontSize: ResponsiveLayout.getBodyFontSize(context) - 2,
                            color: Colors.grey[600],
                          ),
                        ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoadingLocation ? null : _selectMarketLocation,
                        icon: _isLoadingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.location_on),
                        label: Text(_isLoadingLocation ? 'Loading...' : 'Select Location on Map'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.donorGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDonor ? AppTheme.donorGreen : AppTheme.receiverOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDonor = widget.user.userType == 'donor';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: isDonor ? AppTheme.donorGreen : AppTheme.receiverOrange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: ResponsiveLayout.getSubtitleFontSize(context),
              fontWeight: FontWeight.bold,
              color: isDonor ? AppTheme.donorGreen : AppTheme.receiverOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDonor = widget.user.userType == 'donor';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: isDonor ? AppTheme.donorGreen : AppTheme.receiverOrange),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDonor ? AppTheme.donorGreen : AppTheme.receiverOrange,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildBeneficiaryTypeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedBeneficiaryType,
      decoration: InputDecoration(
        labelText: 'Beneficiary Type',
        prefixIcon: const Icon(Icons.category),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      // Use the local _beneficiaryOptions list to build dropdown items
      items: _beneficiaryOptions.map((type) {
        return DropdownMenuItem(
          value: type['id'],
          child: Text(type['name'] ?? type['id'] ?? ''),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedBeneficiaryType = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a beneficiary type';
        }
        return null;
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _marketNameController.dispose();
    _marketAddressController.dispose();
    super.dispose();
  }
}

