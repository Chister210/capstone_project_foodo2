import 'package:cloud_firestore/cloud_firestore.dart';

class DonationModel {
  final String id;
  final String donorId;
  final String donorEmail;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime pickupTime;
  final DateTime? expirationDateTime; // Date and time when donation expires (can no longer be claimed)
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
  final String? foodCategory; // New field for food category
  final String? quantity; // Original quantity string (e.g., "10 kg", "5 boxes")
  final int? totalQuantity; // Parsed total quantity as integer
  final int claimedQuantity; // Total quantity claimed so far
  final int? remainingQuantity; // Remaining quantity available
  final Map<String, int>? quantityClaims; // Map of receiverId -> quantity claimed by each receiver
  final String? specification; // New field for donation specification
  final int? maxRecipients; // New field for maximum number of recipients
  final List<String>? allergens;
  
  // Enhanced fields for messaging and tracking
  final String? chatId; // For messaging between donor and receiver
  final DateTime? claimedAt; // When receiver claimed the donation
  final DateTime? completedAt; // When donation was completed
  final GeoPoint? receiverLocation; // Current receiver location for tracking
  final bool donorNotified; // Whether donor was notified about claim
  final bool receiverNotified; // Whether receiver was notified about completion
  final Map<String, dynamic>? trackingData; // Additional tracking information
  
  // Confirmation fields for donation completion (per receiver)
  final Map<String, bool>? receiverConfirmations; // Map of receiverId -> whether they confirmed the donation
  final Map<String, bool>? donorConfirmations; // Map of receiverId -> whether donor confirmed for that receiver
  final Map<String, DateTime>? receiverConfirmedAt; // Map of receiverId -> when they confirmed
  final Map<String, DateTime>? donorConfirmedAt; // Map of receiverId -> when donor confirmed for that receiver
  

  DonationModel({
    required this.id,
    required this.donorId,
    required this.donorEmail,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.pickupTime,
    this.expirationDateTime,
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
    this.foodCategory,
    this.quantity,
    this.totalQuantity,
    this.claimedQuantity = 0,
    this.remainingQuantity,
    this.quantityClaims,
    this.specification,
    this.maxRecipients,
    this.allergens,
    this.chatId,
    this.claimedAt,
    this.completedAt,
    this.receiverLocation,
    this.donorNotified = false,
    this.receiverNotified = false,
    this.trackingData,
    this.receiverConfirmations,
    this.donorConfirmations,
    this.receiverConfirmedAt,
    this.donorConfirmedAt,
  });

  // Add the hasImage getter
  bool get hasImage => imageUrl.isNotEmpty;

  // Helper getter for allergens that ensures non-null list
  List<String> get allergensList => allergens ?? [];

  // Helper method to parse boolean maps (handles both old single bool and new Map format)
  static Map<String, bool>? _parseBooleanMap(dynamic boolData) {
    if (boolData == null) return null;
    
    // If it's a Map (new format)
    if (boolData is Map) {
      return Map<String, bool>.from(boolData.map((k, v) => MapEntry(k.toString(), v == true)));
    }
    
    // If it's a single bool (old format - backward compatibility)
    if (boolData is bool) {
      // Return null for old format (we can't determine which receiver)
      return null;
    }
    
    return null;
  }

  // Helper method to parse timestamp maps (handles both old single Timestamp and new Map format)
  static Map<String, DateTime>? _parseTimestampMap(dynamic timestampData) {
    if (timestampData == null) return null;
    
    // If it's a Map (new format)
    if (timestampData is Map) {
      return Map<String, DateTime>.from(timestampData.map((k, v) => MapEntry(
        k.toString(),
        v is Timestamp ? v.toDate() : (v is DateTime ? v : DateTime.now())
      )));
    }
    
    // If it's a single Timestamp (old format - backward compatibility)
    if (timestampData is Timestamp) {
      // Return null for old format (we can't determine which receiver)
      return null;
    }
    
    return null;
  }

