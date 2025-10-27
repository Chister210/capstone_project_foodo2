import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/feedback_service.dart';
import '../models/feedback_model.dart';
import '../utils/responsive_layout.dart';

class PublicFeedbackScreen extends StatefulWidget {
  const PublicFeedbackScreen({super.key});

  @override
  State<PublicFeedbackScreen> createState() => _PublicFeedbackScreenState();
}

class _PublicFeedbackScreenState extends State<PublicFeedbackScreen> {
  final FeedbackService _feedbackService = FeedbackService();
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
      body: StreamBuilder<List<FeedbackModel>>(
        stream: _feedbackService.getAllFeedback(),
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

  List<FeedbackModel> _filterFeedbacks(List<FeedbackModel> feedbacks) {
    switch (_selectedFilter) {
      case 'recent':
        feedbacks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return feedbacks.take(10).toList();
      case 'high_rating':
        return feedbacks.where((f) => f.rating >= 4).toList();
      default:
        return feedbacks;
    }
  }

  Widget _buildFeedbackCard(FeedbackModel feedback) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with food title and rating
          Row(
            children: [
              Expanded(
                child: Text(
                  feedback.foodTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              _buildRatingStars(feedback.rating),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Donor and receiver info
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Donated by ${feedback.donorName}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
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
          
          // Comment
          if (feedback.comment.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                feedback.comment,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Images
          if (feedback.images.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: feedback.images.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(feedback.images[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
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
                  color: _getRatingColor(feedback.rating).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${feedback.rating}/5',
                  style: TextStyle(
                    color: _getRatingColor(feedback.rating),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
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
