import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/donor_stats_service.dart';
import '../services/feedback_service.dart';
import '../models/donation_model.dart';
import '../models/feedback_model.dart';
import '../theme/app_theme.dart';

class MarketDetailsScreen extends StatefulWidget {
  final String donorId;
  final String donorName;
  final String marketAddress;
  final bool isOnline;

  const MarketDetailsScreen({
    super.key,
    required this.donorId,
    required this.donorName,
    required this.marketAddress,
    required this.isOnline,
  });

  @override
  State<MarketDetailsScreen> createState() => _MarketDetailsScreenState();
}

class _MarketDetailsScreenState extends State<MarketDetailsScreen> with SingleTickerProviderStateMixin {
  final DonorStatsService _statsService = Get.put(DonorStatsService());
  final FeedbackService _feedbackService = FeedbackService();
  late TabController _tabController;

  Map<String, dynamic>? _marketStats;
  List<FeedbackModel> _allFeedback = [];
  double _marketAverageRating = 0.0;
  int _marketReviewCount = 0;
  bool _isLoading = true;
  StreamSubscription<List<FeedbackModel>>? _feedbackSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMarketData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMarketData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load market statistics
      final stats = await _statsService.getDonorStats(widget.donorId);
      
      // Load feedback and calculate average rating
      final averageRating = await _feedbackService.getAverageRating(widget.donorId);
      final reviewCount = await _feedbackService.getReviewCount(widget.donorId);
      
      // Load feedback list
      _feedbackSubscription?.cancel();
      _feedbackSubscription = _feedbackService.getFeedbackForDonor(widget.donorId).listen((feedbackList) {
        if (mounted) {
          setState(() {
            _allFeedback = feedbackList;
          });
        }
      });
      
      setState(() {
        _marketStats = stats;
        _marketAverageRating = averageRating;
        _marketReviewCount = reviewCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'Failed to load market data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.donorName),
        backgroundColor: AppTheme.donorGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Statistics'),
            Tab(text: 'Reviews'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildMarketHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStatisticsTab(),
                      _buildReviewsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMarketHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.donorGreen,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.store,
              size: 32,
              color: AppTheme.donorGreen,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.donorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.marketAddress,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.isOnline ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.isOnline ? 'Online Now' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_marketStats != null) 
            Builder(
              builder: (context) {
                // Show market rating if available, otherwise show overall rating
                final rating = _marketAverageRating > 0 
                    ? _marketAverageRating 
                    : ((_marketStats!['averageRating'] as num?)?.toDouble() ?? 0.0);
                
                if (rating > 0) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppTheme.donorGreen,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_marketAverageRating > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Market Rating',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    if (_marketStats == null) return const Center(child: Text('No statistics available'));

    // Safely extract values with null checks
    final totalDonations = (_marketStats!['totalDonations'] as num?)?.toInt() ?? 0;
    final completedDonations = (_marketStats!['completedDonations'] as num?)?.toInt() ?? 0;
    final availableDonations = (_marketStats!['availableDonations'] as num?)?.toInt() ?? 0;
    final averageRating = (_marketStats!['averageRating'] as num?)?.toDouble() ?? 0.0;
    final totalRatings = (_marketStats!['totalRatings'] as num?)?.toInt() ?? 0;
    final marketRating = _marketAverageRating > 0 ? _marketAverageRating : averageRating;
    final marketRatingCount = _marketReviewCount > 0 ? _marketReviewCount : totalRatings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Statistics
          Text(
            'Overall Performance',
            style: AppTheme.heading2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Donations',
                  totalDonations.toString(),
                  Icons.restaurant_menu,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  completedDonations.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Available',
                  availableDonations.toString(),
                  Icons.schedule,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Market Rating',
                  marketRating > 0 ? marketRating.toStringAsFixed(1) : 'N/A',
                  Icons.storefront,
                  Colors.amber,
                  subtitle: marketRatingCount > 0 ? '$marketRatingCount reviews' : 'No reviews',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          // Ratings Distribution
          if (marketRatingCount > 0) ...[
            Text(
              'Rating Distribution',
              style: AppTheme.heading2,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  _buildRatingBar(5, _getRatingCount(5), marketRatingCount),
                  _buildRatingBar(4, _getRatingCount(4), marketRatingCount),
                  _buildRatingBar(3, _getRatingCount(3), marketRatingCount),
                  _buildRatingBar(2, _getRatingCount(2), marketRatingCount),
                  _buildRatingBar(1, _getRatingCount(1), marketRatingCount),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Donation Activity
          Text(
            'Recent Activity',
            style: AppTheme.heading2,
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<DonationModel>>(
            stream: _statsService.getDonorRecentDonations(widget.donorId),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return Column(
                  children: snapshot.data!.take(5).map((donation) => 
                    _buildDonationCard(donation)
                  ).toList(),
                );
              }
              return const Center(child: Text('No recent activity'));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.mediumGray.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  int _getRatingCount(int stars) {
    if (_allFeedback.isEmpty) return 0;
    // Count ratings for the specific star count
    return _allFeedback.where((feedback) {
      return feedback.rating == stars;
    }).length;
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final percentage = total > 0 ? count / total : 0.0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$stars',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const Icon(Icons.star, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationCard(DonationModel donation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.softCardDecoration,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor(donation.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(donation.status),
              color: _getStatusColor(donation.status),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donation.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(donation.createdAt)} • ${donation.status.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_allFeedback.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.reviews, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _allFeedback.length,
      itemBuilder: (context, index) {
        final feedback = _allFeedback[index];
        return _buildReviewCard(feedback);
      },
    );
  }

  Widget _buildReviewCard(FeedbackModel feedback) {
    final receiverName = feedback.receiverName;
    final rating = feedback.rating;
    final comment = feedback.comment ?? '';
    final timestamp = feedback.createdAt;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('donations')
          .doc(feedback.donationId)
          .get(),
      builder: (context, snapshot) {
        final donationTitle = snapshot.hasData && snapshot.data!.exists
            ? (snapshot.data!.data() as Map<String, dynamic>)['title'] ?? 'Donation'
            : 'Donation';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.donorGreen.withOpacity(0.2),
                    child: const Icon(Icons.person, color: AppTheme.donorGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receiverName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatDate(timestamp),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.mediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 16,
                      );
                    }),
                  ),
                ],
              ),
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  comment,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textDarkGray,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant, size: 14, color: AppTheme.mediumGray),
                    const SizedBox(width: 4),
                    Text(
                      donationTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'claimed':
        return Colors.orange;
      case 'delivered':
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Icons.check_circle;
      case 'claimed':
        return Icons.schedule;
      case 'delivered':
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.help;
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    }
  }
}
