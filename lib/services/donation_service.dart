import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/donation_model.dart';
import '../models/user_model.dart';
import 'app_notification.dart';
import 'image_compression_service.dart';
import 'messaging_service.dart';
import 'certificate_service.dart';

class DonationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new donation with enhanced parameters
  Future<String> createDonation({
    required String title,
    required String description,
    required File imageFile,
    required DateTime pickupTime,
    DateTime? expirationDateTime,
    required String deliveryType,
    String? address,
    GeoPoint? marketLocation,
    String? marketAddress,
    String? foodType,
    String? foodCategory,
    String? quantity,
    String? specification,
    int? maxRecipients,
    List<String>? allergens,
    String? ingredients,
    DateTime? preparationDate,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Convert image to base64 string for local storage
      final imageBase64 = await _convertImageToBase64(imageFile);

      // Parse quantity to integer if available
      final totalQuantityInt = quantity != null 
          ? DonationModel.parseQuantityString(quantity) 
          : null;
      
      // Create donation document
      final donation = DonationModel(
        id: '', // Will be set by Firestore
        donorId: user.uid,
        donorEmail: user.email ?? '',
        title: title,
        description: description,
        imageUrl: imageBase64, // Store as base64 string
        pickupTime: pickupTime,
        expirationDateTime: expirationDateTime,
        deliveryType: deliveryType,
        status: 'available',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        address: address,
        marketLocation: marketLocation,
        marketAddress: marketAddress,
        foodType: foodType,
        foodCategory: foodCategory,
        quantity: quantity,
        totalQuantity: totalQuantityInt,
        claimedQuantity: 0,
        remainingQuantity: totalQuantityInt,
        quantityClaims: null,
        specification: specification,
        maxRecipients: maxRecipients,
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
            .get();
        final receiverIds = receiversQuery.docs
            .where((doc) => (doc.data()['fcmToken'] ?? '').toString().isNotEmpty)
            .map((doc) => doc.id)
            .toList();
        // Get market name for donor (prefer marketName over displayName)
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        String donorName = 'Donor';
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          donorName = userData['marketName'] ?? userData['displayName'] ?? user.email?.split('@')[0] ?? 'Donor';
        }
        
        print('Found ${receiverIds.length} receivers with FCM tokens');
        print('Receiver IDs: $receiverIds');
        
        if (receiverIds.isNotEmpty) {
          for (final receiverId in receiverIds) {
            await AppNotification.send(
              AppNotification(
                userId: receiverId,
                title: 'New Donation Available!',
                message: '$donorName has posted: "$title"',
                type: 'new_donation',
                data: {
                  'donationId': docRef.id,
                  'donorName': donorName,
                  'donationTitle': title,
                },
              ),
            );
          }
          print('✅ Notifications sent to ${receiverIds.length} receivers');
        } else {
          print('⚠️ No receivers found to notify');
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
  // Includes donations that are available OR have remaining quantity (partial claims)
  Stream<List<DonationModel>> getAvailableDonations() {
    return _firestore
        .collection('donations')
        .where('status', isEqualTo: 'available')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncExpand((availableSnapshot) async* {
          // Get all donations with remaining quantity
          final partialSnapshot = await _firestore
              .collection('donations')
              .where('remainingQuantity', isGreaterThan: 0)
              .get();
          
          final allDonations = <String, DonationModel>{};
          
          // Add available donations
          for (final doc in availableSnapshot.docs) {
            final donation = DonationModel.fromFirestore(doc);
            allDonations[donation.id] = donation;
          }
          
          // Add donations with remaining quantity (even if status is 'claimed')
          for (final doc in partialSnapshot.docs) {
            final donation = DonationModel.fromFirestore(doc);
            // Add if has remaining quantity and not completed
            if ((donation.remainingQuantity ?? 0) > 0 &&
                donation.status != 'completed') {
              allDonations[donation.id] = donation;
            }
          }
          
          // Filter and sort
          final now = DateTime.now();
          final filtered = allDonations.values.where((donation) {
            // Filter out expired donations
            if (donation.expirationDateTime != null) {
              if (now.isAfter(donation.expirationDateTime!)) {
                return false; // Donation has expired
              }
            }
            
            // Show if status is available
            if (donation.status == 'available') return true;
            
            // Show if has remaining quantity and not completed
            if (donation.totalQuantity != null) {
              final remaining = donation.remainingQuantity ?? donation.totalQuantity ?? 0;
              return remaining > 0 && donation.status != 'completed';
            }
            
            // For donations without quantity tracking, only show if available
            return donation.status == 'available';
          }).toList();
          
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          yield filtered;
        });
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

  Future<void> notifyDonationUpdated(String donationId, String receiverId, String title) async {
    try {
      // Get receiver details for personalized notification
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) throw Exception('Receiver not found');
      
      final receiverData = receiverDoc.data()!;
      final receiverName = receiverData['displayName'] ?? receiverData['email']?.split('@')[0] ?? 'Receiver';

      // Send in-app notification to the receiver
      await AppNotification.send(
        AppNotification(
          userId: receiverId,
          title: 'Donation Updated',
          message: 'The donation "$title" has been updated by the donor. Please check the details.',
          type: 'donation_updated',
          data: {
            'donationId': donationId,
            'updatedTitle': title,
          },
        ),
      );

      print('✅ Notification sent to receiver $receiverId for updated donation: $title');
    } catch (e) {
      print('Error notifying donation update: $e');
      rethrow;
    }
  }

  Future<void> notifyDonationDeleted(String donationId, String receiverId, String title) async {
    try {
      // Get receiver details for personalized notification
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) throw Exception('Receiver not found');
      
      final receiverData = receiverDoc.data()!;
      final receiverName = receiverData['displayName'] ?? receiverData['email']?.split('@')[0] ?? 'Receiver';

      // Send in-app notification to the receiver
      await AppNotification.send(
        AppNotification(
          userId: receiverId,
          title: 'Donation Cancelled ❌',
          message: 'The donation "$title" has been cancelled by the donor.',
          type: 'donation_cancelled',
          data: {
            'donationId': donationId,
            'reason': 'Cancelled by donor',
          },
        ),
      );

      print('✅ Notification sent to receiver $receiverId for cancelled donation: $title');
    } catch (e) {
      print('Error notifying donation deletion: $e');
      rethrow;
    }
  }

  // Claim a donation (with optional quantity for partial claims)
  Future<void> claimDonation(String donationId, String receiverId, {int? claimQuantity}) async {
    try {
      // Get donation details
      final donationDoc = await _firestore.collection('donations').doc(donationId).get();
      if (!donationDoc.exists) throw Exception('Donation not found');
      
      final donation = DonationModel.fromFirestore(donationDoc);
      
      // Check if donation has quantity-based claiming
      final hasQuantity = donation.totalQuantity != null && donation.totalQuantity! > 0;
      
      // If no quantity specified but donation has quantity, require quantity selection
      if (hasQuantity && claimQuantity == null) {
        throw Exception('Please specify the quantity you want to claim');
      }
      
      // If quantity specified, validate it
      if (hasQuantity && claimQuantity != null) {
        final remaining = donation.remainingQuantity ?? donation.totalQuantity ?? 0;
        if (claimQuantity <= 0) {
          throw Exception('Quantity must be greater than 0');
        }
        if (claimQuantity > remaining) {
          throw Exception('Requested quantity ($claimQuantity) exceeds available quantity ($remaining)');
        }
      }
      
      // Get receiver details
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) throw Exception('Receiver not found');
      
      final receiverData = receiverDoc.data()!;
      final receiverName = receiverData['displayName'] ?? receiverData['email']?.split('@')[0] ?? 'Receiver';
      
      // Get donor details (use marketName instead of displayName)
      final donorDoc = await _firestore.collection('users').doc(donation.donorId).get();
      if (!donorDoc.exists) throw Exception('Donor not found');
      
      final donorData = donorDoc.data()!;
      final donorName = donorData['marketName'] ?? donorData['displayName'] ?? donorData['email']?.split('@')[0] ?? 'Donor';
      
      // Calculate new quantities
      final currentClaimedQuantity = donation.claimedQuantity;
      final currentRemainingQuantity = donation.remainingQuantity ?? donation.totalQuantity ?? 0;
      final newClaimedQuantity = hasQuantity && claimQuantity != null
          ? currentClaimedQuantity + claimQuantity
          : currentClaimedQuantity;
      final newRemainingQuantity = hasQuantity && claimQuantity != null
          ? currentRemainingQuantity - claimQuantity
          : currentRemainingQuantity;
      
      // Update quantity claims map
      final currentClaims = Map<String, int>.from(donation.quantityClaims ?? {});
      final isAdditionalClaim = hasQuantity && claimQuantity != null && currentClaims.containsKey(receiverId);
      
      if (hasQuantity && claimQuantity != null) {
        currentClaims[receiverId] = (currentClaims[receiverId] ?? 0) + claimQuantity;
      }
      
      // Determine if donation should be marked as claimed (only when remaining is 0)
      final isFullyClaimed = hasQuantity && newRemainingQuantity <= 0;
      final newStatus = isFullyClaimed ? 'claimed' : donation.status;
      
      // Create chat between donor and receiver (each receiver-donor pair gets unique chat)
      // Check if chat already exists for this specific receiver-donor pair
      final MessagingService messagingService = MessagingService();
      final expectedChatId = '${donation.donorId}_${receiverId}_$donationId';
      
      // Check if chat document exists
      final chatDoc = await _firestore.collection('chats').doc(expectedChatId).get();
      String? chatId;
      
      if (!chatDoc.exists) {
        // Create new chat for this specific receiver-donor pair
        chatId = await messagingService.createChat(
          donationId: donationId,
          donorId: donation.donorId,
          receiverId: receiverId,
          donorName: donorName,
          receiverName: receiverName,
        );
      } else {
        // Chat already exists for this pair
        chatId = expectedChatId;
      }
      
      // If user is claiming additional quantity, reset their confirmation status
      // so they need to confirm the new transaction separately
      final currentConfirmations = Map<String, bool>.from(
        (donationDoc.data()?['receiverConfirmations'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v == true))
      );
      
      // Prepare update data
      final updateData = <String, dynamic>{
        if (hasQuantity) 'claimedQuantity': newClaimedQuantity,
        if (hasQuantity) 'remainingQuantity': newRemainingQuantity,
        if (hasQuantity) 'quantityClaims': currentClaims,
        if (isFullyClaimed) 'status': 'claimed',
        if (donation.claimedBy == null || donation.claimedBy!.isEmpty) 'claimedBy': receiverId, // Set first claimer
        if (donation.claimedAt == null) 'claimedAt': FieldValue.serverTimestamp(),
        // Store chatId only if it's the first claim (for backward compatibility)
        if (donation.chatId == null) 'chatId': chatId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Reset confirmation for this receiver if they're claiming additional quantity
      // This ensures they need to confirm the new transaction separately
      if (isAdditionalClaim) {
        // Reset this user's confirmation status for the new claim
        currentConfirmations[receiverId] = false;
        updateData['receiverConfirmations'] = currentConfirmations;
        // Also reset the overall receiverConfirmed flag if all confirmations are false
        if (currentConfirmations.values.every((confirmed) => !confirmed)) {
          updateData['receiverConfirmed'] = false;
        }
      }
      
      // Update donation with quantities and status
      await _firestore.collection('donations').doc(donationId).update(updateData);
      
      // Notify donor about claim
      final quantityText = hasQuantity && claimQuantity != null
          ? '$claimQuantity of ${donation.totalQuantity}'
          : 'all';
      final remainingText = hasQuantity && newRemainingQuantity > 0
          ? ' ($newRemainingQuantity remaining)'
          : '';
      
      await AppNotification.send(
        AppNotification(
          userId: donation.donorId,
          title: 'Donation Claimed!',
          message: '$receiverName claimed $quantityText of "${donation.title}"$remainingText',
          type: 'donation_claimed',
          data: {
            'donationId': donationId,
            'receiverId': receiverId,
            'receiverName': receiverName,
            'donationTitle': donation.title,
            'claimedQuantity': claimQuantity?.toString(),
            'remainingQuantity': newRemainingQuantity.toString(),
            'chatId': chatId, // Include specific chatId for this receiver-donor pair
          },
        ),
      );
    } catch (e) {
      throw Exception('Failed to claim donation: $e');
    }
  }

  // Finalize completion and award points
  Future<void> _finalizeCompletionAndAwardPoints(String donationId, DonationModel donation) async {
    try {
      // IMPORTANT: Only mark as completed if remainingQuantity is 0 or null
      // If there's remaining quantity, this is a partial completion and donation should remain available
      final remainingQty = donation.remainingQuantity ?? 0;
      
      if (remainingQty > 0) {
        print('⚠️ Donation has remaining quantity ($remainingQty). Not marking as completed yet.');
        // Don't mark as completed if there's remaining quantity
        // Just notify the current receiver-donor pair about their portion completion
        // But donation remains available for others to claim remaining quantity
        final updatedDonationDoc = await _firestore.collection('donations').doc(donationId).get();
        final updatedDonation = DonationModel.fromFirestore(updatedDonationDoc);
        
        // Notify receivers about their portion completion
        if (donation.claimedBy != null) {
          await AppNotification.send(
            AppNotification(
              userId: donation.claimedBy!,
              title: 'Your Portion Completed!',
              message: 'Your portion of "${donation.title}" has been completed. The donation still has $remainingQty remaining.',
              type: 'donation_completed',
              data: {
                'donationId': donationId,
                'chatId': donation.chatId,
              },
            ),
          );
        }
        return; // Exit early - don't finalize completion
      }
      
      // Only mark donation as completed if no remaining quantity
      await _firestore.collection('donations').doc(donationId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Award points to donor (10 points per donation)
      const pointsAwarded = 10;
      final userDoc = await _firestore.collection('users').doc(donation.donorId).get();
      if (userDoc.exists) {
        final currentPoints = userDoc.data()?['points'] ?? 0;
        final newPoints = currentPoints + pointsAwarded;
        
        await _firestore.collection('users').doc(donation.donorId).update({
          'points': newPoints,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Check for certificate milestones
        final certificateService = CertificateService();
        await certificateService.checkAndAwardCertificate(donation.donorId, newPoints);
      }

      // Notify donor about completion and points (with chatId for navigation)
      await AppNotification.send(
        AppNotification(
          userId: donation.donorId,
          title: 'Donation Completed!',
          message: 'Your donation "${donation.title}" is completed. You earned $pointsAwarded points!',
          type: 'donation_completed',
          data: {
            'donationId': donationId,
            'pointsAwarded': pointsAwarded,
            'chatId': donation.chatId,
          },
        ),
      );

      // Notify all receivers who claimed portions (with chatId for navigation)
      final updatedDonationDoc = await _firestore.collection('donations').doc(donationId).get();
      final updatedDonation = DonationModel.fromFirestore(updatedDonationDoc);
      
      // Notify all receivers who claimed
      if (updatedDonation.quantityClaims != null && updatedDonation.quantityClaims!.isNotEmpty) {
        for (final receiverId in updatedDonation.quantityClaims!.keys) {
          await AppNotification.send(
            AppNotification(
              userId: receiverId,
              title: 'Donation Completed!',
              message: 'The donation "${donation.title}" has been fully completed.',
              type: 'donation_completed',
              data: {
                'donationId': donationId,
                'chatId': donation.chatId,
              },
            ),
          );
        }
      } else if (donation.claimedBy != null) {
        // Fallback to legacy single receiver notification
        await AppNotification.send(
          AppNotification(
            userId: donation.claimedBy!,
            title: 'Donation Completed! ✅',
            message: 'The donation "${donation.title}" has been successfully completed. Please share your feedback!',
            type: 'donation_completed',
            data: {
              'donationId': donationId,
              'chatId': donation.chatId,
            },
          ),
        );
      }
    } catch (e) {
      print('Error finalizing completion: $e');
      throw Exception('Failed to finalize completion: $e');
    }
  }

  // Legacy method - kept for backward compatibility but now requires both confirmations
  Future<void> completeDonation(String donationId) async {
    // This method is deprecated - use confirmCompletionAsDonor or confirmCompletionAsReceiver instead
    throw Exception('Please use confirmCompletionAsDonor() or confirmCompletionAsReceiver() instead');
  }

  // Award points to donor (private helper - now only called when both confirm)
  Future<void> _awardPointsToDonor(String donorId, int points) async {
    try {
      final userDoc = await _firestore.collection('users').doc(donorId).get();
      if (userDoc.exists) {
        final currentPoints = userDoc.data()?['points'] ?? 0;
        final newPoints = currentPoints + points;
        
        await _firestore.collection('users').doc(donorId).update({
          'points': newPoints,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Check for certificate milestones
        final certificateService = CertificateService();
        await certificateService.checkAndAwardCertificate(donorId, newPoints);
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
          // Get receiver details for personalized notification
          final receiverDoc = await _firestore.collection('users').doc(donation.claimedBy!).get();
          if (receiverDoc.exists) {
            final receiverData = receiverDoc.data()!;
            final receiverName = receiverData['displayName'] ?? receiverData['email']?.split('@')[0] ?? 'Receiver';

            // Send in-app notification to the receiver using AppNotification
            await AppNotification.send(
              AppNotification(
                userId: donation.claimedBy!,
                title: 'Donation Cancelled ❌',
                message: 'The donation "${donation.title}" has been cancelled by the donor.',
                type: 'donation_cancelled',
                data: {
                  'donationId': donationId,
                  'reason': 'Cancelled by donor',
                },
              ),
            );

            print('✅ Notification sent to receiver ${donation.claimedBy!} for cancelled donation: ${donation.title}');
          }
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

  // (legacy donation deletion notification removed)

  // (legacy donation update notification removed)

  // (legacy donation claimed notification removed)

  // (legacy donation completed notification removed)

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

  // Receiver confirms they received the donation
  Future<void> confirmDonationReceived(String donationId, String receiverId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      if (user.uid != receiverId) throw Exception('Only the receiver can confirm the donation');

      final donationDoc = await _firestore.collection('donations').doc(donationId).get();
      if (!donationDoc.exists) {
        throw Exception('Donation not found');
      }

      final donation = DonationModel.fromFirestore(donationDoc);
      
      // Check if this receiver has claimed the donation
      final isClaimedByReceiver = donation.claimedBy == receiverId || 
                                   (donation.quantityClaims?.containsKey(receiverId) ?? false);
      
      if (!isClaimedByReceiver) {
        throw Exception('You have not claimed this donation');
      }

      // Check if already confirmed for this receiver
      final currentReceiverConfirmations = Map<String, bool>.from(
        donation.receiverConfirmations ?? {}
      );
      
      if (currentReceiverConfirmations[receiverId] == true) {
        throw Exception('You have already confirmed this donation');
      }

      // Update donation with receiver confirmation for this specific receiver
      currentReceiverConfirmations[receiverId] = true;
      
      final currentReceiverConfirmedAt = Map<String, Timestamp>.from(
        (donation.receiverConfirmedAt ?? {}).map((k, v) => MapEntry(k, v is Timestamp ? v : Timestamp.fromDate(v)))
      );
      currentReceiverConfirmedAt[receiverId] = Timestamp.now();
      
      await _firestore.collection('donations').doc(donationId).update({
        'receiverConfirmations': currentReceiverConfirmations,
        'receiverConfirmedAt': currentReceiverConfirmedAt.map((k, v) => MapEntry(k, v)),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get donor info for notification (use marketName instead of displayName)
      final donorDoc = await _firestore.collection('users').doc(donation.donorId).get();
      String donorName = 'Donor';
      if (donorDoc.exists) {
        final donorData = donorDoc.data()!;
        donorName = donorData['marketName'] ?? donorData['displayName'] ?? donorData['email']?.split('@')[0] ?? 'Donor';
      }

      // Get receiver info
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      String receiverName = 'Receiver';
      if (receiverDoc.exists) {
        final receiverData = receiverDoc.data()!;
        receiverName = receiverData['displayName'] ?? receiverData['email']?.split('@')[0] ?? 'Receiver';
      }

      // Notify donor that receiver confirmed
      await AppNotification.send(
        AppNotification(
          userId: donation.donorId,
          title: 'Receiver Confirmed Donation',
          message: '$receiverName confirmed they received "${donation.title}". Please confirm to complete the donation.',
          type: 'receiver_confirmed',
          data: {
            'donationId': donationId,
            'receiverId': receiverId,
            'receiverName': receiverName,
            'chatId': donation.chatId,
          },
        ),
      );

      print('✅ Receiver $receiverId confirmed the donation $donationId');
    } catch (e) {
      print('Error confirming donation: $e');
      throw Exception('Failed to confirm donation: $e');
    }
  }

  // Donor confirms the donation was completed for a specific receiver
  Future<void> confirmDonationCompleted(String donationId, String donorId, String receiverId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      if (user.uid != donorId) throw Exception('Only the donor can confirm completion');

      final donationDoc = await _firestore.collection('donations').doc(donationId).get();
      if (!donationDoc.exists) {
        throw Exception('Donation not found');
      }

      final donation = DonationModel.fromFirestore(donationDoc);
      
      if (donation.donorId != donorId) {
        throw Exception('You are not the donor of this donation');
      }

      // Check if this receiver has claimed the donation
      final isClaimedByReceiver = donation.claimedBy == receiverId || 
                                   (donation.quantityClaims?.containsKey(receiverId) ?? false);
      
      if (!isClaimedByReceiver) {
        throw Exception('This receiver has not claimed this donation');
      }

      // Check if receiver has confirmed first for this transaction
      final receiverConfirmations = donation.receiverConfirmations ?? {};
      if (receiverConfirmations[receiverId] != true) {
        throw Exception('Receiver has not confirmed the donation yet');
      }

      // Check if already confirmed for this receiver
      final donorConfirmations = donation.donorConfirmations ?? {};
      if (donorConfirmations[receiverId] == true) {
        throw Exception('You have already confirmed completion for this receiver');
      }

      // Update donation with donor confirmation for this specific receiver
      final updatedDonorConfirmations = Map<String, bool>.from(donorConfirmations);
      updatedDonorConfirmations[receiverId] = true;
      
      final updatedDonorConfirmedAt = Map<String, Timestamp>.from(
        (donation.donorConfirmedAt ?? {}).map((k, v) => MapEntry(k, v is Timestamp ? v : Timestamp.fromDate(v)))
      );
      updatedDonorConfirmedAt[receiverId] = Timestamp.now();
      
      // Check if all claimed quantities are confirmed
      final quantityClaims = donation.quantityClaims ?? {};
      final allReceiversConfirmed = quantityClaims.keys.every((receiverIdKey) {
        return receiverConfirmations[receiverIdKey] == true && updatedDonorConfirmations[receiverIdKey] == true;
      });
      
      // Also check if single claim (claimedBy) is confirmed
      final singleClaimConfirmed = donation.claimedBy == receiverId && 
                                   receiverConfirmations[receiverId] == true && 
                                   updatedDonorConfirmations[receiverId] == true;
      
      // Mark as completed only if all claimed transactions are confirmed
      final shouldMarkCompleted = allReceiversConfirmed || (singleClaimConfirmed && quantityClaims.isEmpty);
      
      await _firestore.collection('donations').doc(donationId).update({
        'donorConfirmations': updatedDonorConfirmations,
        'donorConfirmedAt': updatedDonorConfirmedAt.map((k, v) => MapEntry(k, v)),
        if (shouldMarkCompleted) 'status': 'completed',
        if (shouldMarkCompleted) 'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Award points to donor (10 points per successful transaction)
      await _awardPointsToDonor(donorId, 10);

      // Get donor info (use marketName instead of displayName)
      final donorDoc = await _firestore.collection('users').doc(donorId).get();
      String donorName = 'Donor';
      if (donorDoc.exists) {
        final donorData = donorDoc.data()!;
        donorName = donorData['marketName'] ?? donorData['displayName'] ?? donorData['email']?.split('@')[0] ?? 'Donor';
      }

      // Get receiver info
      String receiverName = 'Receiver';
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      if (receiverDoc.exists) {
        final receiverData = receiverDoc.data()!;
        receiverName = receiverData['displayName'] ?? receiverData['email']?.split('@')[0] ?? 'Receiver';
      }

      // Get chatId for this specific receiver-donor pair
      final expectedChatId = '${donorId}_${receiverId}_$donationId';
      final chatDoc = await _firestore.collection('chats').doc(expectedChatId).get();
      final chatId = chatDoc.exists ? expectedChatId : donation.chatId;

      // Notify receiver of successful donation
      await AppNotification.send(
        AppNotification(
          userId: receiverId,
          title: 'Donation Successful!',
          message: 'The donation "${donation.title}" has been successfully completed. Thank you for using Foodo!',
          type: 'donation_completed',
          data: {
            'donationId': donationId,
            'donorId': donorId,
            'donorName': donorName,
            'chatId': chatId,
          },
        ),
      );

      // Notify donor of successful completion for this transaction
      await AppNotification.send(
        AppNotification(
          userId: donorId,
          title: 'Transaction Completed!',
          message: 'Your transaction with $receiverName for "${donation.title}" is completed. You earned 10 points!',
          type: 'donation_completed',
          data: {
            'donationId': donationId,
            'receiverId': receiverId,
            'points': 10,
            'chatId': chatId,
          },
        ),
      );

      print('✅ Donor $donorId confirmed completion of donation $donationId for receiver $receiverId');
    } catch (e) {
      print('Error confirming donation completion: $e');
      throw Exception('Failed to confirm completion: $e');
    }
  }
}