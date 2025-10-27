import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/app_notification.dart';

class FeedbackDialog extends StatefulWidget {
  final String donationId;
  final String donorId;
  final String donorName;
  final VoidCallback? onFeedbackSubmitted;

  const FeedbackDialog({
    super.key,
    required this.donationId,
    required this.donorId,
    required this.donorName,
    this.onFeedbackSubmitted,
  });

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get user name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userName = userDoc.data()?['name'] ?? 
                      userDoc.data()?['displayName'] ?? 
                      currentUser.displayName ?? 
                      'Anonymous';

      // Save feedback
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(widget.donationId)
          .collection('feedback')
          .doc(currentUser.uid)
          .set({
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'receiverId': currentUser.uid,
        'receiverName': userName,
        'donorId': widget.donorId,
        'donorName': widget.donorName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Send notification to donor
      await AppNotification.sendNotification(
        userId: widget.donorId,
        title: 'New Feedback Received!',
        body: '$userName rated your donation $_rating stars',
        type: 'feedback',
        data: {
          'donationId': widget.donationId,
          'rating': _rating.toString(),
          'receiverName': userName,
        },
      );

      // Show success animation
      _showSuccessDialog();
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting feedback: $e')),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/lottie_files/success.json',
                height: 120,
                width: 120,
                fit: BoxFit.contain,
                repeat: false,
              ),
              const SizedBox(height: 16),
              const Text(
                'Feedback Submitted!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF424242),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Thank you for your feedback. The donor will be notified.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF424242),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close success dialog
                  Navigator.of(context).pop(); // Close feedback dialog
                  widget.onFeedbackSubmitted?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBC02D).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Color(0xFFFBC02D),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rate Your Experience',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF424242),
                            ),
                          ),
                          Text(
                            'How was the food from ${widget.donorName}?',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF424242),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Color(0xFF424242)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Star Rating
                const Text(
                  'Rating',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => setState(() => _rating = index + 1),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFBC02D),
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  _rating == 0 ? 'Tap to rate' : '$_rating star${_rating == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _rating == 0 ? Colors.grey[600] : const Color(0xFF424242),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // Comment Section
                const Text(
                  'Comments (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Share your experience...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF43A047)),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF43A047),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
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
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
