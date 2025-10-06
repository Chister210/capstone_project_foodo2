# Firebase Index Setup Instructions

This document provides step-by-step instructions for setting up the required Firebase indexes for the Foodo app to work properly.

## Required Indexes

### 1. Notifications Collection

**Collection:** `notifications`

**Index 1:**
- **Fields:** `userId` (Ascending), `createdAt` (Descending)
- **Query Scope:** Collection
- **Status:** Enabled

**Index 2:**
- **Fields:** `userId` (Ascending), `isRead` (Ascending)
- **Query Scope:** Collection
- **Status:** Enabled

### 2. Chats Collection

**Collection:** `chats`

**Index 1:**
- **Fields:** `donorId` (Ascending), `lastMessageTime` (Descending)
- **Query Scope:** Collection
- **Status:** Enabled

**Index 2:**
- **Fields:** `receiverId` (Ascending), `lastMessageTime` (Descending)
- **Query Scope:** Collection
- **Status:** Enabled

### 3. Donations Collection

**Collection:** `donations`

**Index 1:**
- **Fields:** `status` (Ascending), `createdAt` (Descending)
- **Query Scope:** Collection
- **Status:** Enabled

**Index 2:**
- **Fields:** `donorId` (Ascending), `createdAt` (Descending)
- **Query Scope:** Collection
- **Status:** Enabled

**Index 3:**
- **Fields:** `claimedBy` (Ascending), `createdAt` (Descending)
- **Query Scope:** Collection
- **Status:** Enabled

**Index 4:**
- **Fields:** `status` (Ascending), `createdAt` (Ascending)
- **Query Scope:** Collection
- **Status:** Enabled

### 4. Users Collection

**Collection:** `users`

**Index 1:**
- **Fields:** `userType` (Ascending), `marketLocation` (Ascending)
- **Query Scope:** Collection
- **Status:** Enabled

## How to Create Indexes in Firebase Console

### Step 1: Access Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Firestore Database** in the left sidebar

### Step 2: Create Indexes
1. Click on the **Indexes** tab
2. Click **Create Index**
3. For each index listed above:
   - Select the collection name
   - Add the fields in the specified order
   - Set the sort order (Ascending/Descending) as specified
   - Click **Create**

### Step 3: Wait for Index Creation
- Indexes are created in the background
- You'll see a status of "Building" initially
- Once complete, the status will change to "Enabled"
- This process can take several minutes

## Alternative: Using Firebase CLI

If you prefer using the Firebase CLI, you can create an `firestore.indexes.json` file:

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
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "isRead",
          "order": "ASCENDING"
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
      "collectionGroup": "donations",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "status",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
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
      "collectionGroup": "donations",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "claimedBy",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "donations",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "status",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "ASCENDING"
        }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userType",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "marketLocation",
          "order": "ASCENDING"
        }
      ]
    }
  ]
}
```

Then deploy using:
```bash
firebase deploy --only firestore:indexes
```

## Troubleshooting

### Common Issues

1. **"Index not found" errors**: Make sure all indexes are created and enabled before testing the app.

2. **Slow queries**: If queries are still slow after creating indexes, check that:
   - The index fields match exactly with your query
   - The sort order matches your query
   - The collection name is correct

3. **Index creation fails**: Ensure you have the necessary permissions in your Firebase project.

### Testing Indexes

After creating the indexes, test your app to ensure:
- Notifications load properly
- Chat lists display correctly
- Donation lists show up
- Search functionality works
- Location-based queries function

## Security Rules

Make sure your Firestore security rules allow the necessary read/write operations:

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

## Support

If you encounter any issues with index setup, please check:
1. Firebase Console for error messages
2. App logs for specific query errors
3. Ensure all required fields are properly indexed
4. Verify collection names and field names match exactly
