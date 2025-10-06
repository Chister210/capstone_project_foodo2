#!/bin/bash

# Firebase Setup Script for Food Donation App
# This script helps you set up Firebase for your Flutter app

echo "🔥 Firebase Setup Script for Food Donation App"
echo "=============================================="

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
else
    echo "✅ Firebase CLI is installed"
fi

# Check if user is logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo "🔐 Please log in to Firebase:"
    firebase login
fi

echo ""
echo "📋 Setup Checklist:"
echo "=================="
echo "1. ✅ Firebase CLI installed"
echo "2. ✅ Logged in to Firebase"
echo ""
echo "📝 Next Steps:"
echo "=============="
echo "1. Create a new Firebase project at: https://console.firebase.google.com/"
echo "2. Add Android app to your Firebase project"
echo "3. Download google-services.json and place it in android/app/"
echo "4. Enable Authentication, Firestore, and Storage in Firebase Console"
echo "5. Update security rules using the provided .rules files"
echo "6. Run: flutter clean && flutter pub get && flutter run"
echo ""
echo "📚 For detailed instructions, see: FIREBASE_SETUP_GUIDE.md"
echo ""
echo "🔧 Quick Commands:"
echo "=================="
echo "flutter clean"
echo "flutter pub get"
echo "flutter run"
echo ""
echo "📖 Documentation:"
echo "================="
echo "- Firebase Console: https://console.firebase.google.com/"
echo "- FlutterFire Documentation: https://firebase.flutter.dev/"
echo "- Firestore Rules: https://firebase.google.com/docs/firestore/security/get-started"
echo ""
echo "🎉 Happy coding!"
