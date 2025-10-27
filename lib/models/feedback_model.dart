import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String id;
  final String donationId;
  final String receiverId;
  final String receiverName;
  final String donorId;
  final String donorName;
  final String foodTitle;
  final int rating; // 1-5 stars
  final String comment;
  final List<String> images; // URLs of feedback images
  final DateTime createdAt;
  final bool isVisible; // Whether feedback is visible to all users

  const FeedbackModel({
    required this.id,
    required this.donationId,
    required this.receiverId,
    required this.receiverName,
    required this.donorId,
    required this.donorName,
    required this.foodTitle,
    required this.rating,
    required this.comment,
    required this.images,
    required this.createdAt,
    required this.isVisible,
  });

  // Existing toMap method (unchanged)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'donationId': donationId,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'donorId': donorId,
      'donorName': donorName,
      'foodTitle': foodTitle,
      'rating': rating,
      'comment': comment,
      'images': images,
      'createdAt': Timestamp.fromDate(createdAt),
      'isVisible': isVisible,
    };
  }

  // Existing fromMap method (unchanged)
  factory FeedbackModel.fromMap(Map<String, dynamic> map) {
    return FeedbackModel(
      id: map['id'] ?? '',
      donationId: map['donationId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      donorId: map['donorId'] ?? '',
      donorName: map['donorName'] ?? '',
      foodTitle: map['foodTitle'] ?? '',
      rating: map['rating'] ?? 0,
      comment: map['comment'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isVisible: map['isVisible'] ?? true,
    );
  }

  // NEW: Factory method to create FeedbackModel from Firestore DocumentSnapshot
  factory FeedbackModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    // Set the id from the document ID and delegate to fromMap
    data['id'] = doc.id;
    return FeedbackModel.fromMap(data);
  }

  // Existing copyWith method (unchanged)
  FeedbackModel copyWith({
    String? id,
    String? donationId,
    String? receiverId,
    String? receiverName,
    String? donorId,
    String? donorName,
    String? foodTitle,
    int? rating,
    String? comment,
    List<String>? images,
    DateTime? createdAt,
    bool? isVisible,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      donationId: donationId ?? this.donationId,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      donorId: donorId ?? this.donorId,
      donorName: donorName ?? this.donorName,
      foodTitle: foodTitle ?? this.foodTitle,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}