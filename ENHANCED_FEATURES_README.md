# Food Donation App - Enhanced Version

A comprehensive Flutter application for connecting food donors (markets) with food receivers, featuring real-time tracking, messaging, and location-based services.

## 🚀 New Features

### 1. **Separate User Accounts**
- **Donor Accounts**: Market owners who donate surplus food
- **Receiver Accounts**: Individuals/organizations who receive donated food
- Complete separation with distinct registration flows
- Role-based authentication and navigation

### 2. **Enhanced Donor Registration**
- Market name and address fields
- Interactive map picker for precise location selection
- GPS coordinates stored for accurate positioning
- Market information displayed to receivers

### 3. **Google Maps Integration**
- Real-time map showing available donor locations
- Interactive markers with donor information
- Market details and available donations
- Distance calculation and navigation support

### 4. **Improved Donation Logic**
- **Status Flow**: `available` → `claimed` → `in_progress` → `completed`
- Real-time notifications for status changes
- Automatic point awarding system for donors
- Comprehensive donation tracking

### 5. **Real-Time Location Tracking**
- Live location sharing between donors and receivers
- Proximity detection for arrival notifications
- Background location tracking
- Automatic completion when receiver arrives

### 6. **Messaging System**
- Real-time chat between donors and receivers
- Location sharing within chat
- Message read receipts
- Chat history persistence

### 7. **Profile Management**
- Profile picture upload (camera/gallery)
- User information display
- Points system for donors
- Account status tracking

### 8. **Points & Rewards System**
- Donors earn 10 points per completed donation
- Points displayed in profile
- Gamification elements for engagement

### 9. **Push Notifications**
- Firebase Cloud Messaging integration
- Real-time notifications for:
  - New donations
  - Donation claims
  - Arrival notifications
  - Completion confirmations

### 10. **Responsive Design**
- Mobile-first approach
- Adaptive layouts for different screen sizes
- Touch-friendly interfaces
- Optimized for mobile devices

## 📱 Screenshots

### Donor Registration with Map Picker
- Interactive map for selecting market location
- Form validation and error handling
- Location permission management

### Receiver Map View
- Available donors displayed on map
- Donation details in bottom sheet
- One-tap claiming functionality

### Real-Time Tracking
- Live location updates
- Proximity-based arrival detection
- Automatic completion workflow

### Chat Interface
- Real-time messaging
- Location sharing
- Message status indicators

### Profile Management
- Photo upload functionality
- Points display
- Account information

## 🛠 Technical Implementation

### Architecture
- **Models**: Enhanced data models with new fields
- **Services**: Modular service architecture
- **Screens**: Feature-specific screen components
- **Widgets**: Reusable UI components

### Key Services
- `DonationService`: Manages donation lifecycle
- `MessagingService`: Handles real-time communication
- `LocationTrackingService`: GPS and proximity features
- `NotificationService`: Push notification management

### Database Structure
```javascript
// Users Collection
{
  "users": {
    "userId": {
      "email": "string",
      "userType": "donor|receiver",
      "displayName": "string",
      "photoUrl": "string",
      "phone": "string",
      "address": "string",
      "location": "geopoint",
      "points": "number",
      "marketName": "string", // donors only
      "marketAddress": "string", // donors only
      "marketLocation": "geopoint", // donors only
      "fcmToken": "string",
      "isOnline": "boolean",
      "lastSeen": "timestamp"
    }
  }
}

// Donations Collection
{
  "donations": {
    "donationId": {
      "donorId": "string",
      "title": "string",
      "description": "string",
      "imageUrl": "string",
      "status": "available|claimed|in_progress|completed",
      "claimedBy": "string",
      "chatId": "string",
      "claimedAt": "timestamp",
      "completedAt": "timestamp",
      "receiverLocation": "geopoint",
      "donorNotified": "boolean",
      "receiverNotified": "boolean"
    }
  }
}

// Chats Collection
{
  "chats": {
    "chatId": {
      "donationId": "string",
      "donorId": "string",
      "receiverId": "string",
      "lastMessage": "string",
      "lastMessageTime": "timestamp",
      "donorActive": "boolean",
      "receiverActive": "boolean"
    }
  }
}
```

## 🔧 Dependencies

### Core Dependencies
```yaml
dependencies:
  flutter: sdk: flutter
  firebase_core: ^4.1.0
  firebase_auth: ^6.0.2
  firebase_storage: ^12.3.2
  firebase_messaging: ^15.1.3
  cloud_firestore: ^6.0.1
  google_maps_flutter: ^2.13.1
  geolocator: ^14.0.2
  permission_handler: ^11.3.1
  image_picker: ^1.0.4
  flutter_local_notifications: ^18.0.1
  get: ^4.7.2
  lottie: ^3.3.2
```

### New Dependencies Added
- `firebase_storage`: For image uploads
- `firebase_messaging`: For push notifications
- `permission_handler`: For location permissions
- `cached_network_image`: For image caching
- `uuid`: For unique identifiers
- `socket_io_client`: For real-time communication
- `flutter_local_notifications`: For local notifications

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.9.0+)
- Firebase project setup
- Google Maps API key
- Android/iOS development environment

### Installation
1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Configure Firebase:
   - Add `google-services.json` (Android)
   - Add `GoogleService-Info.plist` (iOS)
4. Set up Google Maps API key
5. Configure location permissions
6. Run the app: `flutter run`

### Firebase Setup
1. Create a new Firebase project
2. Enable Authentication, Firestore, and Cloud Messaging
3. Configure security rules
4. Add platform-specific configuration files

### Google Maps Setup
1. Enable Google Maps API
2. Create API key
3. Configure platform-specific settings
4. Add API key to configuration files

## 📋 Features Checklist

- ✅ Separate donor and receiver accounts
- ✅ Enhanced donor registration with map picker
- ✅ Google Maps integration for donor locations
- ✅ Improved donation logic with status flow
- ✅ Real-time location tracking
- ✅ Messaging system between users
- ✅ Profile picture upload and management
- ✅ Points system for donors
- ✅ Push notifications
- ✅ Responsive mobile design

## 🔒 Security & Privacy

- User data encryption
- Location permission management
- Secure Firebase rules
- Privacy-compliant data handling
- User consent for location tracking

## 🐛 Known Issues & Limitations

- Location accuracy depends on device GPS
- Requires internet connection for real-time features
- Battery usage for continuous location tracking
- Platform-specific permission handling

## 🔮 Future Enhancements

- Offline mode support
- Advanced analytics dashboard
- Social features and ratings
- Multi-language support
- Advanced filtering and search
- Integration with food delivery services

## 📞 Support

For technical support or feature requests, please contact the development team or create an issue in the repository.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
