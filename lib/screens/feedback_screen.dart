import 'package:flutter/material.dart';
import 'package:get/get.dart';
// import '../services/feedback_service.dart'; // Removed - feedback service deleted

class FeedbackScreen extends StatefulWidget {
  final String donationId;
  final String foodTitle;
  final String donorName;

  const FeedbackScreen({
    super.key,
    required this.donationId,
    required this.foodTitle,
    required this.donorName,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  // final FeedbackService _feedbackService = FeedbackService(); // Removed
  
  int _foodRating = 0;
  int _donorRating = 0;
  final TextEditingController _foodReviewController = TextEditingController();
  final TextEditingController _donorReviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _foodReviewController.dispose();
    _donorReviewController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    // Feedback submission feature has been removed
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback feature has been removed'),
          backgroundColor: Colors.orange,
        ),
      );
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Feedback'),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food item info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Food Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.foodTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22c55e),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Donated by: ${widget.donorName}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Food Rating section
            const Text(
              'Rate the Food Quality',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _foodRating = index + 1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Icon(
                      index < _foodRating ? Icons.star : Icons.star_border,
                      color: index < _foodRating ? Colors.amber : Colors.grey,
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 24),
            
            // Food Review section
            const Text(
              'Food Review (optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _foodReviewController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tell us about the food quality...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF22c55e)),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Donor Rating section
            const Text(
              'Rate the Donor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _donorRating = index + 1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Icon(
                      index < _donorRating ? Icons.star : Icons.star_border,
                      color: index < _donorRating ? Colors.amber : Colors.grey,
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 24),
            
            // Donor Review section
            const Text(
              'Donor Review (optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _donorReviewController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tell us about your experience with the donor...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF22c55e)),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22c55e),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
