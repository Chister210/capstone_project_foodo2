import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/donor_stats_service.dart';
import '../models/donation_model.dart';
import '../utils/responsive_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/market_statistics_screen.dart';

class DonorInfoPopup extends StatefulWidget {
  final String donorId;
  final String donorName;
  final String donorEmail;
  final GeoPoint? location;
  final String marketAddress;
  final bool isOnline;
  final VoidCallback? onGetDirections;
  final VoidCallback? onStartChat;
  final VoidCallback? onShowMoreDetails;

  const DonorInfoPopup({
    super.key,
    required this.donorId,
    required this.donorName,
    required this.donorEmail,
    this.location,
    required this.marketAddress,
    required this.isOnline,
    this.onGetDirections,
    this.onStartChat,
    this.onShowMoreDetails,
  });

  @override
  State<DonorInfoPopup> createState() => _DonorInfoPopupState();
}

class _DonorInfoPopupState extends State<DonorInfoPopup> {
  final DonorStatsService _statsService = Get.put(DonorStatsService());
  Map<String, dynamic>? _donorStats;
  List<DonationModel> _recentDonations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDonorData();
  }

  Future<void> _loadDonorData() async {
    try {
      final stats = await _statsService.getDonorStats(widget.donorId);
      setState(() {
        _donorStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: ResponsiveLayout.isMobile(context) 
            ? MediaQuery.of(context).size.width * 0.9
            : ResponsiveLayout.isTablet(context)
                ? MediaQuery.of(context).size.width * 0.7
                : MediaQuery.of(context).size.width * 0.5,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveLayout.getBorderRadius(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFF22c55e),
                  strokeWidth: ResponsiveLayout.isMobile(context) ? 2 : 3,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    _buildStatsSection(),
                    _buildRecentDonations(),
                    _buildRecentFeedback(),
                    _buildActionButtons(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: ResponsiveLayout.getPadding(context),
      decoration: BoxDecoration(
        color: const Color(0xFF22c55e),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ResponsiveLayout.getBorderRadius(context)),
          topRight: Radius.circular(ResponsiveLayout.getBorderRadius(context)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: ResponsiveLayout.isMobile(context) ? 25 : 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(
              Icons.restaurant,
              color: Colors.white,
              size: ResponsiveLayout.getIconSize(context),
            ),
          ),
          SizedBox(width: ResponsiveLayout.getSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.donorName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveLayout.getSubtitleFontSize(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.marketAddress.isNotEmpty 
                      ? widget.marketAddress 
                      : 'Location not specified',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: ResponsiveLayout.getBodyFontSize(context) - 2,
                  ),
                ),
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
                    SizedBox(width: ResponsiveLayout.getSpacing(context) / 2),
                    Text(
                      widget.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: ResponsiveLayout.getBodyFontSize(context) - 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: Colors.white,
              size: ResponsiveLayout.getIconSize(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_donorStats == null) return const SizedBox.shrink();

    return Padding(
      padding: ResponsiveLayout.getPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistics',
            style: TextStyle(
              fontSize: ResponsiveLayout.getSubtitleFontSize(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveLayout.getSpacing(context)),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Donations',
                  '${_donorStats!['totalDonations']}',
                  Icons.restaurant_menu,
                  Colors.blue,
                ),
              ),
              SizedBox(width: ResponsiveLayout.getSpacing(context)),
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  '${_donorStats!['completedDonations']}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveLayout.getSpacing(context)),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Available',
                  '${_donorStats!['availableDonations']}',
                  Icons.schedule,
                  Colors.orange,
                ),
              ),
              SizedBox(width: ResponsiveLayout.getSpacing(context)),
              Expanded(
                child: _buildStatCard(
                  'Rating',
                  '${_donorStats!['averageRating'].toStringAsFixed(1)} ⭐',
                  Icons.star,
                  Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: ResponsiveLayout.getPadding(context),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ResponsiveLayout.getBorderRadius(context) / 2),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: ResponsiveLayout.getIconSize(context)),
          SizedBox(height: ResponsiveLayout.getSpacing(context) / 2),
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveLayout.getSubtitleFontSize(context),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: ResponsiveLayout.getBodyFontSize(context) - 2,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDonations() {
    return StreamBuilder<List<DonationModel>>(
      stream: _statsService.getDonorRecentDonations(widget.donorId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final donations = snapshot.data!;
        return Padding(
          padding: ResponsiveLayout.getPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Donations',
                style: TextStyle(
                  fontSize: ResponsiveLayout.getSubtitleFontSize(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ResponsiveLayout.getSpacing(context)),
              ...donations.take(3).map((donation) => _buildDonationItem(donation)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDonationItem(DonationModel donation) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveLayout.getSpacing(context) / 2),
      padding: ResponsiveLayout.getPadding(context),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(ResponsiveLayout.getBorderRadius(context) / 2),
        border: Border.all(color: Colors.grey[200]!),
      ),
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
          SizedBox(width: ResponsiveLayout.getSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donation.title,
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getBodyFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Status: ${donation.status.toUpperCase()}',
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getBodyFontSize(context) - 2,
                    color: _getStatusColor(donation.status),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentFeedback() {
    if (_donorStats == null || _donorStats!['recentFeedback'].isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: ResponsiveLayout.getPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Feedback',
            style: TextStyle(
              fontSize: ResponsiveLayout.getSubtitleFontSize(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveLayout.getSpacing(context)),
          ...(_donorStats!['recentFeedback'] as List).take(2).map((feedback) => 
            _buildFeedbackItem(feedback)),
        ],
      ),
    );
  }

  Widget _buildFeedbackItem(Map<String, dynamic> feedback) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveLayout.getSpacing(context) / 2),
      padding: ResponsiveLayout.getPadding(context),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ResponsiveLayout.getBorderRadius(context) / 2),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                feedback['receiverName'],
                style: TextStyle(
                  fontSize: ResponsiveLayout.getBodyFontSize(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < feedback['rating'] ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          SizedBox(height: ResponsiveLayout.getSpacing(context) / 2),
          Text(
            feedback['comment'],
            style: TextStyle(
              fontSize: ResponsiveLayout.getBodyFontSize(context) - 2,
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: ResponsiveLayout.getPadding(context),
      child: Column(
        children: [
          // Get Directions and Start Chat buttons on top
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onGetDirections,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22c55e),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ResponsiveLayout.getBorderRadius(context) / 2),
                    ),
                  ),
                  icon: Icon(
                    Icons.directions,
                    size: ResponsiveLayout.getIconSize(context),
                  ),
                  label: Text(
                    'Get Directions',
                    style: TextStyle(
                      fontSize: ResponsiveLayout.getBodyFontSize(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(width: ResponsiveLayout.getSpacing(context)),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onStartChat,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF22c55e),
                    side: const BorderSide(color: Color(0xFF22c55e)),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ResponsiveLayout.getBorderRadius(context) / 2),
                    ),
                  ),
                  icon: Icon(
                    Icons.chat,
                    size: ResponsiveLayout.getIconSize(context),
                  ),
                  label: Text(
                    'Start Chat',
                    style: TextStyle(
                      fontSize: ResponsiveLayout.getBodyFontSize(context) - 2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveLayout.getSpacing(context)),
          // Show More Details button below
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (widget.onShowMoreDetails != null) {
                  widget.onShowMoreDetails!();
                  return;
                }
                // default navigation: open MarketStatisticsScreen for this donor
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MarketStatisticsScreen(
                      donorId: widget.donorId,
                      donorName: widget.donorName,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22c55e).withOpacity(0.1),
                foregroundColor: const Color(0xFF22c55e),
                side: const BorderSide(color: Color(0xFF22c55e), width: 2),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ResponsiveLayout.getBorderRadius(context) / 2),
                ),
              ),
              icon: Icon(
                Icons.store,
                size: ResponsiveLayout.getIconSize(context),
              ),
              label: Text(
                'Show More Details',
                style: TextStyle(
                  fontSize: ResponsiveLayout.getBodyFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'claimed':
        return Colors.orange;
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
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.help;
    }
  }
}
