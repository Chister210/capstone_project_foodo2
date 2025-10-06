# 🔥 Firebase Setup Guide for Food Donation App

## Prerequisites
- Flutter SDK installed
- Firebase CLI installed (`npm install -g firebase-tools`)
- Google account
- Android Studio / VS Code

## Step 1: Create Firebase Project

### 1.1 Go to Firebase Console
1. Visit [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter project name: `food-donation-app` (or your preferred name)
4. Enable Google Analytics (recommended)
5. Choose Analytics account or create new one
6. Click "Create project"

### 1.2 Configure Project Settings
1. Go to Project Settings (gear icon)
2. Note down your **Project ID** (you'll need this later)
3. Go to "General" tab and scroll down to "Your apps"
4. Click "Add app" and select the platform (Android/iOS/Web)

## Step 2: Configure Android App

### 2.1 Add Android App
1. In Firebase Console, click "Add app" → Android
2. Enter package name: `com.example.capstone_project` (or your package name)
3. Enter app nickname: `Food Donation App`
4. Download `google-services.json`
5. Place it in `android/app/` directory

### 2.2 Update Android Configuration
1. Open `android/app/build.gradle`
2. Add the following in the `dependencies` block:
```gradle
implementation platform('com.google.firebase:firebase-bom:32.7.0')
implementation 'com.google.firebase:firebase-analytics'
implementation 'com.google.firebase:firebase-firestore'
implementation 'com.google.firebase:firebase-storage'
implementation 'com.google.firebase:firebase-auth'
```

3. Add the following at the top of `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```

4. Add to `android/build.gradle` (project level):
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

## Step 3: Configure iOS App (if needed)

### 3.1 Add iOS App
1. In Firebase Console, click "Add app" → iOS
2. Enter bundle ID: `com.example.capstoneProject` (or your bundle ID)
3. Download `GoogleService-Info.plist`
4. Add it to `ios/Runner/` directory in Xcode

## Step 4: Enable Firebase Services

### 4.1 Enable Authentication
1. Go to "Authentication" in Firebase Console
2. Click "Get started"
3. Go to "Sign-in method" tab
4. Enable "Email/Password"
5. Enable "Google" (optional)

### 4.2 Enable Firestore Database
1. Go to "Firestore Database" in Firebase Console
2. Click "Create database"
3. Choose "Start in test mode" (we'll configure security rules later)
4. Select your preferred location (closest to your users)

### 4.3 Firebase Storage (NOT NEEDED)
**Note: This app does NOT use Firebase Storage**
- Images are stored as base64 strings in Firestore
- No need to enable Firebase Storage
- This keeps you within the free plan limits

## Step 5: Configure Security Rules

### 5.1 Firestore Security Rules
1. Go to "Firestore Database" → "Rules" tab
2. Replace the default rules with the content from `firestore.rules` file
3. Click "Publish"

### 5.2 Storage Security Rules (NOT NEEDED)
**Note: Firebase Storage is not used in this app**
- No need to configure Storage rules
- Images are stored as base64 strings in Firestore

## Step 6: Create Required Indexes

### 6.1 Automatic Index Creation
The app will automatically create required indexes when you run queries. However, you can manually create them:

1. Go to "Firestore Database" → "Indexes" tab
2. Click "Create Index"
3. Create the following indexes:

**Index 1:**
- Collection: `donations`
- Fields: `status` (Ascending), `createdAt` (Descending)

**Index 2:**
- Collection: `donations`
- Fields: `donorId` (Ascending), `createdAt` (Descending)

**Index 3:**
- Collection: `donations`
- Fields: `status` (Ascending), `createdAt` (Ascending)

## Step 7: Test Your Setup

### 7.1 Run the App
```bash
flutter clean
flutter pub get
flutter run
```

### 7.2 Test Database Connection
1. Open the app
2. Try to create a donation (this will test Firestore)
3. Try to upload an image (this will test Storage)
4. Check Firebase Console to see if data appears

## Step 8: Production Configuration

### 8.1 Update Security Rules for Production
1. Go to "Firestore Database" → "Rules"
2. Update rules to be more restrictive for production
3. Test thoroughly before deploying

### 8.2 Set up Monitoring
1. Go to "Performance Monitoring"
2. Enable performance monitoring
3. Set up alerts for high usage

### 8.3 Configure Backup
1. Go to "Firestore Database" → "Backups"
2. Enable automatic backups
3. Set backup frequency

## Troubleshooting

### Common Issues:

#### 1. "Firebase not initialized" error
- Make sure `google-services.json` is in the correct location
- Check that Firebase is initialized in `main.dart`

#### 2. Permission denied errors
- Check Firestore security rules
- Ensure user is authenticated
- Verify user has proper permissions

#### 3. Storage upload fails
- Check Storage security rules
- Verify user authentication
- Check file size limits

#### 4. Index errors
- Create required indexes in Firebase Console
- Wait for indexes to build (can take time)

### Debug Commands:
```bash
# Check Firebase configuration
flutter doctor

# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check Firebase CLI
firebase --version
firebase login
firebase projects:list
```

## Security Best Practices

### 1. Authentication
- Always verify user authentication
- Use proper user roles (donor/receiver)
- Implement proper sign-out functionality

### 2. Data Validation
- Validate all input data
- Use proper data types
- Implement proper error handling

### 3. Security Rules
- Regularly review and update security rules
- Test rules thoroughly
- Monitor for security violations

### 4. Monitoring
- Set up proper monitoring
- Monitor usage and costs
- Set up alerts for unusual activity

## Cost Optimization

### 1. Firestore
- Use efficient queries
- Implement proper pagination
- Use offline persistence wisely

### 2. Storage
- Compress images before upload
- Use appropriate image sizes
- Implement proper cleanup

### 3. Authentication
- Monitor active users
- Implement proper session management
- Clean up inactive users

## Support

If you encounter issues:
1. Check Firebase Console for errors
2. Review Flutter logs
3. Check Firebase documentation
4. Contact Firebase support if needed

## Next Steps

After setup:
1. Test all functionality
2. Deploy to production
3. Monitor usage and performance
4. Set up proper backup and recovery
5. Implement monitoring and alerts
