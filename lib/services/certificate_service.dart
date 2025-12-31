import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'email_service.dart';

/// Certificate milestones for donors
class CertificateMilestone {
  final int pointsRequired;
  final String certificateName;
  final String certificateDescription;
  final String certificateLevel; // bronze, silver, gold, platinum

  const CertificateMilestone({
    required this.pointsRequired,
    required this.certificateName,
    required this.certificateDescription,
    required this.certificateLevel,
  });

  static const List<CertificateMilestone> milestones = [
    CertificateMilestone(
      pointsRequired: 50,
      certificateName: 'Food Hero Certificate',
      certificateDescription: 'For completing 5 successful donations',
      certificateLevel: 'bronze',
    ),
    CertificateMilestone(
      pointsRequired: 100,
      certificateName: 'Community Champion Certificate',
      certificateDescription: 'For completing 10 successful donations',
      certificateLevel: 'silver',
    ),
    CertificateMilestone(
      pointsRequired: 250,
      certificateName: 'Impact Leader Certificate',
      certificateDescription: 'For completing 25 successful donations',
      certificateLevel: 'gold',
    ),
    CertificateMilestone(
      pointsRequired: 500,
      certificateName: 'Platinum Supporter Certificate',
      certificateDescription: 'For completing 50 successful donations',
      certificateLevel: 'platinum',
    ),
    CertificateMilestone(
      pointsRequired: 1000,
      certificateName: 'Master Food Donor Certificate',
      certificateDescription: 'For completing 100 successful donations',
      certificateLevel: 'master',
    ),
  ];

  static CertificateMilestone? getMilestoneForPoints(int points) {
    // Get the highest milestone reached
    CertificateMilestone? highestMilestone;
    for (final milestone in milestones) {
      if (points >= milestone.pointsRequired) {
        if (highestMilestone == null || milestone.pointsRequired > highestMilestone.pointsRequired) {
          highestMilestone = milestone;
        }
      }
    }
    return highestMilestone;
  }

  static List<CertificateMilestone> getUnlockedMilestones(int points) {
    return milestones.where((m) => points >= m.pointsRequired).toList();
  }

  static List<CertificateMilestone> getLockedMilestones(int points) {
    return milestones.where((m) => points < m.pointsRequired).toList();
  }

  static CertificateMilestone? getNextMilestone(int points) {
    final locked = getLockedMilestones(points);
    if (locked.isEmpty) return null;
    locked.sort((a, b) => a.pointsRequired.compareTo(b.pointsRequired));
    return locked.first;
  }
}

class CertificateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EmailService _emailService = EmailService();

  /// Check if donor should receive a certificate and send it
  Future<void> checkAndAwardCertificate(String donorId, int newPoints) async {
    try {
      // Get donor data
      final donorDoc = await _firestore.collection('users').doc(donorId).get();
      if (!donorDoc.exists) {
        print('❌ Donor not found: $donorId');
        return;
      }

      final donorData = donorDoc.data()!;
      // Use marketName instead of displayName for donors
      final donorName = donorData['marketName'] ?? donorData['displayName'] ?? donorData['email']?.split('@')[0] ?? 'Donor';
      final donorEmail = donorData['email'] ?? '';

      // Get milestones already awarded to this donor
      final awardedMilestones = donorData['awardedCertificates'] as List<dynamic>? ?? [];
      final awardedPoints = awardedMilestones.map((m) => m is Map ? (m['points'] as int? ?? 0) : 0).toList();

      // Find newly reached milestones
      final newlyReached = CertificateMilestone.milestones.where((milestone) {
        // Check if this milestone was just reached
        final wasReached = awardedPoints.contains(milestone.pointsRequired);
        final isNowReached = newPoints >= milestone.pointsRequired;
        return !wasReached && isNowReached;
      }).toList();

      // Award and send certificates for newly reached milestones
      for (final milestone in newlyReached) {
        await _awardAndSendCertificate(
          donorId: donorId,
          donorName: donorName,
          donorEmail: donorEmail,
          milestone: milestone,
          points: newPoints,
        );
      }

      print('✅ Certificate check completed for donor $donorId');
    } catch (e) {
      print('❌ Error checking certificates: $e');
    }
  }

  /// Award a certificate and send it via email
  Future<void> _awardAndSendCertificate({
    required String donorId,
    required String donorName,
    required String donorEmail,
    required CertificateMilestone milestone,
    required int points,
  }) async {
    try {
      // Record the certificate in Firestore
      final certificateData = {
        'points': milestone.pointsRequired,
        'certificateName': milestone.certificateName,
        'certificateLevel': milestone.certificateLevel,
        'awardedAt': FieldValue.serverTimestamp(),
        'awardedPoints': points,
      };

      // Update user document with awarded certificate
      final currentAwarded = await _firestore.collection('users').doc(donorId).get();
      final currentList = currentAwarded.data()?['awardedCertificates'] as List<dynamic>? ?? [];
      currentList.add(certificateData);

      await _firestore.collection('users').doc(donorId).update({
        'awardedCertificates': currentList,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send certificate via email
      await _emailService.sendCertificateEmail(
        recipientEmail: donorEmail,
        recipientName: donorName,
        certificateName: milestone.certificateName,
        certificateDescription: milestone.certificateDescription,
        certificateLevel: milestone.certificateLevel,
        pointsAwarded: points,
      );

      print('✅ Certificate awarded and sent to $donorEmail: ${milestone.certificateName}');
    } catch (e) {
      print('❌ Error awarding certificate: $e');
    }
  }

  /// Get all certificates for a donor
  Future<List<Map<String, dynamic>>> getDonorCertificates(String donorId) async {
    try {
      final donorDoc = await _firestore.collection('users').doc(donorId).get();
      if (!donorDoc.exists) return [];

      final donorData = donorDoc.data()!;
      final awardedCertificates = donorData['awardedCertificates'] as List<dynamic>? ?? [];

      return awardedCertificates
          .map((cert) => cert is Map 
              ? Map<String, dynamic>.from(cert) 
              : <String, dynamic>{})
          .toList();
    } catch (e) {
      print('❌ Error getting donor certificates: $e');
      return [];
    }
  }
}

