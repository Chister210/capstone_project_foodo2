# Firebase Indexes Configuration

This document contains the Firebase Firestore indexes that need to be configured for the feedback system to work properly.

## Required Indexes

The following indexes need to be created in your Firebase Firestore console:

### 1. Feedback Collection - Donor ID with Created At (Descending)
**Purpose**: Efficiently query feedback for a specific donor, ordered by creation date (newest first)

**Collection**: `feedback`
**Fields**:
- `donorId` (Ascending)
- `createdAt` (Descending)

**Query Used**: `feedback.where('donorId', isEqualTo: donorId).orderBy('createdAt', descending: true)`

### 2. Feedback Collection - Donation ID with Receiver ID
**Purpose**: Check if feedback already exists for a specific donation and receiver combination

**Collection**: `feedback`
**Fields**:
- `donationId` (Ascending)
- `receiverId` (Ascending)

**Query Used**: `feedback.where('donationId', isEqualTo: donationId).where('receiverId', isEqualTo: receiverId)`

### 3. Feedback Collection - Donor ID with Rating
**Purpose**: Calculate average rating and rating distribution for a donor

**Collection**: `feedback`
**Fields**:
- `donorId` (Ascending)
- `rating` (Ascending)

**Query Used**: `feedback.where('donorId', isEqualTo: donorId)` (for rating calculations)

### 4. Donations Collection - Expiration DateTime with Status
**Purpose**: Efficiently query expired donations that need to be deleted

**Collection**: `donations`
**Fields**:
- `expirationDateTime` (Ascending)
- `status` (Ascending)

**Query Used**: `donations.where('expirationDateTime', isLessThan: now).where('status', isEqualTo: 'available')`

## How to Configure Indexes

### Option 1: Using Firebase Console (Recommended)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Firestore Database** → **Indexes** tab
4. Click **Create Index**
5. Enter the collection name and fields as specified above
6. Click **Create**

### Option 2: Using Firebase CLI
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login: `firebase login`
3. Initialize (if not already): `firebase init firestore`
4. Deploy indexes: `firebase deploy --only firestore:indexes`

### Option 3: Using the Provided JSON File
The file `firebase_indexes.json` contains all the required indexes in the correct format. You can:
1. Use Firebase CLI to deploy: `firebase deploy --only firestore:indexes`
2. Or manually copy the index definitions from the JSON file to Firebase Console

## Index Creation Status

After creating the indexes, Firebase will show a status:
- **Building**: Index is being created (may take a few minutes)
- **Enabled**: Index is ready to use
- **Error**: There was an issue creating the index (check the error message)

## Important Notes

1. **Index Creation Time**: Indexes may take a few minutes to build, especially if you have existing data
2. **Cost**: Firestore indexes are free and don't count towards your quota
3. **Automatic Creation**: If you run a query that requires an index, Firebase will show a link to create it automatically
4. **Testing**: You can test queries in the Firebase Console before deploying to production

## Verification

After creating the indexes, verify they work by:
1. Testing the feedback submission flow
2. Checking that market details show ratings correctly
3. Verifying that feedback appears in the Reviews tab

If you encounter any "index not found" errors, make sure:
- The indexes are created in the correct project
- The indexes are in "Enabled" status
- The field names match exactly (case-sensitive)

