const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotificationOnCreate = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const userId = notification.userId;
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const fcmToken = userDoc.get('fcmToken');
    if (!fcmToken) return null;

    const payload = {
      notification: {
        title: notification.title || 'Foodo',
        body: notification.body || 'You have a new notification',
      },
      data: notification.data || {},
      token: fcmToken,
    };

    try {
      await admin.messaging().send(payload);
      return null;
    } catch (e) {
      console.error('Error sending FCM:', e);
      return null;
    }
  });
