import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../services/feedback_service.dart'; // Removed - feedback service deleted
// import '../models/feedback_model.dart'; // Removed - feedback model deleted
import '../utils/responsive_layout.dart';

class PublicFeedbackScreen extends StatefulWidget {
  const PublicFeedbackScreen({super.key});

  @override
  State<PublicFeedbackScreen> createState() => _PublicFeedbackScreenState();
}

class _PublicFeedbackScreenState extends State<PublicFeedbackScreen> {
  // final FeedbackService _feedbackService = FeedbackService(); // Removed
  String _selectedFilter = 'all'; // all, recent, high_rating

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Community Feedback',
          style: TextStyle(
            fontSize: ResponsiveLayout.getTitleFontSize(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _selectedFilter = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Text(
                  'All Feedback',
                  style: TextStyle(fontSize: ResponsiveLayout.getBodyFontSize(context)),
                ),
              ),
              PopupMenuItem(
                value: 'recent',
                child: Text(
                  'Recent',
                  style: TextStyle(fontSize: ResponsiveLayout.getBodyFontSize(context)),
                ),
              ),
              PopupMenuItem(
                value: 'high_rating',
                child: Text(
                  'High Rating',
                  style: TextStyle(fontSize: ResponsiveLayout.getBodyFontSize(context)),
                ),
              ),
            ],
            child: Icon(
              Icons.filter_list,
              size: ResponsiveLayout.getIconSize(context),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: Stream.value([]), // Placeholder - feedback removed
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading feedback: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final feedbacks = snapshot.data ?? [];
          final filteredFeedbacks = _filterFeedbacks(feedbacks);

          if (filteredFeedbacks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.feedback, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No feedback available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Be the first to share your experience!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredFeedbacks.length,
            itemBuilder: (context, index) {
              final feedback = filteredFeedbacks[index];
              return _buildFeedbackCard(feedback);
            },
          );
        },
      ),
    );
  }

  List<dynamic> _filterFeedbacks(List<dynamic> feedbacks) {
    // Feedback filtering removed
    return [];
  }

  Widget _buildFeedbackCard(dynamic feedback) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with food title and rating
          Row(
            children: [
              Expanded(
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('donations').doc(feedback.donationId).get(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final donation = snapshot.data!.data() as Map<String, dynamic>;
                      return Text(
                        donation['title'] ?? 'Donation',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      );
                    }
                    return const Text(
                      'Donation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    );
                  },
                ),
              ),
              _buildRatingStars(feedback.averageRating.round()),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Donor and receiver info
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(feedback.donorId).get(),
                builder: (context, snapshot) {
                  String donorName = 'Donor';
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final donorData = snapshot.data!.data() as Map<String, dynamic>;
                    // Use marketName instead of displayName for donors
                    donorName = donorData['marketName'] ?? donorData['displayName'] ?? 'Donor';
                  }
                  return Text(
                    'Donated by $donorName',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  );
                },
              ),
              const SizedBox(width: 16),
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Reviewed by ${feedback.receiverName}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Reviews
          if ((feedback.foodReview != null && feedback.foodReview!.isNotEmpty) ||
              (feedback.donorReview != null && feedback.donorReview!.isNotEmpty)) ...[
            if (feedback.foodReview != null && feedback.foodReview!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Food Review:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feedback.foodReview!,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (feedback.donorReview != null && feedback.donorReview!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Donor Review:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feedback.donorReview!,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (feedback.marketReview != null && feedback.marketReview!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF22c55e).withOpacity(0.1),
                      const Color(0xFF16a34a).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF22c55e).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront, size: 16, color: Color(0xFF22c55e)),
                        const SizedBox(width: 4),
                        const Text(
                          'Market Review:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF22c55e),
                          ),
                        ),
                        if (feedback.marketRating != null) ...[
                          const SizedBox(width: 8),
                          _buildRatingStars(feedback.marketRating!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feedback.marketReview!,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
          
          // Footer with date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(feedback.createdAt),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRatingColor(feedback.averageRating.round()).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${feedback.averageRating.toStringAsFixed(1)}/5',
                  style: TextStyle(
                    color: _getRatingColor(feedback.averageRating.round()),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildRatingStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
