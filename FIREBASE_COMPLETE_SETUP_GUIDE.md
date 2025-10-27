# Complete Firebase Setup Guide for Food Donation App

This guide will help you set up Firebase for your food donation app with real-time notifications, FCM push notifications, and proper security rules.

## Prerequisites

- Node.js (v18 or higher)
- Firebase CLI installed (`npm install -g firebase-tools`)
- Flutter SDK installed
- Android Studio / Xcode for mobile development

## 1. Firebase Project Setup

### 1.1 Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `food-donation-app`
4. Enable Google Analytics (optional)
5. Choose your analytics account
6. Click "Create project"

### 1.2 Enable Required Services
In your Firebase project console:

1. **Authentication**
   - Go to Authentication > Sign-in method
   - Enable Email/Password
   - Enable Google (optional)

2. **Firestore Database**
   - Go to Firestore Database
   - Click "Create database"
   - Choose "Start in test mode" (we'll update rules later)
   - Select your preferred location

3. **Cloud Functions**
   - Go to Functions
   - Click "Get started"
   - Follow the setup instructions

4. **Cloud Messaging**
   - Go to Cloud Messaging
   - This is automatically enabled for FCM

## 2. Firebase CLI Setup

### 2.1 Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 2.2 Login to Firebase
```bash
firebase login
```

### 2.3 Initialize Firebase in your project
```bash
# Navigate to your project directory
cd capstone_project_foodo2

# Initialize Firebase
firebase init

# Select the following services:
# - Firestore: Configure security rules and indexes
# - Functions: Configure a Cloud Functions directory
# - Hosting: Configure files for Firebase Hosting (optional)

# Choose your existing Firebase project
# Use default settings for most options
```

## 3. Firestore Security Rules

### 3.1 Update firestore.rules
The rules are already configured in your `firestore.rules` file. Deploy them:

```bash
firebase deploy --only firestore:rules
```

### 3.2 Create Firestore Indexes
Create a file `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "chats",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "donorId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "lastMessageTime",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "chats",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "receiverId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "lastMessageTime",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        {
          "fieldPath": "senderId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "isRead",
          "order": "ASCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}
```

Deploy indexes:
```bash
firebase deploy --only firestore:indexes
```

## 4. Cloud Functions Setup

### 4.1 Install Dependencies
```bash
cd functions
npm install
```

### 4.2 Deploy Functions
```bash
# From project root
firebase deploy --only functions
```

### 4.3 Verify Functions
Check your Firebase Console > Functions to see:
- `sendNotificationOnCreate`
- `sendMessageNotification`

## 5. Android Configuration

### 5.1 Download google-services.json
1. Go to Project Settings > General
2. Add Android app
3. Enter package name: `com.example.capstone_project` (or your package name)
4. Download `google-services.json`
5. Place it in `android/app/`

### 5.2 Update android/app/build.gradle
```gradle
apply plugin: 'com.google.gms.google-services'

dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-analytics'
    implementation 'com.google.firebase:firebase-messaging'
    implementation 'com.google.firebase:firebase-firestore'
    implementation 'com.google.firebase:firebase-auth'
}
```

### 5.3 Update android/build.gradle
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

### 5.4 Add Permissions to android/app/src/main/AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- FCM Service -->
<service
    android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

## 6. iOS Configuration

### 6.1 Download GoogleService-Info.plist
1. Go to Project Settings > General
2. Add iOS app
3. Enter bundle ID: `com.example.capstoneProject` (or your bundle ID)
4. Download `GoogleService-Info.plist`
5. Add to `ios/Runner/` in Xcode

### 6.2 Update ios/Runner/Info.plist
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>background-fetch</string>
</array>
```

## 7. Flutter Configuration

### 7.1 Update pubspec.yaml
Ensure these dependencies are included:
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  firebase_messaging: ^14.7.10
  flutter_local_notifications: ^16.3.2
  get: ^4.6.6
```

### 7.2 Initialize Firebase in main.dart
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(MyApp());
}
```

## 8. Testing Notifications

### 8.1 Test FCM Token Generation
Add this to your app to verify FCM tokens:
```dart
// In your notification service
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');
```

### 8.2 Test Notification Flow
1. **Donation Creation**: Create a donation as a donor
2. **Receiver Notification**: Check if receivers get notified
3. **Claim Notification**: Claim a donation and check if donor gets notified
4. **Message Notification**: Send a message and check if recipient gets notified

### 8.3 Debug Notifications
Check Firebase Console > Cloud Messaging for delivery reports.

## 9. Production Deployment

### 9.1 Update Security Rules for Production
```javascript
// In firestore.rules - more restrictive for production
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Add rate limiting and additional security checks
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    // ... rest of your rules
  }
}
```

### 9.2 Deploy Everything
```bash
# Deploy all Firebase services
firebase deploy

# Or deploy specific services
firebase deploy --only firestore:rules,functions
```

## 10. Troubleshooting

### 10.1 Common Issues

**FCM Not Working:**
- Check if `google-services.json` is in the correct location
- Verify FCM token is being generated
- Check Cloud Functions logs in Firebase Console

**Notifications Not Appearing:**
- Check device notification permissions
- Verify FCM token is saved to Firestore
- Check Cloud Functions are deployed

**Firestore Permission Denied:**
- Verify security rules are deployed
- Check user authentication status
- Review rule conditions

### 10.2 Debug Commands
```bash
# Check Firebase project status
firebase projects:list

# View function logs
firebase functions:log

# Test security rules
firebase firestore:rules:test
```

## 11. Monitoring and Analytics

### 11.1 Enable Monitoring
- Go to Firebase Console > Performance Monitoring
- Enable for your app

### 11.2 Set up Alerts
- Go to Firebase Console > Cloud Messaging
- Set up delivery reports and failure alerts

## 12. Security Best Practices

1. **Never expose FCM tokens in client-side code**
2. **Use proper Firestore security rules**
3. **Validate all data on the server side**
4. **Implement rate limiting for notifications**
5. **Regularly audit user permissions**

## 13. Backup and Recovery

### 13.1 Firestore Backup
```bash
# Enable automatic backups in Firebase Console
# Go to Firestore > Backup & Restore
```

### 13.2 Export Data
```bash
# Export Firestore data
gcloud firestore export gs://your-bucket/backup-$(date +%Y%m%d)
```

This setup will give you a fully functional Firebase backend with real-time notifications, FCM push notifications, and proper security rules for your food donation app.
