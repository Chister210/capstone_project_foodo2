import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_notification.dart';

class DeliveryConfirmationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Mark donation as delivered and send notification to donor
  Future<bool> confirmDelivery(String donationId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get donation details
      final donationDoc = await _firestore
          .collection('donations')
          .doc(donationId)
          .get();

      if (!donationDoc.exists) {
        throw Exception('Donation not found');
      }

      final donationData = donationDoc.data()!;
      final donorId = donationData['donorId'] as String;
      final donorName = donationData['donorName'] as String? ?? 'Donor';
      final receiverName = donationData['receiverName'] as String? ?? 'Receiver';

      // Update donation status to delivered
      await _firestore
          .collection('donations')
          .doc(donationId)
          .update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to donor
      await AppNotification.sendNotification(
        userId: donorId,
        title: 'Donation Received Successfully!',
        body: '$receiverName has confirmed receiving your donation',
        type: 'delivery_confirmed',
        data: {
          'donationId': donationId,
          'receiverName': receiverName,
        },
      );

      return true;
    } catch (e) {
      print('Error confirming delivery: $e');
      return false;
    }
  }

  /// Check if user can confirm delivery for this donation
  Future<bool> canConfirmDelivery(String donationId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final donationDoc = await _firestore
          .collection('donations')
          .doc(donationId)
          .get();

      if (!donationDoc.exists) return false;

      final donationData = donationDoc.data()!;
      final status = donationData['status'] as String?;
      final receiverId = donationData['receiverId'] as String?;

      // Can confirm if status is 'claimed' and current user is the receiver
      return status == 'claimed' && receiverId == currentUser.uid;
    } catch (e) {
      print('Error checking delivery confirmation: $e');
      return false;
    }
  }

  /// Get feedback for a specific donation
  Future<List<Map<String, dynamic>>> getDonationFeedback(String donationId) async {
    try {
      final feedbackSnapshot = await _firestore
          .collection('donations')
          .doc(donationId)
          .collection('feedback')
          .orderBy('timestamp', descending: true)
          .get();

      return feedbackSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'rating': data['rating'] as int? ?? 0,
          'comment': data['comment'] as String? ?? '',
          'receiverName': data['receiverName'] as String? ?? 'Anonymous',
          'timestamp': data['timestamp'] as Timestamp?,
        };
      }).toList();
    } catch (e) {
      print('Error getting donation feedback: $e');
      return [];
    }
  }

  /// Get all feedback for a donor's donations
  Future<List<Map<String, dynamic>>> getDonorFeedback(String donorId) async {
    try {
      // Get all donations by this donor
      final donationsSnapshot = await _firestore
          .collection('donations')
          .where('donorId', isEqualTo: donorId)
          .where('status', isEqualTo: 'delivered')
          .get();

      List<Map<String, dynamic>> allFeedback = [];

      for (final donationDoc in donationsSnapshot.docs) {
        final donationId = donationDoc.id;
        final donationData = donationDoc.data();
        
        // Get feedback for this donation
        final feedbackSnapshot = await _firestore
            .collection('donations')
            .doc(donationId)
            .collection('feedback')
            .get();

        for (final feedbackDoc in feedbackSnapshot.docs) {
          final feedbackData = feedbackDoc.data();
          allFeedback.add({
            'donationId': donationId,
            'donationTitle': donationData['title'] as String? ?? 'Donation',
            'rating': feedbackData['rating'] as int? ?? 0,
            'comment': feedbackData['comment'] as String? ?? '',
            'receiverName': feedbackData['receiverName'] as String? ?? 'Anonymous',
            'timestamp': feedbackData['timestamp'] as Timestamp?,
          });
        }
      }

      // Sort by timestamp (most recent first)
      allFeedback.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return allFeedback;
    } catch (e) {
      print('Error getting donor feedback: $e');
      return [];
    }
  }
}
