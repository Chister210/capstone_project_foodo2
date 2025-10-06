import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:capstone_project/MarketDonor/login_donor.dart';
import 'package:capstone_project/role_select.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

class DonorSignup extends StatefulWidget {
  const DonorSignup({super.key});

  @override
  State<DonorSignup> createState() => _DonorSignupState();
}

class _DonorSignupState extends State<DonorSignup> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController marketNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;
  bool isPasswordVisible = false;
  
  // Location variables
  LatLng? selectedLocation;
  String? selectedAddress;

  Future<void> signUp() async {
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        nameController.text.isEmpty ||
        marketNameController.text.isEmpty ||
        addressController.text.isEmpty ||
        phoneController.text.isEmpty ||
        selectedLocation == null) {
      _showErrorDialog('Please enter all fields and select your market location');
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      _showErrorDialog('Passwords do not match');
      return;
    }
    setState(() => isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      await cred.user?.updateDisplayName('donor');
      
      // Create user document in users collection with enhanced data
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'email': cred.user!.email ?? '',
        'name': nameController.text.trim(),
        'userType': 'donor',
        'displayName': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'marketName': marketNameController.text.trim(),
        'marketAddress': selectedAddress ?? addressController.text.trim(),
        'marketLocation': GeoPoint(selectedLocation!.latitude, selectedLocation!.longitude),
        'points': 0,
        'isActive': true,
        'isOnline': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'termsAccepted': false,
      });
      
      _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(e.message ?? 'Signup failed. Please try again.');
    } catch (e) {
      _showErrorDialog('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/lottie_files/success.json',
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sign Up Successful!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Get.off(() => const DonorLogin());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22c55e),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Sign In Now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Future<void> _showMapPicker() async {
    // Request location permission
    final permission = await Permission.location.request();
    if (permission != PermissionStatus.granted) {
      _showErrorDialog('Location permission is required to select your market location');
      return;
    }

    // Get current location with robust error handling
    try {
      final position = await Geolocator.getCurrentPosition();
      final currentLocation = LatLng(position.latitude, position.longitude);

      showDialog(
        context: context,
        builder: (context) => MapPickerDialog(
          initialLocation: selectedLocation ?? currentLocation,
          onLocationSelected: (location, address) {
            setState(() {
              selectedLocation = location;
              selectedAddress = address;
            });
          },
        ),
      );
    } on PermissionDeniedException catch (_) {
      _showErrorDialog('Location permission denied. Please enable it in app settings.');
    } on LocationServiceDisabledException catch (_) {
      _showErrorDialog('Location services are disabled. Please enable GPS/location services.');
    } on Exception catch (e) {
      _showErrorDialog('Unable to get current location. Please enable location services and try again.\nError: \\${e.toString()}');
    }
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Unsuccessful Lottie Animation
                Lottie.asset(
                  'assets/lottie_files/unsuccess.json',
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                
                // Unsuccessful title
                const Text(
                  'Sign Up Unsuccessful',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Error message
                Text(
                  errorMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // OK button to close dialog (same as Receiver Signup)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFFef4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('OK'),
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
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Color(0xFFF1F5F9),
              Color(0xFFE0F7FA),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        // Fixed back button navigation
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.black54),
                              onPressed: () {
                                Get.offAll(() => const RoleSelect());
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text('Market Donor', style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Create account', style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold)),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Start donating surplus food', style: TextStyle(color: Colors.black54)),
                        ),
                        const SizedBox(height: 32),
                        
                        Expanded(
                          child: Container(),
                        ),
                        
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 25,
                                offset: const Offset(0, -5),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Tf(controller: nameController, hint: 'Full name', icon: Icons.person),
                                const SizedBox(height: 16),
                                _Tf(controller: marketNameController, hint: 'Market name', icon: Icons.storefront),
                                const SizedBox(height: 16),
                                _Tf(controller: addressController, hint: 'Address', icon: Icons.home),
                                const SizedBox(height: 16),
                                // Map picker button
                                InkWell(
                                  onTap: _showMapPicker,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on, color: Colors.black54),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            selectedLocation != null 
                                                ? 'Location selected: ${selectedAddress ?? '${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)}'}'
                                                : 'Tap to select market location on map',
                                            style: TextStyle(
                                              color: selectedLocation != null ? Colors.black : Colors.black54,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.map, color: Colors.black54),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _Tf(controller: phoneController, hint: 'Phone number', icon: Icons.phone, keyboardType: TextInputType.phone),
                                const SizedBox(height: 16),
                                _Tf(controller: emailController, hint: 'Email address', icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress),
                                const SizedBox(height: 16),
                                _Tf(
                                  controller: passwordController,
                                  hint: 'Password',
                                  icon: Icons.lock_rounded,
                                  obscure: !isPasswordVisible,
                                  trailing: IconButton(
                                    icon: Icon(isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Colors.black54),
                                    onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _Tf(
                                  controller: confirmPasswordController,
                                  hint: 'Confirm password',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: !isPasswordVisible,
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : signUp,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      backgroundColor: const Color(0xFF22c55e),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Create account'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class MapPickerDialog extends StatefulWidget {
  final LatLng initialLocation;
  final Function(LatLng location, String address) onLocationSelected;

  const MapPickerDialog({
    super.key,
    required this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  late GoogleMapController mapController;
  LatLng? selectedLocation;
  String? selectedAddress;

  @override
  void initState() {
    super.initState();
    selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF22c55e),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Select Market Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Map
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.initialLocation,
                  zoom: 15,
                ),
                onMapCreated: (GoogleMapController controller) {
                  mapController = controller;
                },
                onTap: (LatLng location) {
                  setState(() {
                    selectedLocation = location;
                  });
                },
                markers: selectedLocation != null
                    ? {
                       gmaps.Marker(
  markerId: const gmaps.MarkerId('selected_location'),
  position: selectedLocation!,
  infoWindow: const gmaps.InfoWindow(
    title: 'Selected Location',
    snippet: 'Tap to confirm this location',
  ),
),
                      }
                    : {},
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              ),
            ),
            // Bottom buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selectedLocation != null
                          ? () {
                              // Get address from coordinates (simplified)
                              final address = '${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)}';
                              widget.onLocationSelected(selectedLocation!, address);
                              Navigator.of(context).pop();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22c55e),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Confirm Location'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tf extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? trailing;

  const _Tf({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icon, color: Colors.black54),
        suffixIcon: trailing,
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3b82f6)),
        ),
      ),
    );
  }
}