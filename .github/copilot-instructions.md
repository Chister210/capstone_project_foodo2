# Copilot Instructions for Foodo (Flutter Food Donation App)

## Project Overview
- **Foodo** is a Flutter app connecting market donors and food receivers to reduce food waste.
- Features: role-based authentication, real-time chat, live location tracking, push notifications, donation claiming, and search/filtering.
- Backend: Firebase (Firestore, Auth, Cloud Messaging).

## Architecture & Key Patterns
- **Role Separation:**
  - `MarketDonor` and `FoodReceiver` directories contain role-specific screens and flows.
  - Role is determined at login and enforced throughout navigation.
- **Navigation:**
  - Uses `GetX` for navigation and state management (`controllers/navigation_controller.dart`).
  - Main entry: `main.dart` → role selection → home screen based on user type.
- **Data Models:**
  - See `models/donation_model.dart` and `models/user_model.dart` for Firestore schema.
  - Donations, users, notifications, and chats are top-level Firestore collections.
- **Services:**
  - All business logic and Firebase calls are in `services/` (e.g., `donation_service.dart`, `notification_service.dart`).
  - Notification logic integrates both FCM and local notifications.
- **UI Patterns:**
  - Modern Material Design, Lottie animations, and responsive layouts.
  - Custom widgets in `widgets/` (e.g., `donation_card.dart`, `enhanced_notification_popup.dart`).

## Developer Workflows
- **Setup:**
  - Follow `COMPLETE_SETUP_GUIDE.md` for Firebase, permissions, and local config.
  - Use `FIREBASE_INDEX_SETUP.md` to configure required Firestore indexes.
- **Build & Run:**
  - Install dependencies: `flutter pub get`
  - Run app: `flutter run` (Android), `flutter run -d ios` (iOS)
  - Debug: `flutter run --debug`
- **Testing:**
  - Manual test accounts: see `COMPLETE_SETUP_GUIDE.md` (donor/receiver credentials).
  - Widget tests: in `test/` directory.
- **Production:**
  - Build APK: `flutter build apk --release`
  - Build App Bundle: `flutter build appbundle --release`
  - Update Firestore rules before release.

## Project Conventions
- **Firestore:**
  - All user, donation, notification, and chat data is stored in separate collections.
  - Indexes are required for efficient queries (see `FIREBASE_INDEX_SETUP.md`).
- **Image Handling:**
  - Images are compressed and stored as base64 strings for performance.
- **Notifications:**
  - FCM tokens are saved in user profiles for push notifications.
- **Location:**
  - Live tracking uses Firestore updates and Google Maps integration.
- **Terms & Conditions:**
  - Users must accept terms before using main features.

## Key Files & Directories
- `lib/main.dart` — App entry, role routing
- `lib/MarketDonor/`, `lib/FoodReceiver/` — Role-specific screens
- `lib/services/` — Business logic, Firebase integration
- `lib/models/` — Data models
- `COMPLETE_SETUP_GUIDE.md` — Full setup and troubleshooting
- `FIREBASE_INDEX_SETUP.md` — Required Firestore indexes

## Integration Points
- **Firebase:** Auth, Firestore, Cloud Messaging
- **GetX:** Navigation and state
- **Lottie:** Animations for enhanced UX

---

**For AI agents:**
- Always check user role before navigating or performing actions.
- Use service classes for all Firestore and Firebase logic.
- Reference setup guides for environment-specific steps.
- Follow project-specific patterns for notifications, image handling, and live location.
