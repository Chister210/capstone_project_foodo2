import 'package:flutter/material.dart';

class FoodSafetyGuideline extends StatefulWidget {
  final VoidCallback onCompleted;

  const FoodSafetyGuideline({
    super.key,
    required this.onCompleted,
  });

  @override
  State<FoodSafetyGuideline> createState() => _FoodSafetyGuidelineState();
}

class _FoodSafetyGuidelineState extends State<FoodSafetyGuideline> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final List<bool> _checklistItems = List.filled(8, false);
  bool _allChecked = false;

  final List<Map<String, dynamic>> _guidelines = [
    {
      'title': 'Food Safety Guidelines',
      'subtitle': 'Ensure safe food handling and distribution',
      'icon': Icons.security_rounded,
      'color': const Color(0xFF22c55e),
    },
    {
      'title': 'Temperature Control',
      'subtitle': 'Keep hot foods hot (above 60°C) and cold foods cold (below 4°C)',
      'icon': Icons.thermostat_rounded,
      'color': const Color(0xFF3b82f6),
    },
    {
      'title': 'Cleanliness',
      'subtitle': 'Wash hands thoroughly and use clean containers',
      'icon': Icons.cleaning_services_rounded,
      'color': const Color(0xFF8b5cf6),
    },
    {
      'title': 'Storage',
      'subtitle': 'Store food in appropriate containers and conditions',
      'icon': Icons.inventory_rounded,
      'color': const Color(0xFFf59e0b),
    },
  ];

  final List<Map<String, dynamic>> _checklist = [
    {
      'title': 'Food is fresh and not expired',
      'description': 'Check expiration dates and food quality',
      'icon': Icons.check_circle_outline_rounded,
    },
    {
      'title': 'Proper temperature maintained',
      'description': 'Hot foods hot, cold foods cold',
      'icon': Icons.thermostat_rounded,
    },
    {
      'title': 'Clean packaging and containers',
      'description': 'Use clean, food-safe containers',
      'icon': Icons.cleaning_services_rounded,
    },
    {
      'title': 'No cross-contamination',
      'description': 'Separate raw and cooked foods',
      'icon': Icons.warning_rounded,
    },
    {
      'title': 'Proper labeling',
      'description': 'Label contents and preparation date',
      'icon': Icons.label_rounded,
    },
    {
      'title': 'Allergen information provided',
      'description': 'List all ingredients and allergens',
      'icon': Icons.info_rounded,
    },
    {
      'title': 'Safe handling practices',
      'description': 'Washed hands and clean preparation area',
      'icon': Icons.handshake_rounded,
    },
    {
      'title': 'Appropriate storage conditions',
      'description': 'Stored in proper temperature and environment',
      'icon': Icons.storage_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _updateAllChecked();
  }

  void _updateAllChecked() {
    setState(() {
      _allChecked = _checklistItems.every((item) => item);
    });
  }

  void _toggleChecklistItem(int index) {
    setState(() {
      _checklistItems[index] = !_checklistItems[index];
      _updateAllChecked();
    });
  }

  void _nextPage() {
    if (_currentPage < _guidelines.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeGuidelines() {
  if (_allChecked) {
    // First call the completion callback to update the parent state
    widget.onCompleted();
    
    // Then close ONLY the guidelines dialog, NOT the donation form
    Navigator.pop(context);
    
    // Show success message - this will be shown in the DonationForm context
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Food safety guidelines completed! You can now create your donation.'),
        backgroundColor: Color(0xFF22c55e),
        duration: Duration(seconds: 3),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please complete all checklist items before proceeding'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [
                Colors.white,
                Color(0xFFF1F5F9),
                Color(0xFFE0F7FA),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF22c55e),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.security_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Food Safety Guidelines',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Page indicator
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_guidelines.length + 1, (index) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index 
                            ? const Color(0xFF22c55e)
                            : Colors.grey.withOpacity(0.3),
                      ),
                    );
                  }),
                ),
              ),
              
              // Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _guidelines.length + 1,
                  itemBuilder: (context, index) {
                    if (index < _guidelines.length) {
                      return _buildGuidelinePage(index);
                    } else {
                      return _buildChecklistPage();
                    }
                  },
                ),
              ),
              
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousPage,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF22c55e),
                            side: const BorderSide(color: Color(0xFF22c55e)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Previous'),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _currentPage < _guidelines.length
                          ? ElevatedButton(
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF22c55e),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Next'),
                            )
                          : ElevatedButton(
                              onPressed: _allChecked ? _completeGuidelines : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _allChecked ? const Color(0xFF22c55e) : Colors.grey,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Complete Guidelines'),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidelinePage(int index) {
    final guideline = _guidelines[index];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: guideline['color'].withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              guideline['icon'],
              color: guideline['color'],
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            guideline['title'],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            guideline['subtitle'],
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildGuidelineDetails(index),
        ],
      ),
    );
  }

  Widget _buildGuidelineDetails(int index) {
    final details = _getGuidelineDetails(index);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details.map((detail) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: const Color(0xFF22c55e),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildChecklistPage() {
    return Column(
      children: [
        // Header section
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Safety Checklist',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please confirm that you have followed all safety guidelines:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF22c55e).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF22c55e).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      color: Color(0xFF22c55e),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Completing this checklist is required before you can create a donation',
                        style: TextStyle(
                          color: Color(0xFF22c55e),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Checklist items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _checklist.length,
            itemBuilder: (context, index) {
              final item = _checklist[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _checklistItems[index] ? const Color(0xFF22c55e).withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _checklistItems[index] ? const Color(0xFF22c55e) : Colors.grey.withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => _toggleChecklistItem(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _checklistItems[index] ? const Color(0xFF22c55e) : Colors.transparent,
                          border: Border.all(
                            color: _checklistItems[index] ? const Color(0xFF22c55e) : Colors.grey,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _checklistItems[index]
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        item['icon'],
                        color: _checklistItems[index] ? const Color(0xFF22c55e) : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _checklistItems[index] ? const Color(0xFF22c55e) : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['description'],
                              style: TextStyle(
                                fontSize: 12,
                                color: _checklistItems[index] ? const Color(0xFF22c55e) : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        // Completion message
        if (_allChecked)
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF22c55e).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF22c55e).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF22c55e),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'All safety guidelines completed! You can now create your donation.',
                    style: TextStyle(
                      color: Color(0xFF22c55e),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<String> _getGuidelineDetails(int index) {
    switch (index) {
      case 0:
        return [
          'Follow proper food handling procedures',
          'Ensure food safety standards are met',
          'Protect recipients from foodborne illnesses',
          'Maintain food quality and freshness',
        ];
      case 1:
        return [
          'Hot foods must be kept above 60°C (140°F)',
          'Cold foods must be kept below 4°C (40°F)',
          'Use insulated containers for transport',
          'Check temperatures with food thermometers',
        ];
      case 2:
        return [
          'Wash hands with soap and water for 20 seconds',
          'Use clean, sanitized containers',
          'Avoid cross-contamination',
          'Clean preparation surfaces thoroughly',
        ];
      case 3:
        return [
          'Use appropriate storage containers',
          'Label containers with contents and date',
          'Store in cool, dry places',
          'Protect from pests and contamination',
        ];
      default:
        return [];
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}