import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/feedback_model.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Submit feedback for a donation
  Future<void> submitFeedback({
    required String donationId,
    required String donorId,
    required int rating,
    String? comment,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if feedback already exists for this donation and receiver
      final existingFeedback = await _firestore
          .collection('feedback')
          .where('donationId', isEqualTo: donationId)
          .where('receiverId', isEqualTo: user.uid)
          .limit(1)
          .get();

      // Get receiver name
      final receiverDoc = await _firestore.collection('users').doc(user.uid).get();
      final receiverData = receiverDoc.exists ? receiverDoc.data()! : {};
      final receiverName = receiverData['displayName'] ?? 
                          receiverData['email']?.split('@')[0] ?? 
                          'Receiver';

      if (existingFeedback.docs.isNotEmpty) {
        // Update existing feedback
        final feedbackId = existingFeedback.docs.first.id;
        await _firestore.collection('feedback').doc(feedbackId).update({
          'rating': rating,
          'comment': comment,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new feedback
        final feedback = FeedbackModel(
          id: '', // Will be set by Firestore
          donationId: donationId,
          donorId: donorId,
          receiverId: user.uid,
          receiverName: receiverName,
          rating: rating,
          comment: comment,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore.collection('feedback').add(feedback.toFirestore());
      }
    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }

  // Get all feedback for a specific donor
  Stream<List<FeedbackModel>> getFeedbackForDonor(String donorId) {
    return _firestore
        .collection('feedback')
        .where('donorId', isEqualTo: donorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeedbackModel.fromFirestore(doc))
            .toList());
  }

  // Get feedback for a specific donation
  Future<FeedbackModel?> getFeedbackForDonation(String donationId, String receiverId) async {
    try {
      final feedbackDocs = await _firestore
          .collection('feedback')
          .where('donationId', isEqualTo: donationId)
          .where('receiverId', isEqualTo: receiverId)
          .limit(1)
          .get();

      if (feedbackDocs.docs.isNotEmpty) {
        return FeedbackModel.fromFirestore(feedbackDocs.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Calculate average rating for a donor
  Future<double> getAverageRating(String donorId) async {
    try {
      final feedbackDocs = await _firestore
          .collection('feedback')
          .where('donorId', isEqualTo: donorId)
          .get();

      if (feedbackDocs.docs.isEmpty) return 0.0;

      double totalRating = 0;
      for (var doc in feedbackDocs.docs) {
        final data = doc.data();
        totalRating += (data['rating'] as int).toDouble();
      }

      return totalRating / feedbackDocs.docs.length;
    } catch (e) {
      return 0.0;
    }
  }

  // Get total review count for a donor
  Future<int> getReviewCount(String donorId) async {
    try {
      final feedbackDocs = await _firestore
          .collection('feedback')
          .where('donorId', isEqualTo: donorId)
          .get();

      return feedbackDocs.docs.length;
    } catch (e) {
      return 0;
    }
  }
}

