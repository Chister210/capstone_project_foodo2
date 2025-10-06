import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class BackgroundNotificationService {
  static final BackgroundNotificationService _instance = BackgroundNotificationService._internal();
  factory BackgroundNotificationService() => _instance;
  BackgroundNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Initialize background notification service
  static Future<void> initialize() async {
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

    await _instance._localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _instance._onNotificationTap,
    );

    // Create notification channel for Android
    await _instance._createNotificationChannel();
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

  // Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    print('Background notification tapped: ${response.payload}');
    // Handle navigation based on payload
  }

  // Show notification from background
  Future<void> showNotification({
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

  // Send notification to user from background
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;
      
      if (fcmToken == null) return;

      // Create notification document for tracking
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Show local notification
      await showNotification(
        title: title,
        body: body,
        payload: data?.toString(),
      );

      print('Background notification sent to user $userId: $title');
    } catch (e) {
      print('Error sending background notification: $e');
    }
  }
}

// Background message handler
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  
  // Initialize Firebase if not already done
  await Firebase.initializeApp();
  
  // Initialize background notification service
  await BackgroundNotificationService.initialize();
  
  // Show notification
  await BackgroundNotificationService().showNotification(
    title: message.notification?.title ?? 'Food Donation',
    body: message.notification?.body ?? 'You have a new notification',
    payload: message.data.toString(),
  );
}
