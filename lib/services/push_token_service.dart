import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushTokenService {
  PushTokenService._();
  static final PushTokenService _instance = PushTokenService._();
  factory PushTokenService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _initialized = false;
  String? _currentUserId;
  String? _currentToken;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    print('🔔 PushTokenService: Initializing...');

    try {
      // Request permissions (especially iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      print('🔔 Push permissions granted: ${settings.authorizationStatus}');

      // Save current token (if logged in)
      await _saveCurrentUserToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((token) async {
        print('🔔 Token refreshed: ${token.substring(0, 20)}...');
        await _updateToken(token);
      });

      // React to auth state changes
      _auth.authStateChanges().listen((user) async {
        if (user != null && user.uid != _currentUserId) {
          print('🔔 User changed: ${user.uid}');
          _currentUserId = user.uid;
          await _saveCurrentUserToken();
        } else if (user == null) {
          print('🔔 User logged out');
          _currentUserId = null;
          _currentToken = null;
        }
      });
    } catch (e) {
      print('❌ PushTokenService initialization error: $e');
    }
  }

  Future<void> _saveCurrentUserToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('🔔 No user logged in, skipping token save');
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        print('🔔 No FCM token available');
        return;
      }

      if (token == _currentToken) {
        print('🔔 Token unchanged, skipping update');
        return;
      }

      print('🔔 Saving FCM token for user: ${user.uid}');
      await _updateToken(token);
    } catch (e) {
      print('❌ Error saving current user token: $e');
    }
  }

  Future<void> _updateToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('🔔 No user logged in, cannot update token');
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'platform': Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _currentToken = token;
      print('✅ FCM token updated for user: ${user.uid}');
    } catch (e) {
      print('❌ Error updating FCM token: $e');
    }
  }

  // Force refresh token (useful for debugging)
  Future<void> forceRefreshToken() async {
    await _saveCurrentUserToken();
  }
}


