import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/feedback_model.dart';

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit feedback for a received donation
  Future<bool> submitFeedback({
    required String donationId,
    required int rating,
    required String comment,
    List<String> images = const [],
    bool isVisible = true,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get donation details
      final donationDoc = await _firestore.collection('donations').doc(donationId).get();
      if (!donationDoc.exists) throw Exception('Donation not found');

      final donationData = donationDoc.data()!;
      final donorId = donationData['donorId'];
      final donorName = donationData['donorName'] ?? 'Donor';
      final foodTitle = donationData['title'];

      // Get receiver details
      final receiverDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!receiverDoc.exists) throw Exception('Receiver not found');

      final receiverData = receiverDoc.data()!;
      final receiverName = receiverData['displayName'] ?? 'Receiver';

      // Create feedback
      final feedbackId = _firestore.collection('feedback').doc().id;
      final feedback = FeedbackModel(
        id: feedbackId,
        donationId: donationId,
        receiverId: user.uid,
        receiverName: receiverName,
        donorId: donorId,
        donorName: donorName,
        foodTitle: foodTitle,
        rating: rating,
        comment: comment,
        images: images,
        createdAt: DateTime.now(),
        isVisible: isVisible,
      );

      await _firestore.collection('feedback').doc(feedbackId).set(feedback.toMap());

      // Update donation with feedback status
      await _firestore.collection('donations').doc(donationId).update({
        'hasFeedback': true,
        'feedbackId': feedbackId,
        'feedbackRating': rating,
      });

      print('✅ Feedback submitted successfully');
      return true;
    } catch (e) {
      print('❌ Error submitting feedback: $e');
      return false;
    }
  }

  /// Get all visible feedback
  Stream<List<FeedbackModel>> getAllFeedback() {
    return _firestore
        .collection('feedback')
        .where('isVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeedbackModel.fromMap(doc.data()))
            .toList());
  }

  /// Get feedback for a specific donation
  Future<FeedbackModel?> getFeedbackForDonation(String donationId) async {
    try {
      final snapshot = await _firestore
          .collection('feedback')
          .where('donationId', isEqualTo: donationId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return FeedbackModel.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('❌ Error getting feedback for donation: $e');
      return null;
    }
  }

  /// Get feedback by receiver
  Stream<List<FeedbackModel>> getFeedbackByReceiver(String receiverId) {
    return _firestore
        .collection('feedback')
        .where('receiverId', isEqualTo: receiverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeedbackModel.fromMap(doc.data()))
            .toList());
  }

  /// Get feedback by donor
  Stream<List<FeedbackModel>> getFeedbackByDonor(String donorId) {
    return _firestore
        .collection('feedback')
        .where('donorId', isEqualTo: donorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeedbackModel.fromMap(doc.data()))
            .toList());
  }

  /// Update feedback visibility
  Future<bool> updateFeedbackVisibility(String feedbackId, bool isVisible) async {
    try {
      await _firestore.collection('feedback').doc(feedbackId).update({
        'isVisible': isVisible,
      });
      return true;
    } catch (e) {
      print('❌ Error updating feedback visibility: $e');
      return false;
    }
  }

  /// Delete feedback
  Future<bool> deleteFeedback(String feedbackId) async {
    try {
      await _firestore.collection('feedback').doc(feedbackId).delete();
      return true;
    } catch (e) {
      print('❌ Error deleting feedback: $e');
      return false;
    }
  }

  /// Get average rating for a donor
  Future<double> getDonorAverageRating(String donorId) async {
    try {
      final snapshot = await _firestore
          .collection('feedback')
          .where('donorId', isEqualTo: donorId)
          .where('isVisible', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      final ratings = snapshot.docs
          .map((doc) => doc.data()['rating'] as int)
          .toList();

      return ratings.reduce((a, b) => a + b) / ratings.length;
    } catch (e) {
      print('❌ Error getting average rating: $e');
      return 0.0;
    }
  }

  /// Get feedback statistics
  Future<Map<String, dynamic>> getFeedbackStats() async {
    try {
      final snapshot = await _firestore
          .collection('feedback')
          .where('isVisible', isEqualTo: true)
          .get();

      final feedbacks = snapshot.docs.map((doc) => doc.data()).toList();

      if (feedbacks.isEmpty) {
        return {
          'totalFeedback': 0,
          'averageRating': 0.0,
          'ratingDistribution': {},
        };
      }

      final ratings = feedbacks.map((f) => f['rating'] as int).toList();
      final averageRating = ratings.reduce((a, b) => a + b) / ratings.length;

      // Rating distribution
      final Map<int, int> ratingDistribution = {};
      for (final rating in ratings) {
        ratingDistribution[rating] = (ratingDistribution[rating] ?? 0) + 1;
      }

      return {
        'totalFeedback': feedbacks.length,
        'averageRating': averageRating,
        'ratingDistribution': ratingDistribution,
      };
    } catch (e) {
      print('❌ Error getting feedback stats: $e');
      return {
        'totalFeedback': 0,
        'averageRating': 0.0,
        'ratingDistribution': {},
      };
    }
  }
}
