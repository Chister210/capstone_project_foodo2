import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class TermsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Current terms version
  static const String currentTermsVersion = '1.0';
  
  // Check if user needs to accept terms
  Future<bool> needsTermsAcceptance() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!doc.exists) {
        // New user - needs to accept terms
        return true;
      }
      
      final userData = UserModel.fromFirestore(doc);
      
      // Check if terms are accepted and up to date
      if (!userData.termsAccepted || userData.termsVersion != currentTermsVersion) {
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error checking terms acceptance: $e');
      return true; // Show terms by default if error
    }
  }
  
  // Accept terms and conditions
  Future<void> acceptTerms() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      final now = DateTime.now();
      
      // Check if user document exists
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        // Update existing user
        await _firestore.collection('users').doc(user.uid).update({
          'termsAccepted': true,
          'termsAcceptedAt': Timestamp.fromDate(now),
          'termsVersion': currentTermsVersion,
          'updatedAt': Timestamp.fromDate(now),
        });
      } else {
        // Create new user document
        final userModel = UserModel(
          id: user.uid,
          email: user.email ?? '',
          userType: user.email?.contains('donor') == true ? 'donor' : 'receiver',
          displayName: user.displayName ?? user.email?.split('@')[0] ?? 'User',
          photoUrl: user.photoURL,
          createdAt: now,
          updatedAt: now,
          termsAccepted: true,
          termsAcceptedAt: now,
          termsVersion: currentTermsVersion,
          isActive: true,
        );
        
        await _firestore.collection('users').doc(user.uid).set(userModel.toFirestore());
      }
    } catch (e) {
      throw Exception('Failed to accept terms: $e');
    }
  }
  
  // Get user data
  Future<UserModel?> getUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
  
  // Get terms and conditions content
  Map<String, String> getTermsContent() {
    return {
      'title': 'Terms and Conditions',
      'lastUpdated': 'December 2024',
      'version': currentTermsVersion,
      'content': '''
FOODO TERMS AND CONDITIONS

Welcome to Foodo, a food donation platform connecting food donors with food receivers in Davao City. By using our service, you agree to the following terms and conditions.

1. SERVICE DESCRIPTION
Foodo facilitates the donation and distribution of surplus food between donors (markets, restaurants, individuals) and receivers (charitable organizations, individuals in need) within Davao City.

2. USER RESPONSIBILITIES

FOR FOOD DONORS:
- Ensure all donated food is safe for consumption
- Provide accurate descriptions of donated items
- Maintain proper food handling and storage
- Comply with food safety guidelines
- Be available for pickup during specified times
- Provide accurate market location information

FOR FOOD RECEIVERS:
- Use donated food responsibly and safely
- Follow food safety guidelines when handling received items
- Respect donor's time and location preferences
- Provide accurate contact information
- Use the platform for legitimate food needs only

3. FOOD SAFETY AND LIABILITY
- All users must follow proper food safety practices
- Foodo is not responsible for the quality or safety of donated food
- Users assume full responsibility for food handling and consumption
- Report any food safety concerns immediately

4. LOCATION AND PRIVACY
- Location sharing is optional but recommended for better service
- All location data is used solely for food donation purposes
- Users can stop location tracking at any time
- Personal information is protected according to our Privacy Policy

5. PROHIBITED ACTIVITIES
- Selling donated food for profit
- Misrepresenting food items or quantities
- Harassment or inappropriate behavior
- Violation of local food safety regulations
- Use of the platform for non-food related activities

6. ACCOUNT SUSPENSION
Foodo reserves the right to suspend or terminate accounts that violate these terms or engage in prohibited activities.

7. MODIFICATIONS
These terms may be updated periodically. Users will be notified of significant changes and may need to re-accept updated terms.

8. CONTACT INFORMATION
For questions or concerns about these terms, please contact us through the app or at support@foodo.com.

By accepting these terms, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.
      ''',
    };
  }
}