  factory DonationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return DonationModel(
      id: doc.id,
      donorId: data['donorId'] ?? '',
      donorEmail: data['donorEmail'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      pickupTime: data['pickupTime'] != null
          ? (data['pickupTime'] is Timestamp
              ? (data['pickupTime'] as Timestamp).toDate()
              : DateTime.now().add(const Duration(hours: 1)))
          : DateTime.now().add(const Duration(hours: 1)),
      deliveryType: data['deliveryType'] ?? 'pickup',
      status: data['status'] ?? 'available',
      claimedBy: data['claimedBy'],
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] is Timestamp
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
      location: data['location'] as GeoPoint?,
      address: data['address'],
      marketLocation: data['marketLocation'] as GeoPoint?,
      marketAddress: data['marketAddress'],
      receiverLocationId: data['receiverLocationId'],
      foodType: data['foodType'],
      foodCategory: data['foodCategory'],
      quantity: data['quantity'],
      totalQuantity: data['totalQuantity'],
      claimedQuantity: data['claimedQuantity'] ?? 0,
      remainingQuantity: data['remainingQuantity'],
      quantityClaims: data['quantityClaims'] != null 
          ? Map<String, int>.from(data['quantityClaims'].map((k, v) => MapEntry(k.toString(), v is int ? v : int.tryParse(v.toString()) ?? 0)))
          : null,
      specification: data['specification'],
      maxRecipients: data['maxRecipients'],
      allergens: data['allergens'] != null ? List<String>.from(data['allergens']) : null,
      chatId: data['chatId'],
      claimedAt: data['claimedAt'] != null 
          ? (data['claimedAt'] is Timestamp 
              ? (data['claimedAt'] as Timestamp).toDate() 
              : (data['claimedAt'] as Timestamp?)?.toDate())
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] is Timestamp
              ? (data['completedAt'] as Timestamp).toDate()
              : (data['completedAt'] as Timestamp?)?.toDate())
          : null,
      receiverLocation: data['receiverLocation'] as GeoPoint?,
      donorNotified: data['donorNotified'] ?? false,
      receiverNotified: data['receiverNotified'] ?? false,
      trackingData: data['trackingData'],
      receiverConfirmations: _parseBooleanMap(data['receiverConfirmations']),
      donorConfirmations: _parseBooleanMap(data['donorConfirmations']),
      receiverConfirmedAt: data['receiverConfirmedAt'] != null
          ? _parseTimestampMap(data['receiverConfirmedAt'])
          : null,
      donorConfirmedAt: data['donorConfirmedAt'] != null
          ? _parseTimestampMap(data['donorConfirmedAt'])
          : null,
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
      'expirationDateTime': expirationDateTime != null ? Timestamp.fromDate(expirationDateTime!) : null,
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
      'foodCategory': foodCategory,
      'quantity': quantity,
      'totalQuantity': totalQuantity,
      'claimedQuantity': claimedQuantity,
      'remainingQuantity': remainingQuantity,
      'quantityClaims': quantityClaims,
      'specification': specification,
      'maxRecipients': maxRecipients,
      'allergens': allergens,
      'chatId': chatId,
      'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'receiverLocation': receiverLocation,
      'donorNotified': donorNotified,
      'receiverNotified': receiverNotified,
      'trackingData': trackingData,
      'receiverConfirmations': receiverConfirmations,
      'donorConfirmations': donorConfirmations,
      'receiverConfirmedAt': receiverConfirmedAt != null
          ? Map<String, Timestamp>.from(receiverConfirmedAt!.map((k, v) => MapEntry(k, Timestamp.fromDate(v))))
          : null,
      'donorConfirmedAt': donorConfirmedAt != null
          ? Map<String, Timestamp>.from(donorConfirmedAt!.map((k, v) => MapEntry(k, Timestamp.fromDate(v))))
          : null,
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
    DateTime? expirationDateTime,
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
    int? totalQuantity,
    int? claimedQuantity,
    int? remainingQuantity,
    Map<String, int>? quantityClaims,
    List<String>? allergens,
    String? chatId,
    DateTime? claimedAt,
    DateTime? completedAt,
    GeoPoint? receiverLocation,
    bool? donorNotified,
    bool? receiverNotified,
    Map<String, dynamic>? trackingData,
    Map<String, bool>? receiverConfirmations,
    Map<String, bool>? donorConfirmations,
    Map<String, DateTime>? receiverConfirmedAt,
    Map<String, DateTime>? donorConfirmedAt,
  }) {
    return DonationModel(
      id: id ?? this.id,
      donorId: donorId ?? this.donorId,
      donorEmail: donorEmail ?? this.donorEmail,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      pickupTime: pickupTime ?? this.pickupTime,
      expirationDateTime: expirationDateTime ?? this.expirationDateTime,
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
      totalQuantity: totalQuantity ?? this.totalQuantity,
      claimedQuantity: claimedQuantity ?? this.claimedQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      quantityClaims: quantityClaims ?? this.quantityClaims,
      allergens: allergens ?? this.allergens,
      chatId: chatId ?? this.chatId,
      claimedAt: claimedAt ?? this.claimedAt,
      completedAt: completedAt ?? this.completedAt,
      receiverLocation: receiverLocation ?? this.receiverLocation,
      donorNotified: donorNotified ?? this.donorNotified,
      receiverNotified: receiverNotified ?? this.receiverNotified,
      trackingData: trackingData ?? this.trackingData,
      receiverConfirmations: receiverConfirmations ?? this.receiverConfirmations,
      donorConfirmations: donorConfirmations ?? this.donorConfirmations,
      receiverConfirmedAt: receiverConfirmedAt ?? this.receiverConfirmedAt,
      donorConfirmedAt: donorConfirmedAt ?? this.donorConfirmedAt,
    );
  }
  
  // Helper getter to check if all quantities are claimed
  bool get isFullyConfirmed {
    // For donations with quantity tracking, check remaining quantity
    if (totalQuantity != null && totalQuantity! > 0) {
      // If there's remaining quantity, donation is not fully confirmed
      return (remainingQuantity ?? 0) <= 0;
    }
    
    return true;
  }
  
  // Helper getter to check if donation is fully claimed (no remaining quantity)
  bool get isFullyClaimed {
    if (totalQuantity == null) return false;
    return (remainingQuantity ?? 0) <= 0;
  }
  
  // Helper getter to check if donation has partial claims
  bool get hasPartialClaims => claimedQuantity > 0 && !isFullyClaimed;
  
  // Helper method to parse quantity string to integer
  static int? parseQuantityString(String? quantityStr) {
    if (quantityStr == null || quantityStr.isEmpty) return null;
    // Extract numbers from string (e.g., "10 kg" -> 10, "5 boxes" -> 5)
    final match = RegExp(r'(\d+)').firstMatch(quantityStr);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }
}