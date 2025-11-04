import 'package:flutter/material.dart';

class QuantitySelectorDialog extends StatefulWidget {
  final int maxQuantity;
  final int currentQuantity;
  final String donationTitle;
  final String? quantityUnit; // e.g., "kg", "boxes", "items"

  const QuantitySelectorDialog({
    super.key,
    required this.maxQuantity,
    this.currentQuantity = 0,
    required this.donationTitle,
    this.quantityUnit,
  });

  @override
  State<QuantitySelectorDialog> createState() => _QuantitySelectorDialogState();
}

class _QuantitySelectorDialogState extends State<QuantitySelectorDialog> {
  late int _selectedQuantity;
  final TextEditingController _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedQuantity = widget.currentQuantity > 0 ? widget.currentQuantity : 1;
    _quantityController.text = _selectedQuantity.toString();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(int delta) {
    setState(() {
      final newQuantity = (_selectedQuantity + delta).clamp(1, widget.maxQuantity);
      _selectedQuantity = newQuantity;
      _quantityController.text = newQuantity.toString();
    });
  }

  void _onQuantityChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      setState(() {
        _selectedQuantity = parsed.clamp(1, widget.maxQuantity);
        _quantityController.text = _selectedQuantity.toString();
      });
    } else if (value.isEmpty) {
      _quantityController.text = '1';
      setState(() => _selectedQuantity = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final padding = isSmallScreen ? 20.0 : 24.0;
    final unit = widget.quantityUnit ?? '';
    final unitText = unit.isNotEmpty ? ' $unit' : '';
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: 24,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: size.width > 500 ? 450 : size.width * 0.9,
        ),
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: isSmallScreen ? 44 : 52,
                        height: isSmallScreen ? 44 : 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22c55e).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shopping_cart_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Quantity',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.donationTitle,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 20 : 24),
            
            // Available quantity info
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3b82f6).withOpacity(0.1),
                    const Color(0xFF2563eb).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF3b82f6).withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3b82f6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: Color(0xFF3b82f6),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Quantity',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.maxQuantity}$unitText',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF3b82f6),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 28),
            
            // Quantity selector with larger buttons
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 16 : 20,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decrease button - larger and more touchable
                  _buildQuantityButton(
                    icon: Icons.remove_rounded,
                    onTap: _selectedQuantity > 1 ? () => _updateQuantity(-1) : null,
                    isEnabled: _selectedQuantity > 1,
                    isSmallScreen: isSmallScreen,
                  ),
                  
                  // Quantity display and input
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: isSmallScreen ? 50 : 60,
                          child: TextField(
                            controller: _quantityController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 36 : 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: 1,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: _onQuantityChanged,
                          ),
                        ),
                        if (unit.isNotEmpty)
                          Text(
                            unit,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Increase button - larger and more touchable
                  _buildQuantityButton(
                    icon: Icons.add_rounded,
                    onTap: _selectedQuantity < widget.maxQuantity
                        ? () => _updateQuantity(1)
                        : null,
                    isEnabled: _selectedQuantity < widget.maxQuantity,
                    isSmallScreen: isSmallScreen,
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 20 : 24),
            
            // Quick select buttons - responsive grid
            if (widget.maxQuantity > 5)
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Quick Select',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: isSmallScreen ? 8 : 10,
                      runSpacing: isSmallScreen ? 8 : 10,
                      alignment: WrapAlignment.center,
                      children: [
                        if (widget.maxQuantity >= 5)
                          _buildQuickButton(5, isSmallScreen),
                        if (widget.maxQuantity >= 10)
                          _buildQuickButton(10, isSmallScreen),
                        if (widget.maxQuantity >= 25)
                          _buildQuickButton(25, isSmallScreen),
                        if (widget.maxQuantity >= 50)
                          _buildQuickButton(50, isSmallScreen),
                        if (widget.maxQuantity != 5 &&
                            widget.maxQuantity != 10 &&
                            widget.maxQuantity != 25 &&
                            widget.maxQuantity != 50 &&
                            widget.maxQuantity < 100)
                          _buildQuickButton(widget.maxQuantity, isSmallScreen),
                      ],
                    ),
                  ],
                ),
              ),
            SizedBox(height: isSmallScreen ? 20 : 24),
            
            // Action buttons - responsive
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                    isPrimary: false,
                    isSmallScreen: isSmallScreen,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 10 : 12),
                Expanded(
                  flex: 2,
                  child: _buildActionButton(
                    label: 'Claim $_selectedQuantity$unitText',
                    onPressed: () => Navigator.pop(context, _selectedQuantity),
                    isPrimary: true,
                    isSmallScreen: isSmallScreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isEnabled,
    required bool isSmallScreen,
  }) {
    final buttonSize = isSmallScreen ? 56.0 : 64.0;
    final iconSize = isSmallScreen ? 28.0 : 32.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            gradient: isEnabled
                ? const LinearGradient(
                    colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isEnabled ? null : Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF22c55e).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isEnabled ? Colors.white : Colors.grey[400],
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickButton(int value, bool isSmallScreen) {
    final isSelected = _selectedQuantity == value;
    final unit = widget.quantityUnit ?? '';
    final unitText = unit.isNotEmpty ? ' $unit' : '';
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedQuantity = value.clamp(1, widget.maxQuantity);
            _quantityController.text = _selectedQuantity.toString();
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 18 : 22,
            vertical: isSmallScreen ? 10 : 12,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF22c55e)
                  : Colors.grey[300]!,
              width: isSelected ? 2 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF22c55e).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Text(
            '$value$unitText',
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 13 : 14,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
    required bool isSmallScreen,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 15 : 16,
          ),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [Color(0xFF22c55e), Color(0xFF16a34a)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isPrimary ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isPrimary
                ? null
                : Border.all(
                    color: Colors.grey[300]!,
                    width: 1.5,
                  ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: const Color(0xFF22c55e).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 15 : 16,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}