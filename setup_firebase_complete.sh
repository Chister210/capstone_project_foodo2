#!/bin/bash

echo "Setting up Firebase for Food Donation App..."
echo

echo "1. Installing Firebase CLI..."
npm install -g firebase-tools

echo
echo "2. Logging into Firebase..."
firebase login

echo
echo "3. Installing Cloud Functions dependencies..."
cd functions
npm install
cd ..

echo
echo "4. Deploying Firestore rules and indexes..."
firebase deploy --only firestore:rules,firestore:indexes

echo
echo "5. Deploying Cloud Functions..."
firebase deploy --only functions

echo
echo "6. Checking deployment status..."
firebase projects:list

echo
echo "Setup complete!"
echo
echo "Next steps:"
echo "1. Add google-services.json to android/app/"
echo "2. Add GoogleService-Info.plist to ios/Runner/"
echo "3. Update your Flutter app configuration"
echo "4. Test notifications in your app"
echo
echo "For detailed setup instructions, see FIREBASE_COMPLETE_SETUP_GUIDE.md"
