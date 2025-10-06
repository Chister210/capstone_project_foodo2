import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:capstone_project/FoodReceiver/login_receiver.dart';
import 'package:capstone_project/role_select.dart'; // Import the role selection page

class ReceiverSignup extends StatefulWidget {
  const ReceiverSignup({super.key});

  @override
  State<ReceiverSignup> createState() => _ReceiverSignupState();
}

class _ReceiverSignupState extends State<ReceiverSignup> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;
  bool isPasswordVisible = false;

  Future<void> signUp() async {
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        nameController.text.isEmpty ||
        addressController.text.isEmpty ||
        phoneController.text.isEmpty) {
      _showErrorDialog('Please enter all fields');
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
      await cred.user?.updateDisplayName('receiver');
      // Create user document in users collection with enhanced data
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'email': cred.user!.email ?? '',
        'name': nameController.text.trim(),
        'userType': 'receiver',
        'displayName': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
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
                      Get.off(() => const ReceiverLogin());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C00),
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
                
                // OK button to close dialog (same as Receiver Login)
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
                            const Text('Food Receiver', style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Create account', style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold)),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Connect with nearby donors', style: TextStyle(color: Colors.black54)),
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
                                _Tf(controller: addressController, hint: 'Address', icon: Icons.home),
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
                                      backgroundColor: const Color(0xFFFF8C00),
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