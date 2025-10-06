import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:capstone_project/MarketDonor/signup_donor.dart';
import 'package:capstone_project/forgot.dart';
import 'package:capstone_project/MarketDonor/home_donor.dart';
import 'package:capstone_project/role_select.dart';
import 'package:capstone_project/MarketDonor/onboarding_donor.dart'; // Import the OnboardingDonor class

class DonorLogin extends StatefulWidget {
  const DonorLogin({super.key});

  @override
  State<DonorLogin> createState() => _DonorLoginState();
}

class _DonorLoginState extends State<DonorLogin> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool isPasswordVisible = false;
  bool _showSuccessDialog = true;

  Future<void> signIn() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      Get.snackbar('Missing info', 'Please enter email and password');
      return;
    }
    setState(() => isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      
      // Check if user is already registered as a receiver
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final userType = userData['userType'] ?? userData['displayName'];
        
        if (userType == 'receiver') {
          await FirebaseAuth.instance.signOut();
          _showLoginUnsuccessfulDialog('This account is registered as a Food Receiver. Please use the Food Receiver login instead.');
          return;
        }
      }
      
      // Set user as donor
      await cred.user?.updateDisplayName('donor');
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'email': cred.user!.email,
        'displayName': 'donor',
        'userType': 'donor',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Show success dialog before navigating
      if (_showSuccessDialog) {
        _showSuccessDialog = false;
        _showLoginSuccessDialog();
      } else {
        Get.offAll(() => OnboardingDonor()); // Navigate to OnboardingDonor instead of DonorHome
      }
    } on FirebaseAuthException catch (e) {
      // Show unsuccessful login dialog for wrong credentials or non-existing account
      _showLoginUnsuccessfulDialog(e.message ?? 'Login failed. Please try again.');
    } catch (e) {
      _showLoginUnsuccessfulDialog('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showLoginSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Automatically navigate after animation completes
        Future.delayed(const Duration(milliseconds: 2000), () {
          Navigator.of(context).pop();
          Get.offAll(() => OnboardingDonor()); // Navigate to OnboardingDonor instead of DonorHome
        });

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lottie Animation
                Lottie.asset(
                  'assets/lottie_files/success.json',
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                
                // Success title only
                const Text(
                  'Log In Successful!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLoginUnsuccessfulDialog(String errorMessage) {
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
                
                // Error title
                const Text(
                  'Log In Unsuccessful',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                // Error message
                Text(
                  errorMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // OK button to close dialog
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
                          child: Text('Sign in', style: TextStyle(color: Colors.black, fontSize: 34, fontWeight: FontWeight.bold)),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Access your donor dashboard', style: TextStyle(color: Colors.black54)),
                        ),
                        const SizedBox(height: 32),
                        
                        // Lottie Animation in the center
                        Expanded(
                          child: Center(
                            child: Lottie.asset(
                              'assets/lottie_files/signIn_animation.json',
                              height: 250,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        
                        // Login box at the bottom
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TextField(
                                controller: emailController,
                                hint: 'Email address',
                                icon: Icons.email_rounded,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              _TextField(
                                controller: passwordController,
                                hint: 'Password',
                                icon: Icons.lock_rounded,
                                obscure: !isPasswordVisible,
                                trailing: IconButton(
                                  icon: Icon(isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Colors.black54),
                                  onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Get.to(const Forgot()),
                                  child: const Text('Forgot password?', style: TextStyle(color: Colors.blue)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : signIn,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    backgroundColor: const Color(0xFF22c55e),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Sign in'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Don't have an account? ", style: TextStyle(color: Colors.black54)),
                                  TextButton(
                                    onPressed: () => Get.to(const DonorSignup()),
                                    child: const Text('Create account', style: TextStyle(color: Colors.blue)),
                                  )
                                ],
                              )
                            ],
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

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? trailing;

  const _TextField({
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