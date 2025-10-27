# Firebase Setup Instructions for Enhanced Map Screen

## Prerequisites
- Firebase project created
- Flutter app configured with Firebase
- Google Maps API key obtained

## 1. Firebase Firestore Rules

Update your `firestore.rules` file:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null; // Allow reading for map display
    }
    
    // Donations collection
    match /donations/{donationId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        (request.auth.uid == resource.data.donorId || 
         request.auth.uid == request.resource.data.donorId);
    }
    
    // Feedback collection
    match /feedback/{feedbackId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        request.auth.uid == request.resource.data.receiverId;
    }
    
    // Notifications collection
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
  }
}
```

## 2. Firebase Storage Rules

Update your `storage.rules` file:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## 3. Firestore Indexes

Add these indexes to your `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userType",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "isActive",
          "order": "ASCENDING"
        }
      ]
    },
    {
      "collectionGroup": "donations",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "donorId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "feedback",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "donorId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "isVisible",
          "order": "ASCENDING"
        }
      ]
    },
    {
      "collectionGroup": "feedback",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "isVisible",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}
```

## 4. Google Maps API Setup

### Enable Required APIs:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Enable these APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Directions API
   - Places API
   - Geocoding API

### API Key Restrictions:
1. Go to APIs & Services > Credentials
2. Click on your API key
3. Add these restrictions:
   - **Application restrictions**: Android apps (add your package name and SHA-1)
   - **API restrictions**: Select the APIs listed above

## 5. Android Configuration

### Update `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    
    <application
        android:label="Food Donation App"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Google Maps API Key -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_GOOGLE_MAPS_API_KEY" />
            
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

## 6. iOS Configuration

### Update `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Update `ios/Runner/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>Food Donation App</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$(FLUTTER_BUILD_NAME)</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>$(FLUTTER_BUILD_NUMBER)</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIMainStoryboardFile</key>
    <string>Main</string>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>CADisableMinimumFrameDurationOnPhone</key>
    <true/>
    <key>UIApplicationSupportsIndirectInputEvents</key>
    <true/>
    
    <!-- Location permissions -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>This app needs location access to show nearby food donations and donors.</string>
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>This app needs location access to show nearby food donations and donors.</string>
    <key>NSLocationAlwaysUsageDescription</key>
    <string>This app needs location access to show nearby food donations and donors.</string>
</dict>
</plist>
```

## 7. User Data Structure

Ensure your user documents in Firestore have this structure:

```json
{
  "email": "user@example.com",
  "name": "User Name",
  "displayName": "User Name",
  "userType": "donor", // or "receiver"
  "phone": "+1234567890",
  "address": "User Address",
  "location": {
    "latitude": 7.1907,
    "longitude": 125.4553
  },
  "marketAddress": "Market Address",
  "isActive": true,
  "isOnline": true,
  "lastActive": "2024-01-01T00:00:00Z",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

## 8. Donation Data Structure

Ensure your donation documents have this structure:

```json
{
  "donorId": "donor_user_id",
  "donorEmail": "donor@example.com",
  "title": "Food Title",
  "description": "Food Description",
  "imageUrl": "image_url_or_base64",
  "pickupTime": "2024-01-01T00:00:00Z",
  "deliveryType": "pickup",
  "status": "available",
  "address": "Donation Address",
  "marketLocation": {
    "latitude": 7.1907,
    "longitude": 125.4553
  },
  "marketAddress": "Market Address",
  "foodType": "cooked",
  "foodCategory": "cooked_food",
  "quantity": "5 servings",
  "specification": "by_serving",
  "maxRecipients": 5,
  "allergens": ["nuts", "dairy"],
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

## 9. Feedback Data Structure

Ensure your feedback documents have this structure:

```json
{
  "donationId": "donation_id",
  "receiverId": "receiver_user_id",
  "receiverName": "Receiver Name",
  "donorId": "donor_user_id",
  "donorName": "Donor Name",
  "rating": 5,
  "comment": "Great food!",
  "images": ["image_url_1", "image_url_2"],
  "isVisible": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

## 10. Testing the Setup

1. **Deploy Firestore rules**: `firebase deploy --only firestore:rules`
2. **Deploy Storage rules**: `firebase deploy --only storage`
3. **Deploy indexes**: `firebase deploy --only firestore:indexes`
4. **Test location permissions** on device
5. **Verify Google Maps API key** is working
6. **Check Firestore data** is being read/written correctly

## 11. Troubleshooting

### Common Issues:
- **Maps not loading**: Check API key and restrictions
- **Location not working**: Verify permissions in manifest/plist
- **Firestore errors**: Check rules and indexes
- **Custom markers not showing**: Ensure proper image generation
- **Real-time updates not working**: Check Firestore listeners

### Debug Steps:
1. Check Firebase console for errors
2. Verify API quotas and billing
3. Test on physical device (not simulator)
4. Check network connectivity
5. Review Flutter logs for errors

## 12. Performance Optimization

- Use Firestore offline persistence
- Implement marker clustering for large datasets
- Cache custom markers
- Optimize image sizes for markers
- Use proper Firestore pagination
- Implement proper error handling and retry logic
