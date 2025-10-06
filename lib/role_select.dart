import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:capstone_project/MarketDonor/login_donor.dart';
import 'package:capstone_project/FoodReceiver/login_receiver.dart';

class RoleSelect extends StatefulWidget {
  const RoleSelect({super.key});

  @override
  State<RoleSelect> createState() => _RoleSelectState();
}

class _RoleSelectState extends State<RoleSelect> {
  double _donorButtonScale = 1.0;
  double _receiverButtonScale = 1.0;
  final double _maxScale = 1.3;
  final double _minScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Color(0xFFF1F5F9),
              Color(0xFFE0F7FA),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with welcome text
                Column(
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'Welcome to FOODO',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fighting hunger together',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Lottie animation
                Expanded(
                  child: Center(
                    child: Lottie.asset(
                      'assets/lottie_files/role_selection.json',
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                
                // Role selection section
                Column(
                  children: [
                    const Text(
                      'Choose your role to continue',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Draggable Market Donor Button
                    _buildDraggableButton(
                      scale: _donorButtonScale,
                      onScaleUpdate: (scale) => setState(() => _donorButtonScale = scale),
                      onTap: () => Get.to(const DonorLogin()),
                      backgroundColor: const Color(0xFF22c55e),
                      icon: Icons.storefront_rounded,
                      label: 'I\'m a Market Donor',
                    ),
                    const SizedBox(height: 20),
                    
                    // Draggable Food Receiver Button
                    _buildDraggableButton(
                      scale: _receiverButtonScale,
                      onScaleUpdate: (scale) => setState(() => _receiverButtonScale = scale),
                      onTap: () => Get.to(const ReceiverLogin()),
                      backgroundColor: const Color(0xFFFF8C00),
                      icon: Icons.volunteer_activism_rounded,
                      label: 'I\'m a Food Receiver',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableButton({
    required double scale,
    required Function(double) onScaleUpdate,
    required VoidCallback onTap,
    required Color backgroundColor,
    required IconData icon,
    required String label,
  }) {
    return GestureDetector(
      onPanUpdate: (details) {
        // Calculate scale based on drag distance
        double newScale = _minScale + (details.delta.distance.abs() / 100).clamp(0.0, _maxScale - _minScale);
        onScaleUpdate(newScale);
      },
      onPanEnd: (_) {
        // Animate back to original size when drag ends
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              onScaleUpdate(_minScale);
            });
          }
        });
        
        // Trigger the tap action after a short delay
        Future.delayed(const Duration(milliseconds: 100), onTap);
      },
      onPanCancel: () {
        // Animate back to original size when drag is cancelled
        if (mounted) {
          setState(() {
            onScaleUpdate(_minScale);
          });
        }
      },
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 28, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}