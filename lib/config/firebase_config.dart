import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseConfig {
  static FirebaseFirestore? _firestore;
  static FirebaseAuth? _auth;

  // Initialize Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    
    // Configure Firestore settings
    _firestore?.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Get Firestore instance
  static FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw Exception('Firebase not initialized. Call FirebaseConfig.initialize() first.');
    }
    return _firestore!;
  }


  // Get Auth instance
  static FirebaseAuth get auth {
    if (_auth == null) {
      throw Exception('Firebase not initialized. Call FirebaseConfig.initialize() first.');
    }
    return _auth!;
  }

  // Collection references
  static CollectionReference get donationsCollection => 
      firestore.collection('donations');
  
  static CollectionReference get usersCollection => 
      firestore.collection('users');
  
  static CollectionReference get notificationsCollection => 
      firestore.collection('notifications');


  // Helper methods for common operations
  static Future<void> createUserProfile(String userId, Map<String, dynamic> userData) async {
    await usersCollection.doc(userId).set(userData);
  }

  static Future<void> updateUserProfile(String userId, Map<String, dynamic> userData) async {
    await usersCollection.doc(userId).update(userData);
  }

  static Future<DocumentSnapshot> getUserProfile(String userId) async {
    return await usersCollection.doc(userId).get();
  }

  // Database health check
  static Future<bool> isDatabaseHealthy() async {
    try {
      await firestore.collection('donations').limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Clear cache (useful for testing)
  static Future<void> clearCache() async {
    await firestore.clearPersistence();
  }
}
