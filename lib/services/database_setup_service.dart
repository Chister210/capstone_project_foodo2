import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/firebase_config.dart';

class DatabaseSetupService {
  static final FirebaseFirestore _firestore = FirebaseConfig.firestore;
  static final FirebaseAuth _auth = FirebaseConfig.auth;

  // Initialize database with sample data
  static Future<void> initializeDatabase() async {
    try {
      // Create indexes (these will be created automatically when queries are made)
      await _createIndexes();
      
      // Create sample data for testing
      await _createSampleData();
      
      print('Database initialized successfully');
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }

  // Create required indexes
  static Future<void> _createIndexes() async {
    // These indexes will be created automatically when the first query is made
    // But we can trigger them by making sample queries
    
    // Index for: status + createdAt (for available donations)
    await _firestore
        .collection('donations')
        .where('status', isEqualTo: 'available')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    // Index for: donorId + createdAt (for donor's donations)
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('donations')
          .where('donorId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
    }
  }

  // Create sample data for testing
  static Future<void> _createSampleData() async {
    final now = Timestamp.now();
    final tomorrow = Timestamp.fromDate(DateTime.now().add(const Duration(days: 1)));

    // Sample donations
    final sampleDonations = [
      {
        'donorId': 'sample-donor-1',
        'donorEmail': 'donor1@example.com',
        'title': 'Fresh Vegetables',
        'description': 'Organic vegetables from local farm. Includes tomatoes, lettuce, and cucumbers.',
        'imageUrl': 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400',
        'pickupTime': tomorrow,
        'deliveryType': 'pickup',
        'status': 'available',
        'createdAt': now,
        'updatedAt': now,
        'address': '123 Main St, City, State',
      },
      {
        'donorId': 'sample-donor-2',
        'donorEmail': 'donor2@example.com',
        'title': 'Bread & Pastries',
        'description': 'Fresh bread and pastries from local bakery. Still warm and delicious.',
        'imageUrl': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400',
        'pickupTime': tomorrow,
        'deliveryType': 'delivery',
        'status': 'available',
        'createdAt': now,
        'updatedAt': now,
        'address': '456 Oak Ave, City, State',
      },
      {
        'donorId': 'sample-donor-3',
        'donorEmail': 'donor3@example.com',
        'title': 'Canned Goods',
        'description': 'Various canned goods including beans, vegetables, and soups.',
        'imageUrl': 'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400',
        'pickupTime': tomorrow,
        'deliveryType': 'pickup',
        'status': 'claimed',
        'claimedBy': 'sample-receiver-1',
        'createdAt': now,
        'updatedAt': now,
        'address': '789 Pine Rd, City, State',
      },
    ];

    // Add sample donations
    for (final donation in sampleDonations) {
      await _firestore.collection('donations').add(donation);
    }

    // Sample user profiles
    final sampleUsers = [
      {
        'email': 'donor1@example.com',
        'displayName': 'John Donor',
        'role': 'donor',
        'createdAt': now,
        'lastActive': now,
        'phoneNumber': '+1234567890',
      },
      {
        'email': 'receiver1@example.com',
        'displayName': 'Jane Receiver',
        'role': 'receiver',
        'createdAt': now,
        'lastActive': now,
        'phoneNumber': '+1234567891',
      },
    ];

    // Add sample users
    for (int i = 0; i < sampleUsers.length; i++) {
      await _firestore
          .collection('users')
          .doc('sample-user-${i + 1}')
          .set(sampleUsers[i]);
    }
  }

  // Clear all data (for testing)
  static Future<void> clearAllData() async {
    try {
      // Delete all donations
      final donationsSnapshot = await _firestore.collection('donations').get();
      for (final doc in donationsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete all users
      final usersSnapshot = await _firestore.collection('users').get();
      for (final doc in usersSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete all notifications
      final notificationsSnapshot = await _firestore.collection('notifications').get();
      for (final doc in notificationsSnapshot.docs) {
        await doc.reference.delete();
      }

      print('All data cleared successfully');
    } catch (e) {
      print('Error clearing data: $e');
      rethrow;
    }
  }

  // Check database health
  static Future<Map<String, dynamic>> getDatabaseHealth() async {
    try {
      final donationsCount = await _firestore.collection('donations').get().then((snapshot) => snapshot.docs.length);
      final usersCount = await _firestore.collection('users').get().then((snapshot) => snapshot.docs.length);
      final notificationsCount = await _firestore.collection('notifications').get().then((snapshot) => snapshot.docs.length);

      return {
        'status': 'healthy',
        'donations': donationsCount,
        'users': usersCount,
        'notifications': notificationsCount,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Create user profile
  static Future<void> createUserProfile({
    required String userId,
    required String email,
    required String role,
    String? displayName,
    String? phoneNumber,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'email': email,
      'displayName': displayName ?? email.split('@')[0],
      'role': role,
      'createdAt': Timestamp.now(),
      'lastActive': Timestamp.now(),
      'phoneNumber': phoneNumber,
    });
  }

  // Update user last active
  static Future<void> updateUserLastActive(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'lastActive': Timestamp.now(),
    });
  }
}
