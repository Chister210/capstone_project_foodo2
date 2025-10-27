const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotificationOnCreate = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const userId = notification.userId;
    const notificationId = context.params.notificationId;

    console.log(`🔔 Cloud Function: Processing notification ${notificationId} for user ${userId}`);

    // Get the user's FCM token from Firestore
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;
    
    if (!fcmToken) {
      console.log(`❌ No FCM token for user: ${userId}`);
      return null;
    }

    console.log(`🔔 FCM token found for user ${userId}: ${fcmToken.substring(0, 20)}...`);

    // Compose the notification payload
    const payload = {
      notification: {
        title: notification.title || 'New Notification',
        body: notification.message || notification.body || '',
        icon: 'ic_notification',
        color: '#22c55e',
      },
      data: {
        type: notification.type || '',
        userId: userId,
        notificationId: notificationId,
        ...notification.data,
      },
      token: fcmToken,
    };

    try {
      // Send the notification using the new API
      const response = await admin.messaging().send(payload);
      console.log(`✅ Successfully sent FCM notification to user ${userId}:`, response);
      return response;
    } catch (error) {
      console.error(`❌ Error sending FCM notification to user ${userId}:`, error);
      
      // If token is invalid, remove it from user document
      if (error.code === 'messaging/invalid-registration-token' || 
          error.code === 'messaging/registration-token-not-registered') {
        console.log(`🔔 Removing invalid FCM token for user ${userId}`);
        await admin.firestore().collection('users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      
      return null;
    }
  });

// Removed chat message FCM push to avoid duplicates; messages now create a notification doc handled by sendNotificationOnCreate