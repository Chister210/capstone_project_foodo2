import 'package:flutter/material.dart';

// Google API Key - Should match the key in AndroidManifest.xml and AppDelegate.swift
// Make sure this key has Directions API enabled in Google Cloud Console
const String google_api_key = 'AIzaSyCsTChi88TYeupPvBX5z4BAjDDCPWYxL5s';

// App Information
const String APP_NAME = 'Foodo';
const String APP_VERSION = '1.0.0';
const String APP_DESCRIPTION = 'Fighting hunger together';

// User Types
const String USER_TYPE_DONOR = 'donor';
const String USER_TYPE_RECEIVER = 'receiver';

// Donation Status
const String DONATION_STATUS_AVAILABLE = 'available';
const String DONATION_STATUS_CLAIMED = 'claimed';
const String DONATION_STATUS_IN_PROGRESS = 'in_progress';
const String DONATION_STATUS_COMPLETED = 'completed';
const String DONATION_STATUS_EXPIRED = 'expired';

// Delivery Types
const String DELIVERY_TYPE_PICKUP = 'pickup';
const String DELIVERY_TYPE_DELIVERY = 'delivery';

// Message Types
const String MESSAGE_TYPE_TEXT = 'text';
const String MESSAGE_TYPE_LOCATION = 'location';
const String MESSAGE_TYPE_IMAGE = 'image';

// Notification Types
const String NOTIFICATION_TYPE_NEW_DONATION = 'new_donation';
const String NOTIFICATION_TYPE_DONATION_CLAIMED = 'donation_claimed';
const String NOTIFICATION_TYPE_DONATION_COMPLETED = 'donation_completed';
const String NOTIFICATION_TYPE_RECEIVER_ARRIVED = 'receiver_arrived';
const String NOTIFICATION_TYPE_DONATION_CANCELLED = 'donation_cancelled';
const String NOTIFICATION_TYPE_DONATION_UPDATED = 'donation_updated';

// Colors
const Color primaryColor = Color(0xFF22c55e);
const Color secondaryColor = Color(0xFFFF8C00);
const Color errorColor = Color(0xFFef4444);
const Color successColor = Color(0xFF22c55e);
const Color warningColor = Color(0xFFf59e0b);
const Color infoColor = Color(0xFF3b82f6);

// Dimensions
const double defaultPadding = 16.0;
const double smallPadding = 8.0;
const double largePadding = 24.0;
const double borderRadius = 12.0;
const double smallBorderRadius = 8.0;
const double largeBorderRadius = 16.0;

// Animation Durations
const Duration shortAnimation = Duration(milliseconds: 200);
const Duration mediumAnimation = Duration(milliseconds: 300);
const Duration longAnimation = Duration(milliseconds: 500);

// Location Settings
const double locationUpdateInterval = 15.0; // seconds
const double locationDistanceFilter = 5.0; // meters
const double arrivalThreshold = 50.0; // meters

// Image Settings
const int maxImageWidth = 512;
const int maxImageHeight = 512;
const int imageQuality = 80;

// Points System
const int pointsPerDonation = 10;
const int pointsPerCompletion = 5;

// Search Settings
const int maxSearchResults = 50;
const int searchDebounceMs = 300;

// Chat Settings
const int maxMessageLength = 1000;
const int messagesPerPage = 20;

// Notification Settings
const int maxNotificationHistory = 100;
const Duration notificationTimeout = Duration(seconds: 5);

// Error Messages
const String errorNetwork = 'Network error. Please check your internet connection.';
const String errorPermission = 'Permission denied. Please check your app permissions.';
const String errorLocation = 'Location error. Please enable location services.';
const String errorAuthentication = 'Authentication error. Please try logging in again.';
const String errorUnknown = 'An unexpected error occurred. Please try again.';

// Success Messages
const String successDonationCreated = 'Donation created successfully!';
const String successDonationClaimed = 'Donation claimed successfully!';
const String successDonationCompleted = 'Donation completed successfully!';
const String successMessageSent = 'Message sent successfully!';
const String successLocationShared = 'Location shared successfully!';

// Validation Messages
const String validationEmailRequired = 'Email is required';
const String validationEmailInvalid = 'Please enter a valid email address';
const String validationPasswordRequired = 'Password is required';
const String validationPasswordMinLength = 'Password must be at least 6 characters';
const String validationTitleRequired = 'Title is required';
const String validationDescriptionRequired = 'Description is required';
const String validationImageRequired = 'Image is required';

// Firebase Collections
const String collectionUsers = 'users';
const String collectionDonations = 'donations';
const String collectionChats = 'chats';
const String collectionMessages = 'messages';
const String collectionNotifications = 'notifications';

// Firebase Fields
const String fieldUid = 'uid';
const String fieldEmail = 'email';
const String fieldDisplayName = 'displayName';
const String fieldUserType = 'userType';
const String fieldCreatedAt = 'createdAt';
const String fieldUpdatedAt = 'updatedAt';
const String fieldIsOnline = 'isOnline';
const String fieldLastSeen = 'lastSeen';
const String fieldLocation = 'location';
const String fieldFcmToken = 'fcmToken';
const String fieldPoints = 'points';

// Storage Paths
const String storageProfileImages = 'profile_images';
const String storageDonationImages = 'donation_images';
const String storageChatImages = 'chat_images';