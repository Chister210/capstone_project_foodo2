# Firestore Database Setup Guide

## Database Structure

### Collections

#### 1. `donations` Collection
```json
{
  "donations": {
    "donationId": {
      "donorId": "string",
      "donorEmail": "string", 
      "title": "string",
      "description": "string",
      "imageUrl": "string",
      "pickupTime": "timestamp",
      "deliveryType": "string", // "pickup" or "delivery"
      "status": "string", // "available", "claimed", "completed", "expired"
      "claimedBy": "string", // receiver user ID
      "createdAt": "timestamp",
      "updatedAt": "timestamp",
      "location": "geopoint", // optional
      "address": "string" // optional
    }
  }
}
```

#### 2. `users` Collection (Required - for terms acceptance tracking)
```json
{
  "users": {
    "userId": {
      "email": "string",
      "userType": "string", // "donor" or "receiver"
      "displayName": "string",
      "photoUrl": "string", // optional
      "createdAt": "timestamp",
      "updatedAt": "timestamp",
      "termsAccepted": "boolean",
      "termsAcceptedAt": "timestamp", // optional
      "termsVersion": "string", // e.g., "1.0"
      "isActive": "boolean",
      "preferences": {
        "notifications": "boolean",
        "locationSharing": "boolean"
      }
    }
  }
}
```

#### 3. `notifications` Collection (Optional - for persistent notifications)
```json
{
  "notifications": {
    "notificationId": {
      "userId": "string",
      "type": "string", // "donation_claimed", "new_donation", etc.
      "title": "string",
      "message": "string",
      "isRead": "boolean",
      "createdAt": "timestamp",
      "donationId": "string" // optional
    }
  }
}
```

## Security Rules

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Donations - anyone can read available donations, only donors can create/update their own
    match /donations/{donationId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
        request.auth.uid == resource.data.donorId;
      allow update: if request.auth != null && 
        (request.auth.uid == resource.data.donorId || 
         request.auth.uid == resource.data.claimedBy);
      allow delete: if request.auth != null && 
        request.auth.uid == resource.data.donorId;
    }
    
    // Notifications - users can only access their own notifications
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
  }
}
```

### Firebase Storage Security Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload donation images
    match /donations/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && 
        request.auth.uid == userId;
    }
  }
}
```

## Indexes Required

### Composite Indexes for Firestore
1. **donations collection**:
   - `status` (Ascending) + `createdAt` (Descending)
   - `donorId` (Ascending) + `createdAt` (Descending)
   - `status` (Ascending) + `createdAt` (Ascending) + `createdAt` (Descending)

## Setup Steps

### 1. Enable Required Services
- [ ] Firestore Database
- [ ] Firebase Authentication
- [ ] Firebase Storage
- [ ] Firebase Hosting (optional)

### 2. Configure Authentication
- [ ] Enable Email/Password authentication
- [ ] Enable Google Sign-In (if using)
- [ ] Configure authorized domains

### 3. Set up Storage
- [ ] Create storage bucket
- [ ] Configure storage rules
- [ ] Set up CORS (if needed for web)

### 4. Configure Firestore
- [ ] Create collections
- [ ] Set up security rules
- [ ] Create indexes
- [ ] Configure backup (recommended)

## Testing

### Test Data Structure
```json
{
  "donations": {
    "test-donation-1": {
      "donorId": "test-user-1",
      "donorEmail": "donor@example.com",
      "title": "Fresh Vegetables",
      "description": "Organic vegetables from local farm",
      "imageUrl": "https://example.com/image.jpg",
      "pickupTime": "2024-01-15T18:00:00Z",
      "deliveryType": "pickup",
      "status": "available",
      "createdAt": "2024-01-15T10:00:00Z",
      "updatedAt": "2024-01-15T10:00:00Z"
    }
  }
}
```

## Monitoring

### Firestore Monitoring
- Set up alerts for high read/write usage
- Monitor query performance
- Track error rates
- Set up backup schedules

### Security Monitoring
- Monitor authentication failures
- Track suspicious activity
- Review access patterns
- Set up security alerts
