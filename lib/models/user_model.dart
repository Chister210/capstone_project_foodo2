import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String userType; // 'donor' or 'receiver'
  final String displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool termsAccepted;
  final DateTime? termsAcceptedAt;
  final String? termsVersion;
  final bool isActive;
  final Map<String, dynamic>? preferences;
  
  // Additional fields for enhanced functionality
  final String? phone;
  final String? address;
  final GeoPoint? location;
  final int points; // For donors
  final String? marketName; // For donors
  final String? marketAddress; // For donors
  final GeoPoint? marketLocation; // For donors
  final String? fcmToken; // For push notifications
  final bool isOnline;
  final DateTime? lastSeen;

  UserModel({
    required this.id,
    required this.email,
    required this.userType,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.termsAccepted,
    this.termsAcceptedAt,
    this.termsVersion,
    required this.isActive,
    this.preferences,
    this.phone,
    this.address,
    this.location,
    this.points = 0,
    this.marketName,
    this.marketAddress,
    this.marketLocation,
    this.fcmToken,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  return UserModel(
    id: doc.id,
    email: data['email'] ?? '',
    userType: data['userType'] ?? '',
    displayName: data['displayName'] ?? '',
    photoUrl: data['photoUrl'],
    createdAt: data['createdAt'] is Timestamp
      ? (data['createdAt'] as Timestamp).toDate()
      : DateTime.now(),
    updatedAt: data['updatedAt'] is Timestamp
      ? (data['updatedAt'] as Timestamp).toDate()
      : DateTime.now(),
    termsAccepted: data['termsAccepted'] ?? false,
    termsAcceptedAt: data['termsAcceptedAt'] is Timestamp
      ? (data['termsAcceptedAt'] as Timestamp).toDate()
      : null,
    termsVersion: data['termsVersion'],
    isActive: data['isActive'] ?? true,
    preferences: data['preferences'],
    phone: data['phone'],
    address: data['address'],
    location: data['location'] as GeoPoint?,
    points: data['points'] ?? 0,
    marketName: data['marketName'],
    marketAddress: data['marketAddress'],
    marketLocation: data['marketLocation'] as GeoPoint?,
    fcmToken: data['fcmToken'],
    isOnline: data['isOnline'] ?? false,
    lastSeen: data['lastSeen'] is Timestamp
      ? (data['lastSeen'] as Timestamp).toDate()
      : null,
  );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'userType': userType,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'termsAccepted': termsAccepted,
      'termsAcceptedAt': termsAcceptedAt != null 
          ? Timestamp.fromDate(termsAcceptedAt!) 
          : null,
      'termsVersion': termsVersion,
      'isActive': isActive,
      'preferences': preferences,
      'phone': phone,
      'address': address,
      'location': location,
      'points': points,
      'marketName': marketName,
      'marketAddress': marketAddress,
      'marketLocation': marketLocation,
      'fcmToken': fcmToken,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null 
          ? Timestamp.fromDate(lastSeen!) 
          : null,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? userType,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? termsAccepted,
    DateTime? termsAcceptedAt,
    String? termsVersion,
    bool? isActive,
    Map<String, dynamic>? preferences,
    String? phone,
    String? address,
    GeoPoint? location,
    int? points,
    String? marketName,
    String? marketAddress,
    GeoPoint? marketLocation,
    String? fcmToken,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      termsVersion: termsVersion ?? this.termsVersion,
      isActive: isActive ?? this.isActive,
      preferences: preferences ?? this.preferences,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      location: location ?? this.location,
      points: points ?? this.points,
      marketName: marketName ?? this.marketName,
      marketAddress: marketAddress ?? this.marketAddress,
      marketLocation: marketLocation ?? this.marketLocation,
      fcmToken: fcmToken ?? this.fcmToken,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
