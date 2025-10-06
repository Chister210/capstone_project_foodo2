import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert';
import '../models/donation_model.dart';
import '../models/user_model.dart';
import 'background_notification_service.dart';
import 'notification_service.dart';
import 'image_compression_service.dart';
import 'messaging_service.dart';

class DonationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new donation with enhanced parameters
  Future<String> createDonation({
    required String title,
    required String description,
    required File imageFile,
    required DateTime pickupTime,
    required String deliveryType,
    String? address,
    GeoPoint? marketLocation,
    String? marketAddress,
    String? foodType,
    String? quantity,
    List<String>? allergens,
    String? ingredients,
    DateTime? preparationDate,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Convert image to base64 string for local storage
      final imageBase64 = await _convertImageToBase64(imageFile);

      // Create donation document
      final donation = DonationModel(
        id: '', // Will be set by Firestore
        donorId: user.uid,
        donorEmail: user.email ?? '',
        title: title,
        description: description,
        imageUrl: imageBase64, // Store as base64 string
        pickupTime: pickupTime,
        deliveryType: deliveryType,
        status: 'available',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        address: address,
        marketLocation: marketLocation,
        marketAddress: marketAddress,
        foodType: foodType,
        quantity: quantity,
        allergens: allergens,
        donorNotified: false,
        receiverNotified: false,
      );

      final docRef = await _firestore.collection('donations').add(donation.toFirestore());

      // Notify all active receivers with FCM tokens
      try {
        final receiversQuery = await _firestore
            .collection('users')
            .where('userType', isEqualTo: 'receiver')
            .where('isActive', isEqualTo: true)
            .get();
        final receiverIds = receiversQuery.docs
            .where((doc) => (doc.data()['fcmToken'] ?? '').toString().isNotEmpty)
            .map((doc) => doc.id)
            .toList();
        final donorName = user.displayName ?? user.email?.split('@')[0] ?? 'Donor';
        if (receiverIds.isNotEmpty) {
          // FIXED: Use correct method name from NotificationService
          await NotificationService().notifyNewDonationCreated(
            donorId: user.uid,
            donorName: donorName,
            donationId: docRef.id,
            donationTitle: title,
            receiverIds: receiverIds,
          );
        }
      } catch (e) {
        print('Error notifying receivers of new donation: $e');
      }
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create donation: $e');
    }
  }

  // Convert image to base64 string with compression
  Future<String> _convertImageToBase64(File imageFile) async {
    try {
      // Use image compression service for better performance
      return await ImageCompressionService().compressAndEncodeImage(
        imageFile,
        maxWidth: 512,
        maxHeight: 512,
        quality: 80,
      );
    } catch (e) {
      throw Exception('Failed to convert image: $e');
    }
  }

  // Get all available donations (for receivers)
  Stream<List<DonationModel>> getAvailableDonations() {
    return _firestore
        .collection('donations')
        .where('status', isEqualTo: 'available')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DonationModel.fromFirestore(doc))
            .toList());
  }

  // Get donations by donor (for donors)
  Stream<List<DonationModel>> getDonationsByDonor(String donorId) {
    return _firestore
        .collection('donations')
        .where('donorId', isEqualTo: donorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DonationModel.fromFirestore(doc))
            .toList());
  }

  // Get donations claimed by receiver
  Stream<List<DonationModel>> getDonationsByReceiver(String receiverId) {
    return _firestore
        .collection('donations')
        .where('claimedBy', isEqualTo: receiverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DonationModel.fromFirestore(doc))
            .toList());
  }

  // Claim a donation
  Future<void> claimDonation(String donationId, String receiverId) async {
    try {
      // Get donation details
      final donationDoc = await _firestore.collection('donations').doc(donationId).get();
      if (!donationDoc.exists) throw Exception('Donation not found');
      
      final donation = DonationModel.fromFirestore(donationDoc);
      
      // Get receiver details
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) throw Exception('Receiver not found');
      
      final receiverData = receiverDoc.data()!;
      final receiverName = receiverData['displayName'] ?? receiverData['email']?.split('@')[0] ?? 'Receiver';
      
      // Get donor details
      final donorDoc = await _firestore.collection('users').doc(donation.donorId).get();
      if (!donorDoc.exists) throw Exception('Donor not found');
      
      final donorData = donorDoc.data()!;
      final donorName = donorData['displayName'] ?? donorData['email']?.split('@')[0] ?? 'Donor';
      
      // Create chat between donor and receiver
      final MessagingService messagingService = MessagingService();
      final chatId = await messagingService.createChat(
        donationId: donationId,
        donorId: donation.donorId,
        receiverId: receiverId,
        donorName: donorName,
        receiverName: receiverName,
      );
      
      // Update donation with chat ID and claim status
      await _firestore.collection('donations').doc(donationId).update({
        'status': 'claimed',
        'claimedBy': receiverId,
        'claimedAt': FieldValue.serverTimestamp(),
        'chatId': chatId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // FIXED: Use NotificationService instead of local method
      await NotificationService().notifyDonationClaimed(
        donorId: donation.donorId,
        receiverId: receiverId,
        receiverName: receiverName,
        donationId: donationId,
        donationTitle: donation.title,
      );
    } catch (e) {
      throw Exception('Failed to claim donation: $e');
    }
  }

  // Complete a donation
  Future<void> completeDonation(String donationId) async {
    try {
      await _firestore.collection('donations').doc(donationId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Award points to donor and notify
      final donationDoc = await _firestore.collection('donations').doc(donationId).get();
      if (donationDoc.exists) {
        final donation = DonationModel.fromFirestore(donationDoc);
        await _awardPointsToDonor(donation.donorId);
        
        // FIXED: Use NotificationService and include receiver ID
        if (donation.claimedBy != null) {
          await NotificationService().notifyDonationCompleted(
            donorId: donation.donorId,
            receiverId: donation.claimedBy!,
            donationTitle: donation.title,
            pointsAwarded: 10,
          );
        }
      }
    } catch (e) {
      throw Exception('Failed to complete donation: $e');
    }
  }

  // Award points to donor
  Future<void> _awardPointsToDonor(String donorId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(donorId).get();
      if (userDoc.exists) {
        final currentPoints = userDoc.data()?['points'] ?? 0;
        await _firestore.collection('users').doc(donorId).update({
          'points': currentPoints + 10, // Award 10 points per donation
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error awarding points: $e');
    }
  }

  // Update donation status
  Future<void> updateDonationStatus(String donationId, String status) async {
    try {
      await _firestore.collection('donations').doc(donationId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update donation status: $e');
    }
  }

  // Get donation by ID
  Future<DonationModel?> getDonationById(String donationId) async {
    try {
      final doc = await _firestore.collection('donations').doc(donationId).get();
      if (doc.exists) {
        return DonationModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get donation: $e');
    }
  }

  // Update receiver location for tracking
  Future<void> updateReceiverLocation(String donationId, GeoPoint location) async {
    try {
      await _firestore.collection('donations').doc(donationId).update({
        'receiverLocation': location,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update receiver location: $e');
    }
  }

  // Get all donors with market locations
  Stream<List<UserModel>> getDonorsWithLocations() {
    return _firestore
        .collection('users')
        .where('userType', isEqualTo: 'donor')
        .where('marketLocation', isNull: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  // Delete donation
  Future<void> deleteDonation(String donationId) async {
    try {
      // Get donation details before deleting to notify receiver
      final donationDoc = await _firestore.collection('donations').doc(donationId).get();
      if (donationDoc.exists) {
        final donation = DonationModel.fromFirestore(donationDoc);
        
        // Notify receiver if donation was claimed
        if (donation.claimedBy != null && donation.status == 'claimed') {
          await NotificationService().notifyDonationCancelled(
            donorId: donation.donorId,
            receiverId: donation.claimedBy!,
            donationTitle: donation.title,
            cancelledBy: 'donor',
            reason: 'Donation cancelled by donor',
          );
        }
      }
      
      await _firestore.collection('donations').doc(donationId).delete();
    } catch (e) {
      throw Exception('Failed to delete donation: $e');
    }
  }

  // Get real-time notifications for new donations
  Stream<List<DonationModel>> getNewDonationsNotifications() {
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    return _firestore
        .collection('donations')
        .where('status', isEqualTo: 'available')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(oneHourAgo))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DonationModel.fromFirestore(doc))
            .toList());
  }

  // Notify receiver when donation is deleted
  Future<void> notifyDonationDeleted(String donationId, String receiverId, String donationTitle) async {
    try {
      await BackgroundNotificationService().sendNotificationToUser(
        userId: receiverId,
        title: 'Donation Cancelled',
        body: 'The donation "$donationTitle" has been cancelled by the donor.',
        data: {
          'type': 'donation_cancelled',
          'donationId': donationId,
          'donationTitle': donationTitle,
        },
      );
    } catch (e) {
      print('Error sending deletion notification: $e');
    }
  }

  // Notify receiver when donation is updated
  Future<void> notifyDonationUpdated(String donationId, String receiverId, String donationTitle) async {
    try {
      await BackgroundNotificationService().sendNotificationToUser(
        userId: receiverId,
        title: 'Donation Updated',
        body: 'The donation "$donationTitle" has been updated by the donor.',
        data: {
          'type': 'donation_updated',
          'donationId': donationId,
          'donationTitle': donationTitle,
        },
      );
    } catch (e) {
      print('Error sending update notification: $e');
    }
  }

  // Notify donor when donation is claimed (keep as backup/local method)
  Future<void> notifyDonationClaimed(String donorId, String donationTitle, String receiverName) async {
    try {
      await BackgroundNotificationService().sendNotificationToUser(
        userId: donorId,
        title: 'Donation Claimed!',
        body: '$receiverName has claimed your donation: $donationTitle',
        data: {
          'type': 'donation_claimed',
          'receiverName': receiverName,
          'donationTitle': donationTitle,
        },
      );
    } catch (e) {
      print('Error sending claim notification: $e');
    }
  }

  // Notify donor when donation is completed (keep as backup/local method)
  Future<void> notifyDonationCompleted(String donorId, String donationTitle, int pointsAwarded) async {
    try {
      await BackgroundNotificationService().sendNotificationToUser(
        userId: donorId,
        title: 'Donation Completed!',
        body: 'Your donation "$donationTitle" has been completed. You earned $pointsAwarded points!',
        data: {
          'type': 'donation_completed',
          'pointsAwarded': pointsAwarded,
          'donationTitle': donationTitle,
        },
      );
    } catch (e) {
      print('Error sending completion notification: $e');
    }
  }

  // Additional helper method to get nearby receivers
  Future<List<String>> getNearbyReceiverIds(GeoPoint location, double radiusInKm) async {
    try {
      // This is a simplified version - you might want to implement proper geo-queries
      final receiversQuery = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'receiver')
          .where('isActive', isEqualTo: true)
          .get();
      
      return receiversQuery.docs
          .where((doc) => (doc.data()['fcmToken'] ?? '').toString().isNotEmpty)
          .map((doc) => doc.id)
          .toList();
    } catch (e) {
      print('Error getting nearby receiver IDs: $e');
      return [];
    }
  }

  // Refresh donation data
  Future<void> refreshDonation(String donationId) async {
    try {
      // This can be used to force refresh donation data if needed
      final donationDoc = await _firestore.collection('donations').doc(donationId).get();
      if (!donationDoc.exists) {
        throw Exception('Donation not found');
      }
    } catch (e) {
      throw Exception('Failed to refresh donation: $e');
    }
  }
}