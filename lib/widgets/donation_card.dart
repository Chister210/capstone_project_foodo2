import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/donation_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DonationCard extends StatelessWidget {
  final DonationModel donation;
  final VoidCallback? onTap;
  final VoidCallback? onClaim;
  final bool isDonorView;

  const DonationCard({
    super.key,
    required this.donation,
    this.onTap,
    this.onClaim,
    this.isDonorView = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showDonationDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                image: DecorationImage(
                  image: _getImageProvider(donation.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  // Status Badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildStatusBadge(),
                  ),
                  // Time Badge - removed per user request
                  // Positioned(
                  //   bottom: 12,
                  //   left: 12,
                  //   child: _buildTimeBadge(),
                  // ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Food Type
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          donation.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      // Food Type Badge
                      if (donation.foodType != null && donation.foodType!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getFoodTypeColor(donation.foodType!).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getFoodTypeColor(donation.foodType!).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            donation.foodType!,
                            style: TextStyle(
                              color: _getFoodTypeColor(donation.foodType!),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Market Name with Rating
                  FutureBuilder<Map<String, dynamic>>(
                    future: _getMarketInfo(donation.donorId),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final marketName = snapshot.data!['name'] as String?;
                        final marketRating = snapshot.data!['rating'] as double?;
                        
                        if (marketName != null) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.storefront,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  marketName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (marketRating != null && marketRating > 0) ...[
                                  const SizedBox(width: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        marketRating.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  
                  // Description
                  Text(
                    donation.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // Food Details Row
                  _buildFoodDetailsRow(),
                  const SizedBox(height: 8),
                  
                  // Delivery and Quantity Info
                  Row(
                    children: [
                      // Delivery Type
                      _buildDetailChip(
                        icon: donation.deliveryType == 'pickup' 
                            ? Icons.location_on_rounded 
                            : Icons.delivery_dining_rounded,
                        label: donation.deliveryType == 'pickup' ? 'Pickup' : 'Delivery',
                        color: donation.deliveryType == 'pickup' 
                            ? const Color(0xFF3b82f6) 
                            : const Color(0xFF22c55e),
                      ),
                      const SizedBox(width: 8),
                      
                      // Quantity with remaining info
                      if (donation.quantity != null && donation.quantity!.isNotEmpty)
                        _buildDetailChip(
                          icon: Icons.scale_rounded,
                          label: _buildQuantityLabel(donation),
                          color: const Color(0xFFf59e0b),
                        ),
                      
                      // Donor Info (only for recipients)
                      if (!isDonorView) ...[
                        if (donation.quantity != null && donation.quantity!.isNotEmpty)
                          const SizedBox(width: 8),
                        _buildDetailChip(
                          icon: Icons.person_rounded,
                          label: donation.donorEmail.split('@')[0],
                          color: const Color(0xFF6b7280),
                        ),
                      ],
                    ],
                  ),
                  
                  // Allergens (if any)
                  if (donation.allergens != null && donation.allergens!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Contains: ${donation.allergens!.join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  
                  // Pickup Time
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pickup by ${_formatPickupTime(donation.pickupTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  // Expiration Time (if available)
                  if (donation.expirationDateTime != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_off_rounded,
                          size: 16,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Expires: ${_formatPickupTime(donation.expirationDateTime!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Location Info (if available)
                  if (donation.address != null && donation.address!.isNotEmpty)
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                donation.address!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  
                  // Action Buttons
                  if (onClaim != null && (donation.status == 'available' || (donation.hasPartialClaims && !donation.isFullyClaimed)))
                    Builder(
                      builder: (context) {
                        // Check if current user has already claimed some quantity
                        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                        final userHasClaimed = currentUserId != null && 
                            donation.quantityClaims != null && 
                            donation.quantityClaims!.containsKey(currentUserId) &&
                            (donation.quantityClaims![currentUserId] ?? 0) > 0;
                        
                        final hasPartialClaims = donation.hasPartialClaims;
                        
                        return Column(
                          children: [
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: donation.isFullyClaimed ? null : onClaim,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: donation.isFullyClaimed 
                                      ? Colors.grey 
                                      : const Color(0xFF22c55e),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  donation.isFullyClaimed 
                                      ? 'Fully Claimed'
                                      : (userHasClaimed
                                          ? 'Claim More' 
                                          : 'Claim Donation'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            // Show remaining quantity info
                            if (hasPartialClaims && !donation.isFullyClaimed)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${donation.remainingQuantity ?? donation.totalQuantity ?? 0} remaining',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  
                  // Confirmation status for claimed donations
                  if (donation.status == 'claimed' || (donation.status == 'in_progress' && !donation.isFullyConfirmed))
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                donation.isFullyConfirmed ? Icons.check_circle : Icons.pending,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  donation.isFullyConfirmed
                                      ? 'Donation fully claimed'
                                      : 'Donation in progress',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDonationDetails(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Image
                  Stack(
                    children: [
                      Container(
                        height: 200, // Reduced height for better fit
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          image: DecorationImage(
                            image: _getImageProvider(donation.imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _buildStatusBadge(),
                      ),
                      // Time Badge - removed per user request
                      // Positioned(
                      //   top: 16,
                      //   left: 16,
                      //   child: _buildTimeBadge(),
                      // ),
                    ],
                  ),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20), // Reduced padding
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Food Type
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                donation.title,
                                style: const TextStyle(
                                  fontSize: 20, // Slightly smaller font
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (donation.foodType != null && donation.foodType!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getFoodTypeColor(donation.foodType!).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getFoodTypeColor(donation.foodType!).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  donation.foodType!,
                                  style: TextStyle(
                                    color: _getFoodTypeColor(donation.foodType!),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Full Description
                        Text(
                          donation.description,
                          style: TextStyle(
                            fontSize: 14, // Smaller font
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Food Details Section
                        _buildDetailsSection(context),
                        
                        // Donor Information
                        if (!isDonorView) 
                          Column(
                            children: [
                              const SizedBox(height: 16),
                              _buildDonorSection(),
                            ],
                          ),
                        
                        // Action Buttons
                        if (onClaim != null && donation.status == 'available')
                          Column(
                            children: [
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context); // Close dialog
                                    onClaim!(); // Trigger claim action
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF22c55e),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14), // Reduced padding
                                  ),
                                  child: const Text(
                                    'Claim This Donation',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        
                        // Close Button
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14), // Reduced padding
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

// Also update the _buildDetailsSection to be more compact
Widget _buildDetailsSection(BuildContext context) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Food Details',
        style: TextStyle(
          fontSize: 16, // Smaller font
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      const SizedBox(height: 12),
      
      // Food Details Grid - More compact
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 8, // Reduced spacing
        mainAxisSpacing: 8,  // Reduced spacing
        childAspectRatio: 2.5, // More compact aspect ratio
        children: [
          _buildDetailItem(
            icon: Icons.category_rounded,
            title: 'Food Type',
            value: donation.foodType ?? 'Not specified',
            color: _getFoodTypeColor(donation.foodType ?? 'Other'),
          ),
          _buildDetailItem(
            icon: Icons.scale_rounded,
            title: 'Quantity',
            value: donation.quantity ?? 'Not specified',
            color: const Color(0xFFf59e0b),
          ),
          _buildDetailItem(
            icon: donation.deliveryType == 'pickup' 
                ? Icons.location_on_rounded 
                : Icons.delivery_dining_rounded,
            title: 'Delivery Type',
            value: donation.deliveryType == 'pickup' ? 'Pickup' : 'Delivery',
            color: donation.deliveryType == 'pickup' 
                ? const Color(0xFF3b82f6) 
                : const Color(0xFF22c55e),
          ),
          _buildDetailItem(
            icon: Icons.access_time_rounded,
            title: 'Pickup Time',
            value: DateFormat('h:mm a').format(donation.pickupTime),
            color: const Color(0xFF8b5cf6),
            valueFontSize: 10, // Smaller font size for pickup time
          ),
        ],
      ),
      
      // Allergens
      if (donation.allergens != null && donation.allergens!.isNotEmpty) ...[
        const SizedBox(height: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Allergens',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: donation.allergens!.map((allergen) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    allergen,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
      
      // Location
      if (donation.address != null && donation.address!.isNotEmpty) ...[
        const SizedBox(height: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    donation.address!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      
      // Market Location (if available)
      if (donation.marketAddress != null && donation.marketAddress!.isNotEmpty) ...[
        const SizedBox(height: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Market Location',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.store_rounded,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    donation.marketAddress!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ],
  );
}

// Update the _buildDetailItem to be more compact
Widget _buildDetailItem({
  required IconData icon,
  required String title,
  required String value,
  required Color color,
  double? valueFontSize, // Optional custom font size for value
}) {
  return Container(
    padding: const EdgeInsets.all(10), // Reduced padding
    decoration: BoxDecoration(
      color: color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14, // Smaller icon
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 11, // Smaller font
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: Colors.black,
            fontSize: valueFontSize ?? 12, // Use custom size if provided, else default to 12
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

// Update the _buildDonorSection to be more compact
Widget _buildDonorSection() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Donor Information',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12), // Reduced padding
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 36, // Smaller container
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF22c55e),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 18, // Smaller icon
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    donation.donorEmail.split('@')[0],
                    style: const TextStyle(
                      fontSize: 14, // Smaller font
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    donation.donorEmail,
                    style: TextStyle(
                      fontSize: 12, // Smaller font
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}



  Widget _buildFoodDetailsRow() {
    final List<Widget> detailItems = [];
    
    // Add food type if available
    if (donation.foodType != null && donation.foodType!.isNotEmpty) {
      detailItems.add(
        Expanded(
          child: _buildFoodDetailItem(
            icon: Icons.category_rounded,
            title: 'Type',
            value: donation.foodType!,
            color: _getFoodTypeColor(donation.foodType!),
          ),
        ),
      );
    }
    
    // Add quantity if available
    if (donation.quantity != null && donation.quantity!.isNotEmpty) {
      if (detailItems.isNotEmpty) detailItems.add(const SizedBox(width: 8));
      detailItems.add(
        Expanded(
          child: _buildFoodDetailItem(
            icon: Icons.scale_rounded,
            title: 'Quantity',
            value: donation.quantity!,
            color: const Color(0xFFf59e0b),
          ),
        ),
      );
    }
    
    // Add delivery type
    if (detailItems.isNotEmpty) detailItems.add(const SizedBox(width: 8));
    detailItems.add(
      Expanded(
        child: _buildFoodDetailItem(
          icon: donation.deliveryType == 'pickup' 
              ? Icons.location_on_rounded 
              : Icons.delivery_dining_rounded,
          title: 'Delivery',
          value: donation.deliveryType == 'pickup' ? 'Pickup' : 'Delivery',
          color: donation.deliveryType == 'pickup' 
              ? const Color(0xFF3b82f6) 
              : const Color(0xFF22c55e),
        ),
      ),
    );
    
    return Row(
      children: detailItems,
    );
  }

  Widget _buildFoodDetailItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    // If donation is expired, don't show a badge
    if (donation.status == 'expired') {
      return const SizedBox.shrink();
    }

    Color backgroundColor;
    Color textColor;
    String text;

    // Check if donation has partial claims
    final hasPartial = donation.hasPartialClaims;
    final isFullyClaimed = donation.isFullyClaimed;

    switch (donation.status) {
      case 'available':
        if (hasPartial) {
          backgroundColor = const Color(0xFFFF8C00);
          textColor = Colors.white;
          final remaining = donation.remainingQuantity ?? donation.totalQuantity ?? 0;
          text = '$remaining left';
        } else {
          backgroundColor = const Color(0xFF22c55e);
          textColor = Colors.white;
          text = 'Available';
        }
        break;
      case 'claimed':
        if (!isFullyClaimed && hasPartial) {
          backgroundColor = const Color(0xFFFF8C00);
          textColor = Colors.white;
          final remaining = donation.remainingQuantity ?? 0;
          text = '$remaining left';
        } else {
          backgroundColor = const Color(0xFF3b82f6);
          textColor = Colors.white;
          text = 'Claimed';
        }
        break;
      case 'completed':
        backgroundColor = const Color(0xFF6b7280);
        textColor = Colors.white;
        text = 'Completed';
        break;
      default:
        if (hasPartial && !isFullyClaimed) {
          backgroundColor = const Color(0xFFFF8C00);
          textColor = Colors.white;
          final remaining = donation.remainingQuantity ?? donation.totalQuantity ?? 0;
          text = '$remaining left';
        } else {
          backgroundColor = Colors.grey;
          textColor = Colors.white;
          text = 'Unknown';
        }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTimeBadge() {
    final now = DateTime.now();
    final timeDiff = donation.pickupTime.difference(now);
    final hoursLeft = timeDiff.inHours;
    final minutesLeft = timeDiff.inMinutes % 60;

    // If already expired, don't show the time badge
    if (timeDiff.isNegative) {
      return const SizedBox.shrink();
    }

    String timeText;
    Color backgroundColor;

    if (hoursLeft < 1) {
      timeText = '${minutesLeft}m left';
      backgroundColor = const Color(0xFFef4444);
    } else if (hoursLeft < 24) {
      timeText = '${hoursLeft}h left';
      backgroundColor = const Color(0xFFFF8C00);
    } else {
      timeText = '${timeDiff.inDays}d left';
      backgroundColor = const Color(0xFF22c55e);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        timeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getFoodTypeColor(String foodType) {
    switch (foodType.toLowerCase()) {
      case 'produce':
        return const Color(0xFF22c55e);
      case 'bakery':
        return const Color(0xFFf59e0b);
      case 'protein':
        return const Color(0xFFef4444);
      case 'dairy':
        return const Color(0xFF3b82f6);
      case 'prepared food':
        return const Color(0xFF8b5cf6);
      default:
        return const Color(0xFF6b7280);
    }
  }

  String _formatPickupTime(DateTime pickupTime) {
    final now = DateTime.now();
    if (pickupTime.day == now.day) {
      return 'Today ${DateFormat('h:mm a').format(pickupTime)}';
    } else if (pickupTime.day == now.day + 1) {
      return 'Tomorrow ${DateFormat('h:mm a').format(pickupTime)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(pickupTime);
    }
  }

  String _buildQuantityLabel(DonationModel donation) {
    if (donation.quantity == null) return '';
    
    final hasQuantity = donation.totalQuantity != null && donation.totalQuantity! > 0;
    if (hasQuantity && donation.remainingQuantity != null) {
      final remaining = donation.remainingQuantity!;
      final total = donation.totalQuantity!;
      
      if (remaining < total) {
        // Show remaining quantity
        return '${donation.quantity} ($remaining left)';
      }
    }
    
    return donation.quantity!;
  }

  // Fetch market name and rating from donor's user document and feedback
  Future<Map<String, dynamic>> _getMarketInfo(String donorId) async {
    try {
      final donorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(donorId)
          .get();
      
      if (donorDoc.exists) {
        final data = donorDoc.data();
        final marketName = data?['marketName'] as String?;
        
        // Get market rating from feedback (average of marketRating)
        double? marketRating;
        try {
          final feedbackSnapshot = await FirebaseFirestore.instance
              .collection('feedback')
              .where('donorId', isEqualTo: donorId)
              .where('isVisible', isEqualTo: true)
              .get();
          
          final marketRatings = feedbackSnapshot.docs
              .map((doc) => doc.data()['marketRating'] as int?)
              .where((rating) => rating != null)
              .toList();
          
          if (marketRatings.isNotEmpty) {
            marketRating = marketRatings.reduce((a, b) => a! + b!)! / marketRatings.length;
          }
        } catch (e) {
          // If feedback query fails, continue without rating
          debugPrint('Error fetching market rating: $e');
        }
        
        return {
          'name': marketName,
          'rating': marketRating,
        };
      }
    } catch (e) {
      debugPrint('Error fetching market info: $e');
    }
    return {};
  }

  ImageProvider _getImageProvider(String imageUrl) {
    try {
      if (imageUrl.startsWith('data:image')) {
        // Base64 image
        final parts = imageUrl.split(',');
        if (parts.length > 1) {
          final base64String = parts[1];
          final bytes = base64Decode(base64String);
          // Only use MemoryImage if bytes are large enough for a valid image
          if (bytes.isNotEmpty && bytes.length > 100) {
            return MemoryImage(bytes);
          }
        }
        // Fallback to default asset if base64 is invalid or too small
        return const AssetImage('assets/logos/logo.png');
      } else if (imageUrl.isNotEmpty) {
        // Network image (fallback)
        // Only use NetworkImage if the URL looks valid
        if (imageUrl.startsWith('http') || imageUrl.startsWith('https')) {
          return NetworkImage(imageUrl);
        } else {
          return const AssetImage('assets/logos/logo.png');
        }
      } else {
        // Fallback to default asset if empty
        return const AssetImage('assets/logos/logo.png');
      }
    } catch (e) {
      // Fallback to default asset on any error
      return const AssetImage('assets/logos/logo.png');
    }
  }
}