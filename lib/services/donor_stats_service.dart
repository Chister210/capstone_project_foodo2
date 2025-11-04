import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/donation_model.dart'; // added for DonationModel

class DonorStatsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns aggregated stats and recent feedback (used by MarketStatisticsScreen)
  Future<Map<String, dynamic>> getDonorStats(String donorId) async {
    final Map<String, dynamic> result = {
      'totalDonations': 0,
      'completedDonations': 0,
      'availableDonations': 0,
      'averageRating': 0.0,
      'reviewCount': 0,
      'recentFeedback': <Map<String, dynamic>>[],
    };

    try {
      // Donations aggregation
      final donationsSnap = await _db
          .collection('donations')
          .where('donorId', isEqualTo: donorId)
          .get();
      final donations = donationsSnap.docs.map((d) => d.data()).toList();
      result['totalDonations'] = donations.length;
      result['completedDonations'] = donations
          .where((d) => ((d['status'] ?? '') as String).toLowerCase() == 'completed')
          .length;
      result['availableDonations'] = donations
          .where((d) => ((d['status'] ?? '') as String).toLowerCase() == 'available')
          .length;

      // Feedback aggregation (try two common collection names)
      QuerySnapshot feedbackSnap;
      try {
        feedbackSnap = await _db
            .collection('feedbacks')
            .where('donorId', isEqualTo: donorId)
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();
      } catch (_) {
        feedbackSnap = await _db
            .collection('feedback')
            .where('donorId', isEqualTo: donorId)
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();
      }

      final feedbackDocs = feedbackSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      result['reviewCount'] = feedbackDocs.length;
      if (feedbackDocs.isNotEmpty) {
        double sum = 0;
        for (final f in feedbackDocs) {
          final r = f['rating'];
          if (r is int) {
            sum += r;
          } else if (r is double) sum += r;
          else sum += double.tryParse(r?.toString() ?? '') ?? 0;
        }
        result['averageRating'] = sum / feedbackDocs.length;
      } else {
        result['averageRating'] = 0.0;
      }

      result['recentFeedback'] = feedbackDocs.map((f) {
        return {
          'receiverName': (f['receiverName'] ?? f['receiverDisplayName'] ?? 'Anonymous').toString(),
          'rating': (f['rating'] is int) ? f['rating'] as int : (f['rating'] is double ? (f['rating'] as double).round() : int.tryParse(f['rating']?.toString() ?? '') ?? 0),
          'comment': (f['comment'] ?? '').toString(),
          'createdAt': f['createdAt'],
        };
      }).toList();
    } catch (e) {
      // keep defaults on error
      print('DonorStatsService.getDonorStats error: $e');
    }

    return result;
  }

  /// Stream of donor locations for real-time map markers.
  /// Emits a list of normalized maps:
  /// { donorId, donorName, donorEmail, marketAddress, isOnline, location: GeoPoint }
  Stream<List<Map<String, dynamic>>> getDonorLocations() {
    return _db
        .collection('users')
        .where('userType', isEqualTo: 'donor')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        final marketLocation = data['marketLocation'];
        GeoPoint? gp;
        if (marketLocation is GeoPoint) {
          gp = marketLocation;
        } else if (marketLocation is Map) {
          final lat = (marketLocation['latitude'] as num?)?.toDouble();
          final lng = (marketLocation['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) gp = GeoPoint(lat, lng);
        }

        return {
          'donorId': doc.id,
          'donorName': data['displayName'] ?? data['marketName'] ?? data['email'] ?? '',
          'donorEmail': data['email'] ?? '',
          'marketAddress': data['marketAddress'] ?? '',
          'isOnline': data['isOnline'] ?? false,
          'location': gp, // may be null
        };
      }).where((m) => m['location'] != null).toList();
    });
  }

  /// Stream of recent donations for a donor as DonationModel instances.
  /// Used by UI (e.g. MarketDetailsScreen) to show recent activity.
  Stream<List<DonationModel>> getDonorRecentDonations(String donorId, {int limit = 10}) {
    return _db
        .collection('donations')
        .where('donorId', isEqualTo: donorId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs.map<DonationModel>((doc) {
        final data = doc.data();

        // normalize timestamps
        final createdAt = data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : (data['createdAt'] as DateTime?) ?? DateTime.now();
        final pickupTime = data['pickupTime'] is Timestamp
            ? (data['pickupTime'] as Timestamp).toDate()
            : (data['pickupTime'] as DateTime?) ?? DateTime.now();
        final updatedAt = data['updatedAt'] is Timestamp
            ? (data['updatedAt'] as Timestamp).toDate()
            : (data['updatedAt'] as DateTime?) ?? createdAt;

        // common fallbacks for strings / images
        final imageUrl = (data['imageUrl'] ?? data['image'] ?? data['images'] ?? '').toString();
        final deliveryType = (data['deliveryType'] ?? data['deliveryTpre'] ?? data['delivery_method'] ?? '').toString();
        final title = (data['title'] ?? '').toString();
        final description = (data['description'] ?? '').toString();
        final donorIdField = (data['donorId'] ?? data['ownerId'] ?? '').toString();
        final donorEmail = (data['donorEmail'] ?? data['email'] ?? '').toString();
        final marketAddress = data['marketAddress']?.toString();
        final status = (data['status'] ?? '').toString();
        final marketLocation = data['marketLocation'];

        // construct DonationModel manually (match your model's named params)
        return DonationModel(
          id: doc.id,
          title: title,
          description: description,
          imageUrl: imageUrl,
          deliveryType: deliveryType,
          donorId: donorIdField,
          donorEmail: donorEmail,
          marketAddress: marketAddress,
          marketLocation: marketLocation,
          status: status,
          createdAt: createdAt,
          updatedAt: updatedAt,
          pickupTime: pickupTime,
        );
      }).toList();
    });
  }
}