import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ErrorHandlingService {
  static final ErrorHandlingService _instance = ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  // Show error snackbar
  void showError(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: const Icon(Icons.error, color: Colors.white),
    );
  }

  // Show success snackbar
  void showSuccess(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }

  // Show warning snackbar
  void showWarning(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: const Icon(Icons.warning, color: Colors.white),
    );
  }

  // Show info snackbar
  void showInfo(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      icon: const Icon(Icons.info, color: Colors.white),
    );
  }

  // Handle Firebase errors
  void handleFirebaseError(dynamic error) {
    String message = 'An unexpected error occurred';
    
    if (error.toString().contains('permission-denied')) {
      message = 'Permission denied. Please check your account permissions.';
    } else if (error.toString().contains('network-request-failed')) {
      message = 'Network error. Please check your internet connection.';
    } else if (error.toString().contains('user-not-found')) {
      message = 'User not found. Please try logging in again.';
    } else if (error.toString().contains('wrong-password')) {
      message = 'Incorrect password. Please try again.';
    } else if (error.toString().contains('email-already-in-use')) {
      message = 'Email is already registered. Please use a different email.';
    } else if (error.toString().contains('weak-password')) {
      message = 'Password is too weak. Please choose a stronger password.';
    } else if (error.toString().contains('invalid-email')) {
      message = 'Invalid email address. Please check your email format.';
    } else if (error.toString().contains('too-many-requests')) {
      message = 'Too many requests. Please try again later.';
    }
    
    showError('Error', message);
  }

  // Handle location errors
  void handleLocationError(dynamic error) {
    String message = 'Location error occurred';
    
    if (error.toString().contains('permission')) {
      message = 'Location permission denied. Please enable location access in settings.';
    } else if (error.toString().contains('service')) {
      message = 'Location services are disabled. Please enable location services.';
    } else if (error.toString().contains('timeout')) {
      message = 'Location request timed out. Please try again.';
    }
    
    showError('Location Error', message);
  }

  // Handle image errors
  void handleImageError(dynamic error) {
    String message = 'Image error occurred';
    
    if (error.toString().contains('permission')) {
      message = 'Camera/Storage permission denied. Please enable permissions.';
    } else if (error.toString().contains('size')) {
      message = 'Image file is too large. Please choose a smaller image.';
    } else if (error.toString().contains('format')) {
      message = 'Unsupported image format. Please choose a valid image.';
    }
    
    showError('Image Error', message);
  }

  // Show loading dialog
  void showLoading(String message) {
    Get.dialog(
      AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  // Hide loading dialog
  void hideLoading() {
    if (Get.isDialogOpen == true) {
      Get.back();
    }
  }

  // Show confirmation dialog
  Future<bool> showConfirmation({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    return await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: Text(confirmText),
          ),
        ],
      ),
    ) ?? false;
  }

  // Log error for debugging
  void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    print('ERROR in $context: $error');
    if (stackTrace != null) {
      print('Stack trace: $stackTrace');
    }
  }
}
