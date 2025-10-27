import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get user name from Firestore
  Future<String> getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 'Unknown User';

      final userData = userDoc.data()!;
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
      return {
        'id': userId,
        'name': userData['name'] as String? ?? 
                userData['displayName'] as String? ?? 
                userData['email']?.split('@')[0] ?? 
                'Unknown User',
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
      return {
        'id': userId,
        'name': userData['name'] as String? ?? 
                userData['displayName'] as String? ?? 
                userData['email']?.split('@')[0] ?? 
                'Unknown User',
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
