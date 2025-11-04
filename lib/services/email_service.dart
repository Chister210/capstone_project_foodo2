import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for sending emails (certificates, notifications, etc.)
/// This service can work with Firebase Cloud Functions or a custom email API
class EmailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // You can set this to your Cloud Functions URL or email API endpoint
  // For production, set this in your config file
  static const String _emailFunctionUrl = 'https://YOUR-PROJECT.cloudfunctions.net/sendCertificateEmail';
  static const bool _useCloudFunctions = false; // Set to true if using Cloud Functions

  /// Send certificate email to donor
  Future<void> sendCertificateEmail({
    required String recipientEmail,
    required String recipientName,
    required String certificateName,
    required String certificateDescription,
    required String certificateLevel,
    required int pointsAwarded,
  }) async {
    try {
      if (_useCloudFunctions) {
        // Use Firebase Cloud Functions
        await _sendViaCloudFunction(
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          certificateName: certificateName,
          certificateDescription: certificateDescription,
          certificateLevel: certificateLevel,
          pointsAwarded: pointsAwarded,
        );
      } else {
        // Store in Firestore for processing by Cloud Functions trigger
        // This is the recommended approach as it's more reliable
        await _queueEmailForSending(
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          certificateName: certificateName,
          certificateDescription: certificateDescription,
          certificateLevel: certificateLevel,
          pointsAwarded: pointsAwarded,
        );
      }
      
      print('✅ Certificate email queued for $recipientEmail');
    } catch (e) {
      print('❌ Error sending certificate email: $e');
      // Don't throw - email failures shouldn't break the flow
    }
  }

  /// Queue email in Firestore (recommended - use with Cloud Functions trigger)
  Future<void> _queueEmailForSending({
    required String recipientEmail,
    required String recipientName,
    required String certificateName,
    required String certificateDescription,
    required String certificateLevel,
    required int pointsAwarded,
  }) async {
    await _firestore.collection('email_queue').add({
      'type': 'certificate',
      'recipientEmail': recipientEmail,
      'recipientName': recipientName,
      'subject': '🎉 Congratulations! You\'ve Earned a Certificate',
      'template': 'certificate',
      'data': {
        'certificateName': certificateName,
        'certificateDescription': certificateDescription,
        'certificateLevel': certificateLevel,
        'pointsAwarded': pointsAwarded,
        'date': DateTime.now().toIso8601String(),
      },
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'attempts': 0,
      'maxAttempts': 3,
    });
  }

  /// Send via Cloud Functions HTTP endpoint (alternative method)
  Future<void> _sendViaCloudFunction({
    required String recipientEmail,
    required String recipientName,
    required String certificateName,
    required String certificateDescription,
    required String certificateLevel,
    required int pointsAwarded,
  }) async {
    final response = await http.post(
      Uri.parse(_emailFunctionUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'recipientEmail': recipientEmail,
        'recipientName': recipientName,
        'certificateName': certificateName,
        'certificateDescription': certificateDescription,
        'certificateLevel': certificateLevel,
        'pointsAwarded': pointsAwarded,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send email: ${response.statusCode}');
    }
  }

  /// Generate certificate HTML content
  String generateCertificateHTML({
    required String recipientName,
    required String certificateName,
    required String certificateDescription,
    required String certificateLevel,
    required int pointsAwarded,
    required String date,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body {
      font-family: 'Arial', sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
      background-color: #f5f5f5;
    }
    .certificate {
      background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
      border-radius: 20px;
      padding: 40px;
      text-align: center;
      color: white;
      box-shadow: 0 10px 30px rgba(0,0,0,0.2);
    }
    .certificate h1 {
      font-size: 32px;
      margin: 20px 0;
      text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
    }
    .certificate h2 {
      font-size: 24px;
      margin: 20px 0;
      font-weight: normal;
    }
    .certificate .name {
      font-size: 28px;
      font-weight: bold;
      margin: 30px 0;
      border-bottom: 3px solid white;
      padding-bottom: 20px;
      display: inline-block;
    }
    .certificate .description {
      font-size: 18px;
      margin: 30px 0;
      opacity: 0.95;
    }
    .certificate .points {
      font-size: 20px;
      margin-top: 30px;
      padding-top: 20px;
      border-top: 2px solid rgba(255,255,255,0.3);
    }
    .footer {
      text-align: center;
      margin-top: 30px;
      color: #666;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="certificate">
    <h1>🎉 Certificate of Achievement</h1>
    <h2>$certificateName</h2>
    <div class="name">$recipientName</div>
    <div class="description">$certificateDescription</div>
    <div class="points">
      <strong>Total Points: $pointsAwarded</strong><br>
      <small>Awarded on ${date.split('T')[0]}</small>
    </div>
  </div>
  <div class="footer">
    <p>Thank you for your contributions to reducing food waste and helping your community!</p>
    <p>Foodo Team</p>
  </div>
</body>
</html>
''';
  }
}

