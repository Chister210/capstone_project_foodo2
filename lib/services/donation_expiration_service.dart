import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/donation_model.dart';
import 'app_notification.dart';

class DonationExpirationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check and delete expired unclaimed donations
  Future<void> checkAndDeleteExpiredDonations() async {
    try {
      final now = Timestamp.now();
      
      // Find all donations that:
      // 1. Have an expirationDateTime
      // 2. Are expired (expirationDateTime < now)
      // 3. Are still available (not claimed or completed)
      final expiredDonations = await _firestore
          .collection('donations')
          .where('expirationDateTime', isLessThan: now)
          .where('status', isEqualTo: 'available')
          .get();

      for (var doc in expiredDonations.docs) {
        final donation = DonationModel.fromFirestore(doc);
        
        // Only delete if donation hasn't been claimed (no claims at all)
        final hasClaims = donation.claimedBy != null || 
                         (donation.quantityClaims != null && donation.quantityClaims!.isNotEmpty);
        
        if (!hasClaims) {
          // Get all receivers who might have viewed this donation
          // For simplicity, we'll notify all active receivers
          final receiversQuery = await _firestore
              .collection('users')
              .where('userType', isEqualTo: 'receiver')
              .get();
          
          final receiverIds = receiversQuery.docs
              .where((doc) => (doc.data()['fcmToken'] ?? '').toString().isNotEmpty)
              .map((doc) => doc.id)
              .toList();

          // Notify receivers
          for (final receiverId in receiverIds) {
            await AppNotification.send(
              AppNotification(
                userId: receiverId,
                title: 'Donation Expired',
                message: 'The donation "${donation.title}" has expired and was not claimed.',
                type: 'donation_expired',
                data: {
                  'donationId': donation.id,
                  'donationTitle': donation.title,
                },
              ),
            );
          }

          // Notify donor
          await AppNotification.send(
            AppNotification(
              userId: donation.donorId,
              title: 'Donation Expired',
              message: 'Your donation "${donation.title}" has expired and was not claimed. It has been removed.',
              type: 'donation_expired',
              data: {
                'donationId': donation.id,
                'donationTitle': donation.title,
              },
            ),
          );

          // Delete the donation
          await _firestore.collection('donations').doc(donation.id).delete();
          
          print('Deleted expired donation: ${donation.id} - ${donation.title}');
        }
      }
    } catch (e) {
      print('Error checking expired donations: $e');
    }
  }

  // Check if a donation is expired
  bool isDonationExpired(DonationModel donation) {
    if (donation.expirationDateTime == null) return false;
    return DateTime.now().isAfter(donation.expirationDateTime!);
  }

  // Get time remaining until expiration
  Duration? getTimeUntilExpiration(DonationModel donation) {
    if (donation.expirationDateTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(donation.expirationDateTime!)) {
      return Duration.zero; // Already expired
    }
    return donation.expirationDateTime!.difference(now);
  }
}

