// ...existing code...
import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String userId; // recipient user id
  final String title;
  final String message;
  final String type; // new_donation | donation_claimed | new_message
  final Map<String, dynamic> data;

  AppNotification({
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    Map<String, dynamic>? data,
  }) : data = data ?? const {};

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'data': data,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Future<void> send(AppNotification notification) async {
    try {
      print('🔔 AppNotification: Sending notification to user ${notification.userId}');
      print('🔔 Title: ${notification.title}');
      print('🔔 Message: ${notification.message}');
      print('🔔 Type: ${notification.type}');

      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notification.toMap());

      print('✅ AppNotification: Successfully sent notification');
    } catch (e) {
      print('❌ AppNotification: Error sending notification: $e');
      rethrow;
    }
  }

  // Convenience helper expected by UI code: builds AppNotification and calls send()
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final notification = AppNotification(
      userId: userId,
      title: title,
      message: body,
      type: type,
      data: data,
    );
    await send(notification);
  }
}
// ...existing code...