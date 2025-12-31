import 'package:flutter/material.dart';
import '../services/terms_service.dart';

class TermsAndConditionsPopup extends StatefulWidget {
  final VoidCallback onAccepted;
  final VoidCallback onDeclined;

  const TermsAndConditionsPopup({
    super.key,
    required this.onAccepted,
    required this.onDeclined,
  });

  @override
  State<TermsAndConditionsPopup> createState() => _TermsAndConditionsPopupState();
}

class _TermsAndConditionsPopupState extends State<TermsAndConditionsPopup> {
  final TermsService _termsService = TermsService();
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _hasScrolledToBottom = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _checkInitialScroll();
    _loadTerms();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 100 && !_hasScrolledToBottom) {
      setState(() {
        _hasScrolledToBottom = true;
      });
    }
  }

  void _checkInitialScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final position = _scrollController.position;
      if (position.maxScrollExtent <= position.viewportDimension) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    });
  }

  Future<void> _loadTerms() async {
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() {
      _isInitializing = false;
    });
  }

  Future<void> _acceptTerms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _termsService.acceptTerms();
      widget.onAccepted();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting terms: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _declineTerms() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Terms Required'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To use Foodo, you must accept our Terms and Conditions.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'This ensures a safe and reliable experience for all users.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDeclined();
            },
            child: const Text(
              'Exit App',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22c55e),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue Reading'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(40),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF22c55e)),
            SizedBox(height: 20),
            Text(
              'Loading Terms and Conditions...',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Unable to load terms and conditions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please try again later',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22c55e),
                foregroundColor: Colors.white,
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final termsContent = _termsService.getTermsContent();
    
    if (_isInitializing) {
      return _buildLoadingState();
    }
    
    if (termsContent['title'] == null || termsContent['content'] == null) {
      return _buildErrorState();
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return WillPopScope(
      onWillPop: () async {
        _declineTerms();
        return false;
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.85,
            maxWidth: screenWidth * 0.95,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: screenHeight * 0.02,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22c55e).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.description_rounded,
                          color: Color(0xFF22c55e),
                          size: 24,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              termsContent['title']!,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Version ${termsContent['version']} • Updated ${termsContent['lastUpdated']}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: Column(
                      children: [
                        // Welcome message
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22c55e).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF22c55e).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF22c55e),
                                size: 20,
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Expanded(
                                child: Text(
                                  'Welcome to Foodo! Please read and accept our Terms and Conditions to continue.',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: screenWidth < 600 ? 13 : 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Terms content
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTermsSection(
                                  title: '1. Introduction',
                                  content: termsContent['introduction'] ?? termsContent['content']!,
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                _buildTermsSection(
                                  title: '2. User Responsibilities',
                                  content: termsContent['responsibilities'] ?? 'As a user of Foodo, you agree to maintain food safety standards, provide accurate information about donations, and respect other users. You are responsible for ensuring that all donated food meets safety requirements and is properly stored and handled.',
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                _buildTermsSection(
                                  title: '3. Food Safety',
                                  content: termsContent['safety'] ?? 'All food donations must comply with local food safety regulations. Donors must ensure food is fresh, properly stored, and free from contamination. Receivers should inspect donations when receiving them and report any concerns immediately.',
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                _buildTermsSection(
                                  title: '4. Privacy',
                                  content: 'We respect your privacy and are committed to protecting your personal information. Your data will only be used to facilitate food donations and improve our services.',
                                ),
                                
                                // Scroll to bottom indicator
                                if (!_hasScrolledToBottom)
                                  Container(
                                    width: double.infinity,
                                    margin: EdgeInsets.only(top: screenHeight * 0.02),
                                    padding: EdgeInsets.all(screenWidth * 0.03),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Colors.orange,
                                          size: 18,
                                        ),
                                        SizedBox(width: screenWidth * 0.02),
                                        Text(
                                          'Scroll to read complete terms',
                                          style: TextStyle(
                                            color: Colors.orange[800],
                                            fontSize: screenWidth < 600 ? 12 : 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Footer with buttons
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: screenHeight * 0.02,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Acceptance checkbox
                      Semantics(
                        label: 'I have read and agree to the Terms and Conditions',
                        child: Row(
                          children: [
                            Checkbox(
                              value: _hasScrolledToBottom,
                              onChanged: _hasScrolledToBottom ? (value) {} : null,
                              activeColor: const Color(0xFF22c55e),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Expanded(
                              child: Text(
                                'I have read and agree to the Terms and Conditions',
                                style: TextStyle(
                                  color: _hasScrolledToBottom ? Colors.black87 : Colors.grey[500],
                                  fontSize: screenWidth < 600 ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: screenHeight * 0.015),
                      
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _declineTerms,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey[400]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.015,
                                ),
                              ),
                              child: Text(
                                'Decline',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: screenWidth < 600 ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _hasScrolledToBottom && !_isLoading ? _acceptTerms : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF22c55e),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.015,
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Accept & Continue',
                                      style: TextStyle(
                                        fontSize: screenWidth < 600 ? 14 : 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
        ),
      ),
    );
  }
}