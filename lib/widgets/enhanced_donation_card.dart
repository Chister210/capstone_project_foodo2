import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/donation_model.dart';
import '../services/donation_service.dart';
import '../screens/edit_donation_screen.dart';

class EnhancedDonationCard extends StatefulWidget {
  final DonationModel donation;
  final VoidCallback? onUpdated;
  final bool showActions;

  const EnhancedDonationCard({
    super.key,
    required this.donation,
    this.onUpdated,
    this.showActions = true,
  });

  @override
  State<EnhancedDonationCard> createState() => _EnhancedDonationCardState();
}

class _EnhancedDonationCardState extends State<EnhancedDonationCard> {
  final DonationService _donationService = DonationService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          if (widget.donation.hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Builder(
                builder: (context) {
                  try {
                    final uri = Uri.tryParse(widget.donation.imageUrl);
                    if (uri != null && uri.data != null) {
                      final bytes = uri.data!.contentAsBytes();
                      if (bytes.isNotEmpty && bytes.length > 100) {
                        return Image.memory(
                          bytes,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        );
                      }
                    }
                  } catch (e) {}
                  // Fallback if image is invalid
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey, size: 48),
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.donation.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusChip(),
                  ],
                ),

                const SizedBox(height: 8),

                // Description
                Text(
                  widget.donation.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Food details
                if (widget.donation.foodType != null || widget.donation.quantity != null)
                  Row(
                    children: [
                      if (widget.donation.foodType != null) ...[
                        _buildInfoChip(
                          icon: Icons.restaurant,
                          label: widget.donation.foodType!,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (widget.donation.quantity != null)
                        _buildInfoChip(
                          icon: Icons.scale,
                          label: widget.donation.quantity!,
                          color: Colors.orange,
                        ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Pickup time
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Pickup: ${_formatDateTime(widget.donation.pickupTime)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Allergens
                if (widget.donation.allergensList.isNotEmpty)
                  Wrap(
                    children: widget.donation.allergensList.map((allergen) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 4),
                        child: Chip(
                          label: Text(
                            allergen,
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.red.withOpacity(0.1),
                          labelStyle: const TextStyle(color: Colors.red),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      );
                    }).toList(),
                  ),

                // Claimed by info
                if (widget.donation.status == 'claimed' || widget.donation.status == 'in_progress')
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Claimed by receiver',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Action buttons
                if (widget.showActions && _canShowActions())
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        if (widget.donation.status == 'available') ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _editDonation,
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: const BorderSide(color: Colors.blue),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _deleteDonation,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.delete, size: 16),
                            label: Text(widget.donation.status == 'available' ? 'Delete' : 'Cancel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String text;

    switch (widget.donation.status) {
      case 'available':
        color = Colors.green;
        text = 'Available';
        break;
      case 'claimed':
        color = Colors.orange;
        text = 'Claimed';
        break;
      case 'in_progress':
        color = Colors.blue;
        text = 'In Progress';
        break;
      case 'completed':
        color = Colors.grey;
        text = 'Completed';
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  bool _canShowActions() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    // Only show actions for the donation owner
    if (widget.donation.donorId != user.uid) return false;
    
    // Don't show actions for completed donations
    if (widget.donation.status == 'completed') return false;
    
    return true;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _editDonation() async {
    Get.to(() => EditDonationScreen(donation: widget.donation));
  }

  Future<void> _deleteDonation() async {
    final confirmed = await _showDeleteConfirmation();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      // Notify receiver if donation was claimed
      if (widget.donation.claimedBy != null) {
        await _donationService.notifyDonationDeleted(
          widget.donation.id,
          widget.donation.claimedBy!,
          widget.donation.title,
        );
      }

      // Delete the donation
      await _donationService.deleteDonation(widget.donation.id);

      Get.snackbar(
        'Success',
        'Donation deleted successfully',
        backgroundColor: const Color(0xFF22c55e),
        colorText: Colors.white,
      );

      widget.onUpdated?.call();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete donation: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Donation'),
        content: Text(
          widget.donation.status == 'claimed' || widget.donation.status == 'in_progress'
              ? 'This donation has been claimed. Are you sure you want to cancel it? The receiver will be notified.'
              : 'Are you sure you want to delete this donation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }
}
