import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/donation_model.dart';
import '../services/delivery_confirmation_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

class ReceiverDonationDetailsScreen extends StatefulWidget {
  final DonationModel donation;

  const ReceiverDonationDetailsScreen({
    super.key,
    required this.donation,
  });

  @override
  State<ReceiverDonationDetailsScreen> createState() => _ReceiverDonationDetailsScreenState();
}

class _ReceiverDonationDetailsScreenState extends State<ReceiverDonationDetailsScreen> {
  final DeliveryConfirmationService _deliveryService = DeliveryConfirmationService();
  final UserService _userService = UserService();
  bool _isLoading = false;
  String? _donorName;

  // Local mutable status to reflect UI changes without mutating the model
  late String _status;

  @override
  void initState() {
    super.initState();
    _loadDonorName();
    _status = widget.donation.status; // initialize local status
  }

  Future<void> _loadDonorName() async {
    try {
      final donorName = await _userService.getUserName(widget.donation.donorId);
      setState(() => _donorName = donorName);
    } catch (e) {
      print('Error loading donor name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.donation.title),
        backgroundColor: AppTheme.receiverOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            if (widget.donation.hasImage)
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  child: _buildImage(),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.donation.title,
                          style: AppTheme.heading2,
                        ),
                      ),
                      _buildStatusChip(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'Description',
                    style: AppTheme.heading3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.donation.description,
                    style: AppTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),

                  // Donation details
                  _buildDetailsSection(),
                  const SizedBox(height: 20),

                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    try {
      final uri = Uri.tryParse(widget.donation.imageUrl);
      if (uri != null && uri.data != null) {
        final bytes = uri.data!.contentAsBytes();
        if (bytes.isNotEmpty && bytes.length > 100) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
          );
        }
      }
    } catch (e) {}
    
    return Container(
      color: AppTheme.lightGray,
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: AppTheme.mediumGray,
          size: 64,
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String text;

    switch (_status) {
      case 'available':
        color = Colors.green;
        text = 'Available';
        break;
      case 'claimed':
        color = AppTheme.receiverOrange;
        text = 'Claimed';
        break;
      case 'delivered':
        color = AppTheme.donorGreen;
        text = 'Delivered';
        break;
      default:
        color = AppTheme.mediumGray;
        text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
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

  Widget _buildDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Donation Details',
            style: AppTheme.heading3,
          ),
          const SizedBox(height: 16),

          // Donor info
          _buildDetailRow(
            icon: Icons.person,
            label: 'Donor',
            value: _donorName ?? 'Loading...',
          ),
          const SizedBox(height: 12),

          // Pickup time
          _buildDetailRow(
            icon: Icons.schedule,
            label: 'Pickup Time',
            value: _formatDateTime(widget.donation.pickupTime),
          ),
          const SizedBox(height: 12),

          // Delivery type
          _buildDetailRow(
            icon: widget.donation.deliveryType == 'pickup' 
                ? Icons.location_on 
                : Icons.delivery_dining,
            label: 'Type',
            value: widget.donation.deliveryType == 'pickup' ? 'Pickup' : 'Delivery',
          ),

          // Food details
          if (widget.donation.foodType != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.restaurant,
              label: 'Food Type',
              value: widget.donation.foodType!,
            ),
          ],

          if (widget.donation.quantity != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.scale,
              label: 'Quantity',
              value: widget.donation.quantity!,
            ),
          ],

          // Market address
          if (widget.donation.marketAddress != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.location_on,
              label: 'Location',
              value: widget.donation.marketAddress!,
            ),
          ],

          // Allergens
          if (widget.donation.allergensList.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Allergens',
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        children: widget.donation.allergensList.map((allergen) {
                          return Container(
                            margin: const EdgeInsets.only(right: 4, bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Text(
                              allergen,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.donorGreen, size: 20),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Mark as Received button (only for claimed donations)
        if (_status == 'claimed')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _confirmDelivery,
              style: AppTheme.receiverButtonStyle,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text(
                'Mark as Received',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // View feedback button (only for delivered donations)
        if (_status == 'delivered') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _viewFeedback,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.donorGreen,
                side: const BorderSide(color: AppTheme.donorGreen),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.star),
              label: const Text(
                'View Feedback',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDelivery() async {
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final success = await _deliveryService.confirmDelivery(widget.donation.id);
      
      if (success) {
        // Show feedback dialog
      } else {
        Get.snackbar(
          'Error',
          'Failed to confirm delivery',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to confirm delivery: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: const Text(
          'Have you received the food donation? This will notify the donor and allow you to provide feedback.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.receiverButtonStyle,
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }


  void _viewFeedback() {
    // Navigate to feedback view screen or show feedback in a dialog
    Get.snackbar(
      'Info',
      'Feedback viewing feature will be implemented',
      backgroundColor: AppTheme.donorGreen,
      colorText: Colors.white,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
