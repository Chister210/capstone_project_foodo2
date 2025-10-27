import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'app_notification.dart';

class DonorNotificationService extends GetxController {
  final RxInt unreadCount = 0.obs;
  final RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  StreamSubscription? _sub;
  String? _currentUserId;

  static final DonorNotificationService _instance = DonorNotificationService._internal();
  factory DonorNotificationService() => _instance;
  DonorNotificationService._internal();

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  Future<void> initialize() async {
    print('🔔 DonorNotificationService: Initializing...');
    
    try {
      const AndroidInitializationSettings initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const InitializationSettings init = InitializationSettings(android: initAndroid, iOS: initIOS);
      await _local.initialize(init);
      
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'donor_channel',
          'Donor Notifications',
          description: 'Notifications for donors',
          importance: Importance.high,
        );
        await _local
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }
      
      // Listen to auth state changes
      _auth.authStateChanges().listen((user) {
        if (user != null && user.uid != _currentUserId) {
          print('🔔 Donor: User changed to ${user.uid}');
          _currentUserId = user.uid;
          _listen();
        } else if (user == null) {
          print('🔔 Donor: User logged out');
          _currentUserId = null;
          _sub?.cancel();
          notifications.clear();
          unreadCount.value = 0;
        }
      });
      
      // Start listening if user is already logged in
      if (_auth.currentUser != null) {
        _currentUserId = _auth.currentUser!.uid;
        _listen();
      }
    } catch (e) {
      print('❌ DonorNotificationService initialization error: $e');
    }
  }

  void _listen() {
    final user = _auth.currentUser;
    if (user == null) {
      print('🔔 Donor: No user logged in, cannot listen');
      return;
    }

    print('🔔 Donor: Starting to listen for user ${user.uid}');
    _sub?.cancel();
    
    _sub = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snap) {
        print('🔔 Donor: Received ${snap.docs.length} notifications');
        final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        notifications.assignAll(list);
        unreadCount.value = list.where((n) => n['isRead'] != true).length;

        if (list.isNotEmpty) {
          final latest = list.first;
          if (latest['isRead'] != true) {
            print('🔔 Donor: Showing local notification: ${latest['title']}');
            _showLocal(latest['title'] ?? 'New Notification', latest['message'] ?? '');
          }
        }
      },
      onError: (error) {
        print('❌ Donor notification stream error: $error');
      },
    );
  }

  Future<void> _showLocal(String title, String body) async {
    try {
      const android = AndroidNotificationDetails(
        'donor_channel',
        'Donor Notifications',
        channelDescription: 'Notifications for donors',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const ios = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      const details = NotificationDetails(android: android, iOS: ios);
      await _local.show(DateTime.now().millisecondsSinceEpoch.remainder(100000), title, body, details);
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }

  // Public API: send(AppNotification)
  Future<void> send(AppNotification notification) async {
    await AppNotification.send(notification);
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final qs = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();
      
      final batch = _firestore.batch();
      for (final d in qs.docs) {
        batch.update(d.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
    }
  }
}


