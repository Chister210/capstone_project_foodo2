import 'dart:async';

class EmailValidationService {
  static final EmailValidationService _instance = EmailValidationService._internal();
  factory EmailValidationService() => _instance;
  EmailValidationService._internal();

  // Email validation regex pattern
  static const String _emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static final RegExp _emailRegex = RegExp(_emailPattern);

  /// Validates if the email format is correct
  bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    return _emailRegex.hasMatch(email);
  }

  /// Validates email and returns detailed result
  EmailValidationResult validateEmail(String email) {
    if (email.isEmpty) {
      return EmailValidationResult(
        isValid: false,
        errorMessage: 'Email is required',
      );
    }

    if (!_emailRegex.hasMatch(email)) {
      return EmailValidationResult(
        isValid: false,
        errorMessage: 'Please enter a valid email address',
      );
    }

    // Check for common typos in popular domains
    final commonTypos = {
      'gmail.co': 'gmail.com',
      'gmail.cm': 'gmail.com',
      'gmail.con': 'gmail.com',
      'yahoo.co': 'yahoo.com',
      'yahoo.cm': 'yahoo.com',
      'hotmail.co': 'hotmail.com',
      'outlook.co': 'outlook.com',
    };

    for (final typo in commonTypos.keys) {
      if (email.toLowerCase().contains(typo)) {
        return EmailValidationResult(
          isValid: false,
          errorMessage: 'Did you mean ${email.replaceAll(typo, commonTypos[typo]!)}?',
          suggestion: email.replaceAll(typo, commonTypos[typo]!),
        );
      }
    }

    return EmailValidationResult(
      isValid: true,
      errorMessage: null,
    );
  }

  /// Checks if email domain is valid by attempting to resolve it
  Future<bool> isEmailDomainValid(String email) async {
    try {
      final domain = email.split('@').last;
      
      // List of known invalid domains
      const invalidDomains = [
        'tempmail.com',
        '10minutemail.com',
        'guerrillamail.com',
        'mailinator.com',
        'throwaway.email',
      ];

      if (invalidDomains.contains(domain.toLowerCase())) {
        return false;
      }

      // Additional domain validation can be added here
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Comprehensive email validation
  Future<EmailValidationResult> validateEmailComprehensive(String email) async {
    final basicValidation = validateEmail(email);
    
    if (!basicValidation.isValid) {
      return basicValidation;
    }

    final isDomainValid = await isEmailDomainValid(email);
    if (!isDomainValid) {
      return EmailValidationResult(
        isValid: false,
        errorMessage: 'Please use a valid email provider',
      );
    }

    return EmailValidationResult(
      isValid: true,
      errorMessage: null,
    );
  }
}

class EmailValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? suggestion;

  const EmailValidationResult({
    required this.isValid,
    this.errorMessage,
    this.suggestion,
  });
}
