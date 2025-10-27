import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:capstone_project/FoodReceiver/login_receiver.dart';
import 'package:capstone_project/role_select.dart'; // Import the role selection page
import 'package:capstone_project/models/beneficiary_type.dart';
import 'package:capstone_project/services/email_validation_service.dart';

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
  bool isConfirmPasswordVisible = false;
  String? selectedBeneficiaryType;
  final EmailValidationService _emailValidator = EmailValidationService();

  // Password validation function
  bool _isPasswordValid(String password) {
    // Check if password has at least 8 characters
    if (password.length < 8) return false;
    
    // Check if password has at least 1 uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    
    // Check if password has at least 1 special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    
    return true;
  }

  String? _getPasswordValidationMessage(String password) {
    if (password.isEmpty) return null;
    
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least 1 uppercase letter';
    }
    
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least 1 special character';
    }
    
    return null;
  }

  Future<void> signUp() async {
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        nameController.text.isEmpty ||
        addressController.text.isEmpty ||
        phoneController.text.isEmpty ||
        selectedBeneficiaryType == null) {
      _showErrorDialog('Please enter all fields and select beneficiary type');
      return;
    }

    // Removed the external email-suggestion/validation check so verification email is sent directly.
    // Keep password validation and matching checks.
    final passwordValidationMessage = _getPasswordValidationMessage(passwordController.text);
    if (passwordValidationMessage != null) {
      _showErrorDialog(passwordValidationMessage);
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showErrorDialog('Passwords do not match');
      return;
    }

    setState(() => isLoading = true);
    try {
      print('DEBUG: Attempting signup with email=${emailController.text.trim()}');
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      print('DEBUG: createUserWithEmailAndPassword succeeded: uid=${cred.user?.uid}');

      // Send email verification immediately
      await cred.user?.sendEmailVerification();

      // Set auth display name to provided full name
      await cred.user?.updateDisplayName(nameController.text.trim());

      // Get beneficiary type details
      final beneficiaryType = BeneficiaryType.getById(selectedBeneficiaryType!);

      // Create user document in users collection with enhanced data
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'email': cred.user!.email ?? '',
        'name': nameController.text.trim(),
        'userType': 'receiver',
        'displayName': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'beneficiaryType': selectedBeneficiaryType,
        'beneficiaryTypeName': beneficiaryType?.name ?? 'Individual',
        'points': 0,
        'isActive': true,
        'isOnline': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'termsAccepted': false,
        'emailVerified': false,
      });

      _showEmailVerificationDialog(cred.user!);
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException ${e.code} - ${e.message}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Signup failed: ${e.message ?? e.code}')));
      _showErrorDialog(e.message ?? 'Signup failed. Please try again.');
    } catch (e) {
      print('DEBUG: Signup error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Signup error: $e')));
      _showErrorDialog('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showEmailVerificationDialog(User user) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must take action
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
                  'assets/lottie_files/email_verification.json', // You can use a different Lottie file for email
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'We have sent a verification link to your email address:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  user.email ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please check your inbox and click the verification link to activate your account.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Get.offAll(() => const RoleSelect());
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: const BorderSide(color: Colors.grey),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _checkEmailVerification(user);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8C00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'I\'ve Verified',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    try {
                      await user.sendEmailVerification();
                      _showResendSuccessDialog();
                    } catch (e) {
                      _showErrorDialog('Failed to resend verification email. Please try again.');
                    }
                  },
                  child: const Text(
                    'Resend Verification Email',
                    style: TextStyle(
                      color: Color(0xFFFF8C00),
                      fontSize: 14,
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

  void _showResendSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Email Sent'),
          content: const Text('Verification email has been resent successfully. Please check your inbox.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkEmailVerification(User user) async {
    setState(() => isLoading = true);
    
    try {
      // Reload user to get latest email verification status
      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;
      
      if (updatedUser != null && updatedUser.emailVerified) {
        // Update Firestore with verified status
        await FirebaseFirestore.instance.collection('users').doc(updatedUser.uid).update({
          'emailVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        _showSuccessDialog();
      } else {
        _showVerificationRequiredDialog(user);
      }
    } catch (e) {
      _showErrorDialog('Failed to check verification status. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showVerificationRequiredDialog(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Email Not Verified'),
          content: const Text('Your email address has not been verified yet. Please check your inbox and click the verification link before continuing.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showEmailVerificationDialog(user);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
                  'Email Verified Successfully!',
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

  Widget _buildBeneficiaryTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Beneficiary Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedBeneficiaryType,
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Select your beneficiary type',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              items: BeneficiaryType.types.map((type) {
                return DropdownMenuItem<String>(
                  value: type.id,
                  child: Row(
                    children: [
                      Text(type.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              type.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              type.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? value) {
                setState(() {
                  selectedBeneficiaryType = value;
                });
              },
            ),
          ),
        ),
      ],
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
                                _buildBeneficiaryTypeSelector(),
                                const SizedBox(height: 16),
                                _Tf(controller: emailController, hint: 'Email address', icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress),
                                const SizedBox(height: 16),
                                _PasswordField(
                                  controller: passwordController,
                                  hint: 'Password',
                                  isPasswordVisible: isPasswordVisible,
                                  onVisibilityChanged: () => setState(() => isPasswordVisible = !isPasswordVisible),
                                  validator: _getPasswordValidationMessage,
                                ),
                                const SizedBox(height: 16),
                                _Tf(
                                  controller: confirmPasswordController,
                                  hint: 'Confirm password',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: !isConfirmPasswordVisible,
                                  trailing: IconButton(
                                    icon: Icon(isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Colors.black54),
                                    onPressed: () => setState(() => isConfirmPasswordVisible = !isConfirmPasswordVisible),
                                  ),
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

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool isPasswordVisible;
  final VoidCallback onVisibilityChanged;
  final String? Function(String) validator;

  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.isPasswordVisible,
    required this.onVisibilityChanged,
    required this.validator,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  String? _validationMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          obscureText: !widget.isPasswordVisible,
          style: const TextStyle(color: Colors.black),
          onChanged: (value) {
            setState(() {
              _validationMessage = widget.validator(value);
            });
          },
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: Colors.black54),
            prefixIcon: const Icon(Icons.lock_rounded, color: Colors.black54),
            suffixIcon: IconButton(
              icon: Icon(widget.isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Colors.black54),
              onPressed: widget.onVisibilityChanged,
            ),
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
            errorText: _validationMessage,
            errorStyle: const TextStyle(fontSize: 12),
          ),
        ),
        if (_validationMessage == null && widget.controller.text.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4.0, left: 12.0),
            child: Text(
              '✓ Password meets security requirements',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 4.0, left: 12.0),
          child: Text(
            'Password must contain: 8+ characters, 1 uppercase letter, 1 special character',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}