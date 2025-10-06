import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_project/services/background_notification_service.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'dart:async';

class NotificationService extends GetxController {
  // Reactive notification lists for GetX
  final RxList<Map<String, dynamic>> _donorNotifications = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> _receiverNotifications = <Map<String, dynamic>>[].obs;
  final RxInt _donorNotificationCount = 0.obs;
  final RxInt _receiverNotificationCount = 0.obs;

  RxList<Map<String, dynamic>> get donorNotifications => _donorNotifications;
  RxList<Map<String, dynamic>> get receiverNotifications => _receiverNotifications;
  RxInt get donorNotificationCount => _donorNotificationCount;
  RxInt get receiverNotificationCount => _receiverNotificationCount;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _fcmToken;
  StreamSubscription? _donorSubscription;
  StreamSubscription? _receiverSubscription;

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  @override
  void onClose() {
    _donorSubscription?.cancel();
    _receiverSubscription?.cancel();
    super.onClose();
  }

  // Initialize notification service
  Future<void> initialize() async {
    try {
      // Request permission for iOS
      if (Platform.isIOS) {
        await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }

      // Request permission for Android
      if (Platform.isAndroid) {
        await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      print('FCM Token: $_fcmToken');

      // Save token to user document
      await _saveFCMToken();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _saveFCMToken();
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle initial message (when app is opened from notification)
      final RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Start listening to user notifications
      _listenToUserNotifications();

    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  // Listen to user notifications based on user type
  void _listenToUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Listen for donor notifications
    _donorSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('userType', isEqualTo: 'donor')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final notifications = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      _donorNotifications.assignAll(notifications);
      _donorNotificationCount.value = notifications.where((n) => n['isRead'] != true).length;
    });

    // Listen for receiver notifications
    _receiverSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('userType', isEqualTo: 'receiver')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final notifications = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      _receiverNotifications.assignAll(notifications);
      _receiverNotificationCount.value = notifications.where((n) => n['isRead'] != true).length;
    });
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }
  }

  // Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'food_donation_channel',
      'Food Donation Notifications',
      description: 'Notifications for food donation app',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Save FCM token to user document
  Future<void> _saveFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null && _fcmToken != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': _fcmToken,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.notification?.title}');
    
    // Show local notification
    await _showLocalNotification(
      title: message.notification?.title ?? 'New Message',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  // Handle notification taps
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('Notification tapped: ${message.data}');
    // Handle navigation based on notification data
    _navigateFromNotification(message.data);
  }

  // Handle local notification taps
  void _onNotificationTap(NotificationResponse response) {
    print('Local notification tapped: ${response.payload}');
    // Handle navigation based on payload
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'food_donation_channel',
      'Food Donation Notifications',
      channelDescription: 'Notifications for food donation app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Send notification to specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String userType,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Create notification document for tracking
      await _firestore.collection('notifications').add({
        'userId': userId,
        'userType': userType,
        'title': title,
        'message': body, // Changed from 'body' to 'message' to match your UI
        'type': type,
        'data': data ?? {},
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(), // Changed to match your UI
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Notification sent to $userType $userId: $title');

      // In a real implementation, you would also send push notification via FCM
      // This would require a backend server or Cloud Functions

    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // ========== DONATION FLOW NOTIFICATIONS ==========

  // Send notification when donor creates a new donation
  Future<void> notifyNewDonationCreated({
    required String donorId,
    required String donorName,
    required String donationId,
    required String donationTitle,
    required List<String> receiverIds,
  }) async {
    for (final receiverId in receiverIds) {
      await sendNotificationToUser(
        userId: receiverId,
        userType: 'receiver',
        title: 'New Donation Available! 🍽️',
        body: '$donorName has posted a new donation: "$donationTitle"',
        type: 'new_donation',
        data: {
          'donationId': donationId,
          'donorName': donorName,
          'donationTitle': donationTitle,
          'donorId': donorId,
        },
      );
    }
  }

  // Send notification when receiver claims a donation
  Future<void> notifyDonationClaimed({
    required String donorId,
    required String receiverId,
    required String receiverName,
    required String donationId,
    required String donationTitle,
  }) async {
    // Notify donor
    await sendNotificationToUser(
      userId: donorId,
      userType: 'donor',
      title: 'Donation Claimed! ✅',
      body: '$receiverName has claimed your donation: "$donationTitle"',
      type: 'donation_claimed',
      data: {
        'donationId': donationId,
        'receiverName': receiverName,
        'donationTitle': donationTitle,
        'receiverId': receiverId,
      },
    );

    // Notify receiver (confirmation)
    await sendNotificationToUser(
      userId: receiverId,
      userType: 'receiver',
      title: 'Donation Claimed Successfully! 🎉',
      body: 'You have claimed "$donationTitle". Please coordinate with the donor for pickup.',
      type: 'donation_claimed_confirmation',
      data: {
        'donationId': donationId,
        'donationTitle': donationTitle,
        'donorId': donorId,
      },
    );
  }

  // Send notification when donation is completed
  Future<void> notifyDonationCompleted({
    required String donorId,
    required String receiverId,
    required String donationTitle,
    required int pointsAwarded,
  }) async {
    // Notify donor
    await sendNotificationToUser(
      userId: donorId,
      userType: 'donor',
      title: 'Donation Completed! 🎊',
      body: 'Your donation "$donationTitle" has been successfully completed. You earned $pointsAwarded points!',
      type: 'donation_completed',
      data: {
        'donationTitle': donationTitle,
        'pointsAwarded': pointsAwarded,
      },
    );

    // Notify receiver
    await sendNotificationToUser(
      userId: receiverId,
      userType: 'receiver',
      title: 'Donation Received! 🙏',
      body: 'Thank you for receiving "$donationTitle". The donation has been completed.',
      type: 'donation_received',
      data: {
        'donationTitle': donationTitle,
      },
    );
  }

  // Send notification when receiver arrives at location
  Future<void> notifyReceiverArrived({
    required String donorId,
    required String receiverName,
    required String donationTitle,
  }) async {
    await sendNotificationToUser(
      userId: donorId,
      userType: 'donor',
      title: 'Receiver Arrived! 📍',
      body: '$receiverName has arrived to pick up "$donationTitle"',
      type: 'receiver_arrived',
      data: {
        'receiverName': receiverName,
        'donationTitle': donationTitle,
      },
    );
  }

  // Send notification for donation cancellation
  Future<void> notifyDonationCancelled({
    required String donorId,
    required String receiverId,
    required String donationTitle,
    required String cancelledBy,
    required String reason,
  }) async {
    final isCancelledByDonor = cancelledBy == 'donor';
    final otherUserId = isCancelledByDonor ? receiverId : donorId;
    final otherUserType = isCancelledByDonor ? 'receiver' : 'donor';
    final cancelledByName = isCancelledByDonor ? 'Donor' : 'Receiver';

    await sendNotificationToUser(
      userId: otherUserId,
      userType: otherUserType,
      title: 'Donation Cancelled ❌',
      body: '$cancelledByName cancelled the donation: "$donationTitle". Reason: $reason',
      type: 'donation_cancelled',
      data: {
        'donationTitle': donationTitle,
        'cancelledBy': cancelledBy,
        'reason': reason,
      },
    );
  }

  // ========== HELPER METHODS ==========

  // Get all receiver users (you might want to modify this based on your user structure)
  Future<List<String>> getAllReceiverIds() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'receiver')
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error getting receiver IDs: $e');
      return [];
    }
  }

  // Get nearby receivers based on location (simplified version)
  Future<List<String>> getNearbyReceiverIds(double latitude, double longitude, double radiusInKm) async {
    // This is a simplified version - you'll need to implement proper geoqueries
    // For now, return all receivers
    return await getAllReceiverIds();
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read for a user type
  Future<void> markAllNotificationsAsRead(String userType) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('userType', isEqualTo: userType)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Navigate based on notification data
  void _navigateFromNotification(Map<String, dynamic> data) {
    final type = data['type'];
    switch (type) {
      case 'new_donation':
        // Navigate to donations list or specific donation
        Get.toNamed('/donations');
        break;
      case 'donation_claimed':
        // Navigate to donation details
        final donationId = data['donationId'];
        if (donationId != null) {
          Get.toNamed('/donation/$donationId');
        }
        break;
      case 'donation_completed':
        // Navigate to completed donations
        Get.toNamed('/completed-donations');
        break;
      default:
        Get.toNamed('/notifications');
        break;
    }
  }

  // Refresh notifications (for pull-to-refresh)
  Future<void> refreshNotifications() async {
    _listenToUserNotifications();
  }
}