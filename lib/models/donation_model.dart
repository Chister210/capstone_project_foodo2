import 'package:cloud_firestore/cloud_firestore.dart';

class DonationModel {
  final String id;
  final String donorId;
  final String donorEmail;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime pickupTime;
  final String deliveryType; // 'pickup' or 'delivery'
  final String status; // 'available', 'claimed', 'in_progress', 'completed', 'expired'
  final String? claimedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final GeoPoint? location;
  final String? address;
  final GeoPoint? marketLocation;
  final String? marketAddress;
  final String? receiverLocationId; // For live tracking
  final String? foodType;
  final String? quantity;
  final List<String>? allergens;
  
  // Enhanced fields for messaging and tracking
  final String? chatId; // For messaging between donor and receiver
  final DateTime? claimedAt; // When receiver claimed the donation
  final DateTime? completedAt; // When donation was completed
  final GeoPoint? receiverLocation; // Current receiver location for tracking
  final bool donorNotified; // Whether donor was notified about claim
  final bool receiverNotified; // Whether receiver was notified about completion
  final Map<String, dynamic>? trackingData; // Additional tracking information

  DonationModel({
    required this.id,
    required this.donorId,
    required this.donorEmail,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.pickupTime,
    required this.deliveryType,
    required this.status,
    this.claimedBy,
    required this.createdAt,
    required this.updatedAt,
    this.location,
    this.address,
    this.marketLocation,
    this.marketAddress,
    this.receiverLocationId,
    this.foodType,
    this.quantity,
    this.allergens,
    this.chatId,
    this.claimedAt,
    this.completedAt,
    this.receiverLocation,
    this.donorNotified = false,
    this.receiverNotified = false,
    this.trackingData,
  });

  // Add the hasImage getter
  bool get hasImage => imageUrl.isNotEmpty;

  // Helper getter for allergens that ensures non-null list
  List<String> get allergensList => allergens ?? [];

  factory DonationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return DonationModel(
      id: doc.id,
      donorId: data['donorId'] ?? '',
      donorEmail: data['donorEmail'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      pickupTime: (data['pickupTime'] as Timestamp).toDate(),
      deliveryType: data['deliveryType'] ?? 'pickup',
      status: data['status'] ?? 'available',
      claimedBy: data['claimedBy'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      location: data['location'] as GeoPoint?,
      address: data['address'],
      marketLocation: data['marketLocation'] as GeoPoint?,
      marketAddress: data['marketAddress'],
      receiverLocationId: data['receiverLocationId'],
      foodType: data['foodType'],
      quantity: data['quantity'],
      allergens: data['allergens'] != null ? List<String>.from(data['allergens']) : null,
      chatId: data['chatId'],
      claimedAt: data['claimedAt'] != null ? (data['claimedAt'] as Timestamp).toDate() : null,
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      receiverLocation: data['receiverLocation'] as GeoPoint?,
      donorNotified: data['donorNotified'] ?? false,
      receiverNotified: data['receiverNotified'] ?? false,
      trackingData: data['trackingData'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'donorId': donorId,
      'donorEmail': donorEmail,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'pickupTime': Timestamp.fromDate(pickupTime),
      'deliveryType': deliveryType,
      'status': status,
      'claimedBy': claimedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'location': location,
      'address': address,
      'marketLocation': marketLocation,
      'marketAddress': marketAddress,
      'receiverLocationId': receiverLocationId,
      'foodType': foodType,
      'quantity': quantity,
      'allergens': allergens,
      'chatId': chatId,
      'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'receiverLocation': receiverLocation,
      'donorNotified': donorNotified,
      'receiverNotified': receiverNotified,
      'trackingData': trackingData,
    };
  }

  DonationModel copyWith({
    String? id,
    String? donorId,
    String? donorEmail,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? pickupTime,
    String? deliveryType,
    String? status,
    String? claimedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    GeoPoint? location,
    String? address,
    GeoPoint? marketLocation,
    String? marketAddress,
    String? receiverLocationId,
    String? foodType,
    String? quantity,
    List<String>? allergens,
    String? chatId,
    DateTime? claimedAt,
    DateTime? completedAt,
    GeoPoint? receiverLocation,
    bool? donorNotified,
    bool? receiverNotified,
    Map<String, dynamic>? trackingData,
  }) {
    return DonationModel(
      id: id ?? this.id,
      donorId: donorId ?? this.donorId,
      donorEmail: donorEmail ?? this.donorEmail,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      pickupTime: pickupTime ?? this.pickupTime,
      deliveryType: deliveryType ?? this.deliveryType,
      status: status ?? this.status,
      claimedBy: claimedBy ?? this.claimedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      location: location ?? this.location,
      address: address ?? this.address,
      marketLocation: marketLocation ?? this.marketLocation,
      marketAddress: marketAddress ?? this.marketAddress,
      receiverLocationId: receiverLocationId ?? this.receiverLocationId,
      foodType: foodType ?? this.foodType,
      quantity: quantity ?? this.quantity,
      allergens: allergens ?? this.allergens,
      chatId: chatId ?? this.chatId,
      claimedAt: claimedAt ?? this.claimedAt,
      completedAt: completedAt ?? this.completedAt,
      receiverLocation: receiverLocation ?? this.receiverLocation,
      donorNotified: donorNotified ?? this.donorNotified,
      receiverNotified: receiverNotified ?? this.receiverNotified,
      trackingData: trackingData ?? this.trackingData,
    );
  }
}