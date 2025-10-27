import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_category.dart';
import '../models/beneficiary_type.dart';

class StatisticsService {
  static final StatisticsService _instance = StatisticsService._internal();
  factory StatisticsService() => _instance;
  StatisticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get food category statistics
  Future<Map<String, dynamic>> getFoodCategoryStats({
    String? beneficiaryType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('donations');

      // Apply filters
      if (beneficiaryType != null) {
        query = query.where('beneficiaryType', isEqualTo: beneficiaryType);
      }

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      final donations = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      // Count food categories
      final Map<String, int> categoryCounts = {};
      for (final donation in donations) {
        final category = donation['foodCategory'] ?? 'other';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      // Convert to list with category details
      final List<Map<String, dynamic>> categoryStats = [];
      for (final entry in categoryCounts.entries) {
        final category = FoodCategory.getById(entry.key);
        if (category != null) {
          categoryStats.add({
            'category': category,
            'count': entry.value,
            'percentage': (entry.value / donations.length * 100).round(),
          });
        }
      }

      // Sort by count
      categoryStats.sort((a, b) => b['count'].compareTo(a['count']));

      return {
        'totalDonations': donations.length,
        'categoryStats': categoryStats,
        'topCategory': categoryStats.isNotEmpty ? categoryStats.first : null,
      };
    } catch (e) {
      print('Error getting food category stats: $e');
      return {
        'totalDonations': 0,
        'categoryStats': [],
        'topCategory': null,
      };
    }
  }

  /// Get beneficiary type statistics
  Future<Map<String, dynamic>> getBeneficiaryTypeStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('users').where('userType', isEqualTo: 'receiver');

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      final users = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      // Count beneficiary types
      final Map<String, int> typeCounts = {};
      for (final user in users) {
        final type = user['beneficiaryType'] ?? 'individual';
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }

      // Convert to list with type details
      final List<Map<String, dynamic>> typeStats = [];
      for (final entry in typeCounts.entries) {
        final type = BeneficiaryType.getById(entry.key);
        if (type != null) {
          typeStats.add({
            'type': type,
            'count': entry.value,
            'percentage': (entry.value / users.length * 100).round(),
          });
        }
      }

      // Sort by count
      typeStats.sort((a, b) => b['count'].compareTo(a['count']));

      return {
        'totalReceivers': users.length,
        'typeStats': typeStats,
        'topType': typeStats.isNotEmpty ? typeStats.first : null,
      };
    } catch (e) {
      print('Error getting beneficiary type stats: $e');
      return {
        'totalReceivers': 0,
        'typeStats': [],
        'topType': null,
      };
    }
  }

  /// Get donation trends over time
  Future<Map<String, dynamic>> getDonationTrends({
    String period = 'week', // day, week, month, year
    String? foodCategory,
    String? beneficiaryType,
  }) async {
    try {
      final now = DateTime.now();
      DateTime startDate;
      
      switch (period) {
        case 'day':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = now.subtract(const Duration(days: 7));
      }

      Query query = _firestore.collection('donations')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));

      if (foodCategory != null) {
        query = query.where('foodCategory', isEqualTo: foodCategory);
      }

      if (beneficiaryType != null) {
        query = query.where('beneficiaryType', isEqualTo: beneficiaryType);
      }

      final snapshot = await query.get();
      final donations = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      // Group by time period
      final Map<String, int> trends = {};
      for (final donation in donations) {
        final createdAt = (donation['createdAt'] as Timestamp).toDate();
        String key;
        
        switch (period) {
          case 'day':
            key = '${createdAt.hour}:00';
            break;
          case 'week':
            key = createdAt.weekday.toString();
            break;
          case 'month':
            key = createdAt.day.toString();
            break;
          case 'year':
            key = createdAt.month.toString();
            break;
          default:
            key = createdAt.day.toString();
        }
        
        trends[key] = (trends[key] ?? 0) + 1;
      }

      return {
        'period': period,
        'trends': trends,
        'totalDonations': donations.length,
        'averagePerPeriod': donations.length / trends.length,
      };
    } catch (e) {
      print('Error getting donation trends: $e');
      return {
        'period': period,
        'trends': {},
        'totalDonations': 0,
        'averagePerPeriod': 0,
      };
    }
  }

  /// Get overall statistics
  Future<Map<String, dynamic>> getOverallStats() async {
    try {
      final donationsSnapshot = await _firestore.collection('donations').get();
      final usersSnapshot = await _firestore.collection('users').get();
      final feedbackSnapshot = await _firestore.collection('feedback').get();

      final donations = donationsSnapshot.docs.length;
      final receivers = usersSnapshot.docs.where((doc) => doc.data()['userType'] == 'receiver').length;
      final donors = usersSnapshot.docs.where((doc) => doc.data()['userType'] == 'donor').length;
      final feedback = feedbackSnapshot.docs.length;

      // Calculate average rating
      double averageRating = 0;
      if (feedback > 0) {
        final ratings = feedbackSnapshot.docs
            .map((doc) => doc.data()['rating'] as int? ?? 0)
            .toList();
        averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
      }

      return {
        'totalDonations': donations,
        'totalReceivers': receivers,
        'totalDonors': donors,
        'totalFeedback': feedback,
        'averageRating': averageRating,
        'donationRate': donations > 0 ? (donations / donors).round() : 0,
      };
    } catch (e) {
      print('Error getting overall stats: $e');
      return {
        'totalDonations': 0,
        'totalReceivers': 0,
        'totalDonors': 0,
        'totalFeedback': 0,
        'averageRating': 0.0,
        'donationRate': 0,
      };
    }
  }
}
