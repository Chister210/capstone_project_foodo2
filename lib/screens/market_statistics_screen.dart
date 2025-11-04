import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/responsive_layout.dart';
import '../services/donor_stats_service.dart';

class MarketStatisticsScreen extends StatefulWidget {
  final String donorId;
  final String donorName;

  const MarketStatisticsScreen({
    super.key,
    required this.donorId,
    required this.donorName,
  });

  @override
  State<MarketStatisticsScreen> createState() => _MarketStatisticsScreenState();
}

class _MarketStatisticsScreenState extends State<MarketStatisticsScreen> {
  bool _isLoading = true;
  int _totalDonations = 0;
  int _completed = 0;
  int _available = 0;
  double _averageRating = 0.0;
  int _reviewCount = 0;
  List<Map<String, dynamic>> _recentDonations = [];
  List<Map<String, dynamic>> _recentFeedback = [];

  final DonorStatsService _statsService = DonorStatsService();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _statsService.getDonorStats(widget.donorId);
      setState(() {
        _totalDonations = stats['totalDonations'] ?? 0;
        _completed = stats['completedDonations'] ?? 0;
        _available = stats['availableDonations'] ?? 0;
        _averageRating = (stats['averageRating'] ?? 0.0) as double;
        _reviewCount = stats['reviewCount'] ?? 0;
        _recentFeedback = List<Map<String, dynamic>>.from(stats['recentFeedback'] ?? []);
      });
      // load recent donations via stream subscription (simple one-time snapshot)
      final donations = await FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: widget.donorId)
          .orderBy('createdAt', descending: true)
          .limit(6)
          .get();
      setState(() {
        _recentDonations = donations.docs.map((d) {
          final data = d.data();
          return {
            'id': d.id,
            'title': data['title'] ?? '',
            'status': data['status'] ?? '',
            'createdAt': data['createdAt'],
          };
        }).toList();
      });
    } catch (e) {
      print('MarketStatisticsScreen._loadStats error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: ResponsiveLayout.getPadding(context),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow() {
    final stars = _averageRating.round();
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_averageRating.toStringAsFixed(1), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Row(children: List.generate(5, (i) => Icon(i < stars ? Icons.star : Icons.star_border, color: Colors.amber, size: 18))),
            const SizedBox(height: 4),
            Text('$_reviewCount review${_reviewCount == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22c55e)),
        ),
      ],
    );
  }

  Widget _buildRecentDonations() {
    if (_recentDonations.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: ResponsiveLayout.getPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Transactions', style: TextStyle(fontSize: ResponsiveLayout.getSubtitleFontSize(context), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._recentDonations.map((d) {
            final created = d['createdAt'];
            String timeText = '';
            if (created is Timestamp) timeText = (created.toDate()).toString();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: Colors.grey[100], child: Icon(Icons.restaurant, color: Colors.green)),
              title: Text(d['title'] ?? ''),
              subtitle: Text('Status: ${(d['status'] ?? '').toString()} • $timeText', style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeedbackList() {
    if (_recentFeedback.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('No feedback yet', style: TextStyle(color: Colors.grey[600])),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Feedback', style: TextStyle(fontSize: ResponsiveLayout.getSubtitleFontSize(context), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._recentFeedback.map((f) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: ResponsiveLayout.getPadding(context),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(f['reviewer']?.toString() ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Row(children: List.generate(5, (i) => Icon(i < (f['rating'] as int) ? Icons.star : Icons.star_border, color: Colors.amber, size: 14))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  (f['comment'] ?? '').toString().isNotEmpty ? (f['comment'] ?? '').toString() : 'No comment',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.donorName} • Market Stats'),
        backgroundColor: const Color(0xFF22c55e),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: ResponsiveLayout.getPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRatingRow(),
                  const SizedBox(height: 16),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 3,
                    ),
                    children: [
                      _statCard('Total Donations', '$_totalDonations', Icons.restaurant_menu, Colors.blue),
                      _statCard('Completed', '$_completed', Icons.check_circle, Colors.green),
                      _statCard('Available', '$_available', Icons.schedule, Colors.orange),
                      _statCard('Average Rating', _averageRating.toStringAsFixed(1), Icons.star, Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRecentDonations(),
                  const SizedBox(height: 16),
                  _buildFeedbackList(),
                ],
              ),
            ),
    );
  }
}