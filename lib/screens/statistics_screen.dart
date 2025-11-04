import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/statistics_service.dart';
import '../models/food_category.dart';
import '../models/beneficiary_type.dart';
import '../utils/responsive_layout.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with TickerProviderStateMixin {
  final StatisticsService _statsService = StatisticsService();
  late TabController _tabController;
  
  String _selectedPeriod = 'week';
  String? _selectedFoodCategory;
  String? _selectedBeneficiaryType;
  
  Map<String, dynamic> _overallStats = {};
  Map<String, dynamic> _foodStats = {};
  Map<String, dynamic> _beneficiaryStats = {};
  Map<String, dynamic> _trends = {};
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    
    try {
      final overallStats = await _statsService.getOverallStats();
      final foodStats = await _statsService.getFoodCategoryStats(
        beneficiaryType: _selectedBeneficiaryType,
        startDate: _getStartDate(),
        endDate: DateTime.now(),
      );
      final beneficiaryStats = await _statsService.getBeneficiaryTypeStats(
        startDate: _getStartDate(),
        endDate: DateTime.now(),
      );
      final trends = await _statsService.getDonationTrends(
        period: _selectedPeriod,
        foodCategory: _selectedFoodCategory,
        beneficiaryType: _selectedBeneficiaryType,
      );

      setState(() {
        _overallStats = overallStats;
        _foodStats = foodStats;
        _beneficiaryStats = beneficiaryStats;
        _trends = trends;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading statistics: $e');
      setState(() => _isLoading = false);
    }
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'day':
        return DateTime(now.year, now.month, now.day);
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'year':
        return DateTime(now.year, 1, 1);
      default:
        return now.subtract(const Duration(days: 7));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Statistics Dashboard',
          style: TextStyle(
            fontSize: ResponsiveLayout.getTitleFontSize(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
        bottom: ResponsiveLayout.isMobile(context) ? TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(
            fontSize: ResponsiveLayout.getBodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Food Trends', icon: Icon(Icons.restaurant)),
            Tab(text: 'Beneficiaries', icon: Icon(Icons.people)),
          ],
        ) : null,
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              size: ResponsiveLayout.getIconSize(context),
            ),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: ResponsiveLayout.getIconSize(context),
            ),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF22c55e),
                strokeWidth: ResponsiveLayout.isMobile(context) ? 2 : 3,
              ),
            )
          : ResponsiveWidget(
              mobile: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildFoodTrendsTab(),
                  _buildBeneficiariesTab(),
                ],
              ),
              tablet: Row(
                children: [
                  // Sidebar for tablet
                  Container(
                    width: 200,
                    color: Colors.grey[100],
                    child: Column(
                      children: [
                        Padding(
                          padding: ResponsiveLayout.getPadding(context),
                          child: Text(
                            'Statistics',
                            style: TextStyle(
                              fontSize: ResponsiveLayout.getSubtitleFontSize(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            children: [
                              _buildSidebarItem('Overview', 0),
                              _buildSidebarItem('Food Trends', 1),
                              _buildSidebarItem('Beneficiaries', 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content area
                  Expanded(
                    child: IndexedStack(
                      index: _tabController.index,
                      children: [
                        _buildOverviewTab(),
                        _buildFoodTrendsTab(),
                        _buildBeneficiariesTab(),
                      ],
                    ),
                  ),
                ],
              ),
              desktop: Row(
                children: [
                  // Sidebar for desktop
                  Container(
                    width: 250,
                    color: Colors.grey[100],
                    child: Column(
                      children: [
                        Padding(
                          padding: ResponsiveLayout.getPadding(context),
                          child: Text(
                            'Statistics Dashboard',
                            style: TextStyle(
                              fontSize: ResponsiveLayout.getSubtitleFontSize(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            children: [
                              _buildSidebarItem('Overview', 0),
                              _buildSidebarItem('Food Trends', 1),
                              _buildSidebarItem('Beneficiaries', 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content area
                  Expanded(
                    child: IndexedStack(
                      index: _tabController.index,
                      children: [
                        _buildOverviewTab(),
                        _buildFoodTrendsTab(),
                        _buildBeneficiariesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSidebarItem(String title, int index) {
    return Obx(() => Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _tabController.index == index ? const Color(0xFF22c55e) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            color: _tabController.index == index ? Colors.white : Colors.black87,
            fontWeight: _tabController.index == index ? FontWeight.bold : FontWeight.normal,
            fontSize: ResponsiveLayout.getBodyFontSize(context),
          ),
        ),
        onTap: () {
          _tabController.animateTo(index);
        },
      ),
    ));
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildTrendsChart(),
          const SizedBox(height: 24),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          title: 'Total Donations',
          value: '${_overallStats['totalDonations'] ?? 0}',
          icon: Icons.restaurant,
          color: Colors.blue,
        ),
        _buildStatCard(
          title: 'Active Receivers',
          value: '${_overallStats['totalReceivers'] ?? 0}',
          icon: Icons.people,
          color: Colors.green,
        ),
        _buildStatCard(
          title: 'Active Donors',
          value: '${_overallStats['totalDonors'] ?? 0}',
          icon: Icons.store,
          color: Colors.orange,
        ),
        _buildStatCard(
          title: 'Average Rating',
          value: '${(_overallStats['averageRating'] ?? 0.0).toStringAsFixed(1)} ⭐',
          icon: Icons.star,
          color: Colors.amber,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Donation Trends',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_trends['trends'] != null && _trends['trends'].isNotEmpty)
            SizedBox(
              height: 200,
              child: _buildTrendsBarChart(),
            )
          else
            const Center(
              child: Text(
                'No trend data available',
                style: TextStyle(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendsBarChart() {
    final trends = _trends['trends'] as Map<String, int>;
    final maxValue = trends.values.isNotEmpty ? trends.values.reduce((a, b) => a > b ? a : b) : 1;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: trends.entries.map((entry) {
        final height = (entry.value / maxValue) * 150;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 30,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF22c55e),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.key,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              '${entry.value}',
              style: const TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('donations')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No recent activity',
                    style: TextStyle(color: Colors.black54),
                  ),
                );
              }
              
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF22c55e).withOpacity(0.1),
                      child: const Icon(Icons.restaurant, color: Color(0xFF22c55e)),
                    ),
                    title: Text(data['title'] ?? 'Donation'),
                    subtitle: Text('${data['donorEmail']?.split('@')[0] ?? 'Donor'} • ${_formatDate((data['createdAt'] as Timestamp).toDate())}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(data['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        data['status'] ?? 'unknown',
                        style: TextStyle(
                          color: _getStatusColor(data['status']),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFoodTrendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFoodCategoryChart(),
          const SizedBox(height: 24),
          _buildFoodCategoryList(),
        ],
      ),
    );
  }

  Widget _buildFoodCategoryChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Food Category Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_foodStats['categoryStats'] != null && _foodStats['categoryStats'].isNotEmpty)
            SizedBox(
              height: 200,
              child: _buildFoodCategoryPieChart(),
            )
          else
            const Center(
              child: Text(
                'No food category data available',
                style: TextStyle(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFoodCategoryPieChart() {
    final categories = (_foodStats['categoryStats'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final categoryData = category['category'] as FoodCategory?;
        final count = category['count'] as int? ?? 0;
        final percentage = category['percentage'] as int? ?? 0;
        
        if (categoryData == null) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Text(categoryData.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryData.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '$count donations ($percentage%)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(int.parse(categoryData.color.replaceAll('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFoodCategoryList() {
    final categories = (_foodStats['categoryStats'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Food Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...categories.map((category) {
            final categoryData = category['category'] as FoodCategory;
            final count = category['count'] as int;
            final percentage = category['percentage'] as int;
            
            return ListTile(
              leading: Text(categoryData.icon, style: const TextStyle(fontSize: 24)),
              title: Text(categoryData.name),
              subtitle: Text(categoryData.description),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBeneficiariesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBeneficiaryTypeChart(),
          const SizedBox(height: 24),
          _buildBeneficiaryTypeList(),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryTypeChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Beneficiary Type Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_beneficiaryStats['typeStats'] != null && _beneficiaryStats['typeStats'].isNotEmpty)
            SizedBox(
              height: 200,
              child: _buildBeneficiaryTypeBarChart(),
            )
          else
            const Center(
              child: Text(
                'No beneficiary data available',
                style: TextStyle(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryTypeBarChart() {
    final types = (_beneficiaryStats['typeStats'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
    final maxValue = types.isNotEmpty ? types.map((t) => (t['count'] as int?) ?? 0).reduce((a, b) => a > b ? a : b) : 1;
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = types[index];
        final typeData = type['type'] as BeneficiaryType?;
        final count = (type['count'] as int?) ?? 0;
        final height = (count / maxValue) * 150;
        
        if (typeData == null) return const SizedBox.shrink();
        
        return Container(
          width: 80,
          margin: const EdgeInsets.only(right: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 60,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFF22c55e),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                typeData.name,
                style: const TextStyle(fontSize: 10, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              Text(
                '$count',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBeneficiaryTypeList() {
    final types = (_beneficiaryStats['typeStats'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Beneficiary Types',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...types.map((type) {
            final typeData = type['type'] as BeneficiaryType;
            final count = type['count'] as int;
            final percentage = type['percentage'] as int;
            
            return ListTile(
              leading: Text(typeData.icon, style: const TextStyle(fontSize: 24)),
              title: Text(typeData.name),
              subtitle: Text(typeData.description),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedPeriod,
              decoration: const InputDecoration(labelText: 'Time Period'),
              items: const [
                DropdownMenuItem(value: 'day', child: Text('Today')),
                DropdownMenuItem(value: 'week', child: Text('This Week')),
                DropdownMenuItem(value: 'month', child: Text('This Month')),
                DropdownMenuItem(value: 'year', child: Text('This Year')),
              ],
              onChanged: (value) => setState(() => _selectedPeriod = value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedFoodCategory,
              decoration: const InputDecoration(labelText: 'Food Category'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Categories')),
                ...FoodCategory.categories.map((category) => DropdownMenuItem(
                  value: category.id,
                  child: Text('${category.icon} ${category.name}'),
                )),
              ],
              onChanged: (value) => setState(() => _selectedFoodCategory = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedBeneficiaryType,
              decoration: const InputDecoration(labelText: 'Beneficiary Type'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Types')),
                ...BeneficiaryType.types.map((type) => DropdownMenuItem(
                  value: type.id,
                  child: Text('${type.icon} ${type.name}'),
                )),
              ],
              onChanged: (value) => setState(() => _selectedBeneficiaryType = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadStatistics();
            },
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'claimed':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.purple;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
