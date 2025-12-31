import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get user name from Firestore (for donors, use marketName instead of displayName)
  Future<String> getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 'Unknown User';

      final userData = userDoc.data()!;
      final userType = userData['userType'] as String?;
      
      // For donors, prefer marketName over displayName
      if (userType == 'donor') {
        return userData['marketName'] as String? ?? 
               userData['name'] as String? ?? 
               userData['displayName'] as String? ?? 
               userData['email']?.split('@')[0] ?? 
               'Unknown User';
      }
      
      // For receivers, use displayName
      return userData['name'] as String? ?? 
             userData['displayName'] as String? ?? 
             userData['email']?.split('@')[0] ?? 
             'Unknown User';
    } catch (e) {
      print('Error getting user name: $e');
      return 'Unknown User';
    }
  }

  /// Get current user name
  Future<String> getCurrentUserName() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 'Unknown User';
    return getUserName(currentUser.uid);
  }

  /// Get user data including name
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      final userType = userData['userType'] as String?;
      
      // For donors, prefer marketName over displayName
      String name;
      if (userType == 'donor') {
        name = userData['marketName'] as String? ?? 
               userData['name'] as String? ?? 
               userData['displayName'] as String? ?? 
               userData['email']?.split('@')[0] ?? 
               'Unknown User';
      } else {
        name = userData['name'] as String? ?? 
               userData['displayName'] as String? ?? 
               userData['email']?.split('@')[0] ?? 
               'Unknown User';
      }
      
      return {
        'id': userId,
        'name': name,
        'email': userData['email'] as String? ?? '',
        'userType': userData['userType'] as String? ?? '',
        'phone': userData['phone'] as String? ?? '',
        'address': userData['address'] as String? ?? '',
        'isActive': userData['isActive'] as bool? ?? false,
        'createdAt': userData['createdAt'] as Timestamp?,
      };
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Stream user data for real-time updates
  Stream<Map<String, dynamic>?> getUserDataStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;

      final userData = snapshot.data()!;
      final userType = userData['userType'] as String?;
      
      // For donors, prefer marketName over displayName
      String name;
      if (userType == 'donor') {
        name = userData['marketName'] as String? ?? 
               userData['name'] as String? ?? 
               userData['displayName'] as String? ?? 
               userData['email']?.split('@')[0] ?? 
               'Unknown User';
      } else {
        name = userData['name'] as String? ?? 
               userData['displayName'] as String? ?? 
               userData['email']?.split('@')[0] ?? 
               'Unknown User';
      }
      
      return {
        'id': userId,
        'name': name,
        'email': userData['email'] as String? ?? '',
        'userType': userData['userType'] as String? ?? '',
        'phone': userData['phone'] as String? ?? '',
        'address': userData['address'] as String? ?? '',
        'isActive': userData['isActive'] as bool? ?? false,
        'createdAt': userData['createdAt'] as Timestamp?,
      };
    });
  }

  /// Update user name in Firestore
  Future<bool> updateUserName(String userId, String newName) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'name': newName,
        'displayName': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating user name: $e');
      return false;
    }
  }
}
