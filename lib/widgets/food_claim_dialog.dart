import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/donation_model.dart';
import 'quantity_selector_dialog.dart';

/// Modern, streamlined claim dialog inspired by Food Panda/Grab
/// Combines quantity selection and confirmation into a single smooth flow
class FoodClaimDialog extends StatefulWidget {
  final DonationModel donation;
  final VoidCallback? onSuccess;

  const FoodClaimDialog({
    super.key,
    required this.donation,
    this.onSuccess,
  });

  @override
  State<FoodClaimDialog> createState() => _FoodClaimDialogState();
}

class _FoodClaimDialogState extends State<FoodClaimDialog>
    with SingleTickerProviderStateMixin {
  int? _selectedQuantity;
  bool _isClaiming = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();

    // Auto-select quantity for donations with quantity
    final hasQuantity = widget.donation.totalQuantity != null &&
        widget.donation.totalQuantity! > 0;
    if (hasQuantity) {
      final remaining = widget.donation.remainingQuantity ?? widget.donation.totalQuantity ?? 1;
      _selectedQuantity = remaining > 0 ? 1 : null; // Default to 1 if available, never allow 0
    } else {
      _selectedQuantity = null; // No quantity for non-quantity donations
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String? _getUnit() {
    if (widget.donation.quantity == null) return null;
    // Extract unit, removing any "0" values
    // Handle formats like "90 kg", "90 0 kg", etc.
    final quantityStr = widget.donation.quantity!.trim();
    
    // Extract text after the first number (which is the quantity)
    final match = RegExp(r'^\d+\s*(.+)$').firstMatch(quantityStr);
    if (match == null) return null;
    
    var unit = match.group(1)?.trim() ?? '';
    if (unit.isEmpty) return null;
    
    // Remove any standalone "0" values from the unit
    // Split by spaces, filter out "0", then rejoin
    final parts = unit.split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty && part.trim() != '0')
        .toList();
    
    unit = parts.join(' ').trim();
    
    // Additional cleanup: remove any remaining "0" patterns
    unit = unit
        .replaceAll(RegExp(r'^\s*0+\s+'), '') // Remove leading "0 "
        .replaceAll(RegExp(r'\s+0+\s+'), ' ') // Remove " 0 " in middle
        .replaceAll(RegExp(r'\s+0+\s*$'), '') // Remove trailing " 0"
        .trim();
    
    return unit.isEmpty ? null : unit;
  }

  int _getRemainingQuantity() {
    final remaining = widget.donation.remainingQuantity ??
        widget.donation.totalQuantity ??
        0;
    // Ensure it's a whole number (int), never negative, never 0 when displaying
    // Convert to int and clamp to ensure whole number
    final intValue = (remaining is int) 
        ? remaining 
        : (remaining is double) 
            ? remaining.round().toInt() 
            : 0;
    return intValue.clamp(0, 999999); // Max reasonable value
  }

  int _getTotalQuantity() {
    return widget.donation.totalQuantity ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final hasQuantity = _getTotalQuantity() > 0;
    final remainingQuantity = _getRemainingQuantity();
    final unit = _getUnit();
    final unitText = unit != null && unit.isNotEmpty ? ' $unit' : '';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: 24,
      ),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.8 + (_animationController.value * 0.2),
            child: Opacity(
              opacity: _animationController.value,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: size.width > 500 ? 450 : size.width * 0.9,
                  maxHeight: size.height * 0.8,
                ),
                padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with image and title
                      _buildHeader(isSmallScreen),
                      SizedBox(height: isSmallScreen ? 16 : 20),

                      // Donation info card
                      _buildDonationInfoCard(unitText, remainingQuantity, hasQuantity),
                      SizedBox(height: isSmallScreen ? 16 : 20),

                      // Quantity selector (if applicable)
                      if (hasQuantity && remainingQuantity > 0) ...[
                        _buildQuantitySelector(unitText, remainingQuantity),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                      ],

                      // Delivery/Pickup info
                      _buildDeliveryInfo(),
                      SizedBox(height: isSmallScreen ? 16 : 20),

                      // Action buttons - ensure they fit
                      _buildActionButtons(hasQuantity),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Donation image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            widget.donation.imageUrl,
            width: isSmallScreen ? 70 : 80,
            height: isSmallScreen ? 70 : 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: isSmallScreen ? 70 : 80,
              height: isSmallScreen ? 70 : 80,
              color: Colors.grey[200],
              child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
            ),
          ),
        ),
        SizedBox(width: isSmallScreen ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.donation.title,
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (widget.donation.foodCategory != null)
                Text(
                  widget.donation.foodCategory!,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _isClaiming ? null : () => Navigator.pop(context),
          color: Colors.grey[600],
        ),
      ],
    );
  }

  Widget _buildDonationInfoCard(
      String unitText, int remainingQuantity, bool hasQuantity) {
    final isAvailable = !hasQuantity || remainingQuantity > 0;
    
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAvailable
              ? [Colors.green[50]!, Colors.green[100]!]
              : [Colors.grey[100]!, Colors.grey[200]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAvailable
              ? Colors.green[200]!
              : Colors.grey[300]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isAvailable
                ? Colors.green.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: isAvailable
                  ? const LinearGradient(
                      colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                    )
                  : null,
              color: isAvailable ? null : Colors.grey[300],
              borderRadius: BorderRadius.circular(14),
              boxShadow: isAvailable
                  ? [
                      BoxShadow(
                        color: const Color(0xFF22c55e).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isAvailable ? Icons.check_circle_rounded : Icons.close_rounded,
              color: isAvailable ? Colors.white : Colors.grey[600],
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasQuantity ? 'Available Quantity' : 'Status',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasQuantity
                      ? (remainingQuantity > 0
                          ? '$remainingQuantity$unitText' // Already an int from _getRemainingQuantity
                          : 'Fully claimed')
                      : 'Available',
                  style: TextStyle(
                    fontSize: 22,
                    color: isAvailable
                        ? const Color(0xFF22c55e)
                        : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(String unitText, int remainingQuantity) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final isMediumScreen = size.width >= 360 && size.width < 414;
    final unit = _getUnit();
    
    // Responsive sizing - smaller buttons to prevent overlap
    final buttonSize = isSmallScreen ? 36.0 : (isMediumScreen ? 40.0 : 44.0);
    final fontSize = isSmallScreen ? 28.0 : (isMediumScreen ? 32.0 : 36.0);
    final spacing = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);
    final padding = isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 18.0);
    final headerFontSize = isSmallScreen ? 13.0 : 15.0;
    
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and unit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                        ),
                        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22c55e).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.shopping_bag_rounded,
                        size: isSmallScreen ? 18 : 20,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 10 : 12),
                    Flexible(
                      child: Text(
                        'Select Quantity',
                        style: TextStyle(
                          fontSize: headerFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (unit != null) ...[
                SizedBox(width: isSmallScreen ? 8 : 12),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 10 : 12,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 20 : 24),
          
          // Main quantity selector - responsive and modern
          Container(
            padding: EdgeInsets.symmetric(
              vertical: isSmallScreen ? 12 : 16,
              horizontal: isSmallScreen ? 8 : 12,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey[50]!,
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 20),
              border: Border.all(
                color: Colors.grey[200]!,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decrease button
                _buildQuantityButton(
                  icon: Icons.remove_rounded,
                  size: buttonSize,
                  onTap: () {
                    if (_selectedQuantity != null && _selectedQuantity! > 1) {
                      setState(() {
                        final newValue = (_selectedQuantity! - 1).clamp(1, remainingQuantity);
                        _selectedQuantity = newValue > 0 ? newValue : 1;
                      });
                    }
                  },
                  enabled: _selectedQuantity != null && _selectedQuantity! > 1,
                ),
                
                SizedBox(width: spacing),
                
                // Quantity display - responsive (never show 0)
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: isSmallScreen ? 40 : (isMediumScreen ? 50 : 60),
                      maxWidth: isSmallScreen ? 80 : (isMediumScreen ? 100 : 120),
                    ),
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Builder(
                        builder: (context) {
                          final displayQty = _selectedQuantity ?? 1;
                          // Never show 0, always at least 1
                          final safeQty = (displayQty > 0) ? displayQty : 1;
                          return Text(
                            '$safeQty',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                              letterSpacing: -1,
                              height: 1.0,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.08),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                SizedBox(width: spacing),
                
                // Increase button
                _buildQuantityButton(
                  icon: Icons.add_rounded,
                  size: buttonSize,
                  onTap: () {
                    if (_selectedQuantity != null && _selectedQuantity! < remainingQuantity) {
                      setState(() {
                        final newValue = (_selectedQuantity! + 1).clamp(1, remainingQuantity);
                        _selectedQuantity = newValue;
                      });
                    }
                  },
                  enabled: _selectedQuantity != null &&
                      _selectedQuantity! < remainingQuantity,
                ),
              ],
            ),
          ),
          
          // Quick select buttons for larger quantities - responsive
          if (remainingQuantity > 5) ...[
            SizedBox(height: isSmallScreen ? 16 : 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final isVerySmall = availableWidth < 300;
                final buttonSpacing = isVerySmall ? 6.0 : (isSmallScreen ? 8.0 : 10.0);
                final buttonPadding = isVerySmall
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    : (isSmallScreen
                        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 9)
                        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10));
                final buttonFontSize = isVerySmall ? 12.0 : (isSmallScreen ? 13.0 : 14.0);
                
                return Wrap(
                  spacing: buttonSpacing,
                  runSpacing: buttonSpacing,
                  alignment: WrapAlignment.center,
                  children: [
                    if (remainingQuantity >= 5) _buildQuickButton(5, padding: buttonPadding, fontSize: buttonFontSize),
                    if (remainingQuantity >= 10) _buildQuickButton(10, padding: buttonPadding, fontSize: buttonFontSize),
                    if (remainingQuantity >= 25) _buildQuickButton(25, padding: buttonPadding, fontSize: buttonFontSize),
                    _buildQuickButton(remainingQuantity, label: 'All', padding: buttonPadding, fontSize: buttonFontSize),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required double size,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(size / 3.5),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled ? null : Colors.grey[200],
            borderRadius: BorderRadius.circular(size / 3.5),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF22c55e).withOpacity(0.4),
                      blurRadius: size / 4,
                      offset: Offset(0, size / 14),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.grey[400],
            size: size * 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickButton(
    int value, {
    String? label,
    EdgeInsets? padding,
    double? fontSize,
  }) {
    final isSelected = _selectedQuantity == value;
    final remainingQuantity = _getRemainingQuantity();
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (value > 0 && value <= remainingQuantity) {
            setState(() {
              _selectedQuantity = value;
            });
          }
        },
        borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 18,
                vertical: isSmallScreen ? 8 : 10,
              ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF22c55e)
                  : Colors.grey[300]!,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF22c55e).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label ?? value.toString(),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[800],
              fontWeight: FontWeight.bold,
              fontSize: fontSize ?? (isSmallScreen ? 13 : 14),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    final isPickup = widget.donation.deliveryType == 'pickup';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPickup ? Colors.orange[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPickup ? Colors.orange[200]! : Colors.blue[200]!,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPickup ? Icons.store_rounded : Icons.delivery_dining_rounded,
            color: isPickup ? Colors.orange[700] : Colors.blue[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPickup ? 'Pickup Required' : 'Delivery',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isPickup ? Colors.orange[900] : Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPickup
                      ? 'You need to collect this from the market'
                      : 'The donor will deliver this to you',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPickup ? Colors.orange[800] : Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool hasQuantity) {
    final remainingQuantity = _getRemainingQuantity();
    final unit = _getUnit();
    final unitText = unit != null && unit.isNotEmpty ? ' $unit' : '';
    // Ensure claimQuantity is never null or 0, and is always a whole number (int)
    final rawQuantity = hasQuantity ? _selectedQuantity : null;
    final claimQuantity = (rawQuantity != null && rawQuantity > 0) 
        ? (rawQuantity)
        : (hasQuantity ? 1 : null);
    
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isClaiming
                ? null
                : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 12 : 14,
                horizontal: isSmallScreen ? 8 : 10,
              ),
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
              ),
              minimumSize: Size(0, isSmallScreen ? 44 : 48),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: (_isClaiming ||
                    (hasQuantity && remainingQuantity <= 0) ||
                    (hasQuantity && (claimQuantity == null || claimQuantity <= 0)))
                ? null
                : () => _handleClaim(claimQuantity),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22c55e),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 12 : 14,
                horizontal: isSmallScreen ? 8 : 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
              ),
              elevation: 2,
              minimumSize: Size(0, isSmallScreen ? 44 : 48),
            ),
            child: _isClaiming
                ? SizedBox(
                    height: isSmallScreen ? 18 : 20,
                    width: isSmallScreen ? 18 : 20,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      // Never show 0 - claimQuantity is guaranteed to be > 0 and an int if hasQuantity
                      if (hasQuantity && claimQuantity != null && claimQuantity > 0) {
                        final displayQty = claimQuantity; // Already an int
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Claim $displayQty$unitText',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 14 : 15,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text(
                          'Claim Food',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleClaim(int? claimQuantity) async {
    setState(() => _isClaiming = true);

    try {
      // Wait a bit for smooth animation
      await Future.delayed(const Duration(milliseconds: 300));

      // Return the selected quantity
      if (mounted) {
        Navigator.pop(context, {
          'quantity': claimQuantity,
          'success': true,
        });

        // Call success callback if provided
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }
      }
    } catch (e) {
      setState(() => _isClaiming = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

