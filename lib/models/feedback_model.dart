import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String id;
  final String donationId;
  final String donorId;
  final String receiverId;
  final String receiverName;
  final int rating; // 1-5 stars
  final String? comment; // Optional feedback text
  final DateTime createdAt;
  final DateTime updatedAt;

  FeedbackModel({
    required this.id,
    required this.donationId,
    required this.donorId,
    required this.receiverId,
    required this.receiverName,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert from Firestore document
  factory FeedbackModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedbackModel(
      id: doc.id,
      donationId: data['donationId'] as String,
      donorId: data['donorId'] as String,
      receiverId: data['receiverId'] as String,
      receiverName: data['receiverName'] as String,
      rating: data['rating'] as int,
      comment: data['comment'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'donationId': donationId,
      'donorId': donorId,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create a copy with updated fields
  FeedbackModel copyWith({
    String? id,
    String? donationId,
    String? donorId,
    String? receiverId,
    String? receiverName,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      donationId: donationId ?? this.donationId,
      donorId: donorId ?? this.donorId,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

