# Foodo - Complete Setup Guide

## Overview
Foodo is a Flutter-based food donation app that connects market donors with food receivers to reduce food waste and fight hunger. The app features real-time messaging, live location tracking, and a comprehensive notification system.

## Features Implemented

### ✅ User Authentication & Role Separation
- **Separate login systems** for Market Donors and Food Receivers
- **Cross-login prevention** - users cannot access the wrong dashboard
- **Google Sign-In** support for receivers
- **Email verification** system
- **Terms and conditions** acceptance

### ✅ Messaging Platform
- **Real-time chat** between donors and receivers
- **Message history** with timestamps
- **Location sharing** in messages
- **Unread message indicators**
- **Chat list** with last message preview

### ✅ Live Location Tracking
- **Real-time location sharing** between donor and receiver
- **Distance calculation** between users
- **Location updates** every 15 seconds
- **Visual tracking interface** with maps
- **Arrival notifications** when receiver reaches market

### ✅ Enhanced Donation System
- **Donation claiming** with confirmation dialogs
- **Pickup vs Delivery** options with appropriate messaging
- **Donation status tracking** (available, claimed, completed)
- **Image compression** for better performance
- **Allergen information** and food safety guidelines

### ✅ Search & Discovery
- **Search functionality** for available donations
- **Filter by market name**, food type, description
- **Real-time search results**
- **Empty state handling** for no results

### ✅ Notification System
- **Push notifications** for new donations
- **Claim notifications** for donors
- **Completion notifications** with points
- **Real-time notification counts**
- **Background notification handling**

### ✅ User Interface
- **Modern Material Design** with gradients
- **Responsive navigation** with 4 tabs
- **Loading states** and error handling
- **Success/error dialogs** with animations
- **Lottie animations** for better UX

## Prerequisites

Before setting up the app, ensure you have:

1. **Flutter SDK** (3.0.0 or higher)
2. **Dart SDK** (3.0.0 or higher)
3. **Android Studio** or **VS Code** with Flutter extensions
4. **Firebase project** with Firestore and Authentication enabled
5. **Google Services** configuration files
6. **Location permissions** enabled for the app

## Firebase Setup

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: "foodo-app"
4. Enable Google Analytics (optional)
5. Create project

### 2. Enable Authentication
1. In Firebase Console, go to **Authentication**
2. Click **Get Started**
3. Go to **Sign-in method** tab
4. Enable **Email/Password** authentication
5. Enable **Google** authentication
6. Add your app's SHA-1 fingerprint for Android

### 3. Enable Firestore Database
1. Go to **Firestore Database**
2. Click **Create database**
3. Choose **Start in test mode** (for development)
4. Select a location close to your users
5. Create database

### 4. Configure Security Rules
Replace the default Firestore rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Notifications are readable by the user they belong to
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         request.auth.uid == resource.data.userId);
    }
    
    // Chats are readable by participants
    match /chats/{chatId} {
      allow read, write: if request.auth != null && 
        (resource.data.donorId == request.auth.uid || 
         resource.data.receiverId == request.auth.uid);
    }
    
    // Donations are readable by all authenticated users
    match /donations/{donationId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        (resource.data.donorId == request.auth.uid || 
         request.auth.uid == resource.data.donorId);
    }
  }
}
```

### 5. Create Required Indexes
Follow the instructions in `FIREBASE_INDEX_SETUP.md` to create all necessary Firestore indexes.

### 6. Enable Cloud Messaging
1. Go to **Cloud Messaging** in Firebase Console
2. No additional setup required for basic functionality

## App Configuration

### 1. Download Configuration Files
1. In Firebase Console, go to **Project Settings**
2. Scroll down to **Your apps** section
3. Click **Add app** and select **Android**
4. Enter package name: `com.example.capstone_project`
5. Download `google-services.json`
6. Place it in `android/app/` directory

### 2. Configure Android Permissions
Add these permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### 3. Configure iOS (if needed)
1. Download `GoogleService-Info.plist` from Firebase Console
2. Add it to `ios/Runner/` directory
3. Add location permissions to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to show nearby donations and enable live tracking.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to show nearby donations and enable live tracking.</string>
```

## Installation & Running

### 1. Clone the Repository
```bash
git clone <repository-url>
cd capstone_project_foodo1-main
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run the App
```bash
# For Android
flutter run

# For iOS (if on macOS)
flutter run -d ios
```

## Testing the App

### 1. Create Test Accounts
1. **Market Donor Account:**
   - Email: donor@test.com
   - Password: test123
   - Role: Market Donor

2. **Food Receiver Account:**
   - Email: receiver@test.com
   - Password: test123
   - Role: Food Receiver

### 2. Test Workflow
1. **Donor creates donation:**
   - Login as Market Donor
   - Click "Create New Donation"
   - Fill in details and upload image
   - Choose pickup or delivery

2. **Receiver claims donation:**
   - Login as Food Receiver
   - Browse available donations
   - Use search to find specific items
   - Claim donation and see confirmation dialog

3. **Test messaging:**
   - After claiming, go to Messages tab
   - Send messages to coordinate pickup/delivery
   - Share location in chat

4. **Test live tracking:**
   - In chat, click live tracking button
   - See real-time location updates
   - Monitor distance between users

## Troubleshooting

### Common Issues

1. **"Index not found" errors:**
   - Ensure all Firestore indexes are created
   - Check `FIREBASE_INDEX_SETUP.md` for complete list

2. **Location not updating:**
   - Check device location permissions
   - Ensure location services are enabled
   - Test on physical device (not simulator)

3. **Notifications not working:**
   - Check Firebase Cloud Messaging setup
   - Verify notification permissions
   - Test on physical device

4. **Images not uploading:**
   - Check camera/storage permissions
   - Ensure image compression service is working
   - Test with smaller images

5. **Authentication errors:**
   - Verify Firebase configuration files
   - Check SHA-1 fingerprints for Android
   - Ensure authentication methods are enabled

### Debug Mode
Run the app in debug mode to see detailed logs:
```bash
flutter run --debug
```

### Logs
Check console output for:
- Firebase connection status
- Location permission status
- Notification token generation
- Database read/write operations

## Production Deployment

### 1. Build Release APK
```bash
flutter build apk --release
```

### 2. Build App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

### 3. Update Security Rules
Before going live, update Firestore security rules to be more restrictive:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Add production-specific rules here
    // Ensure proper validation and security
  }
}
```

### 4. Enable App Check (Optional)
For additional security, enable Firebase App Check in production.

## Support

For issues or questions:
1. Check this setup guide
2. Review Firebase documentation
3. Check Flutter documentation
4. Review app logs for specific errors

## Features Roadmap

### Future Enhancements
- [ ] Push notifications via FCM
- [ ] Offline support
- [ ] Multi-language support
- [ ] Advanced filtering options
- [ ] Donation analytics
- [ ] User ratings and reviews
- [ ] Social sharing features
- [ ] Admin dashboard

## License

This project is for educational purposes. Please ensure you have proper licenses for any third-party dependencies used in production.
