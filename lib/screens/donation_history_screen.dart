import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../models/donation_model.dart';
import '../services/donation_service.dart';
import '../widgets/enhanced_donation_card.dart';

class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen>
    with SingleTickerProviderStateMixin {
  final DonationService _donationService = DonationService();
  late TabController _tabController;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Donations'),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Available'),
            Tab(text: 'Claimed'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDonationsList(_getAllDonations()),
          _buildDonationsList(_getDonationsByStatus('available')),
          _buildDonationsList(_getDonationsByStatus('claimed')),
          _buildDonationsList(_getDonationsByStatus('completed')),
        ],
      ),
    );
  }

  Stream<List<DonationModel>> _getAllDonations() {
    return _donationService.getDonationsByDonor(_currentUserId!);
  }

  Stream<List<DonationModel>> _getDonationsByStatus(String status) {
    return _donationService.getDonationsByDonor(_currentUserId!)
        .map((donations) => donations.where((d) => d.status == status).toList());
  }

  Widget _buildDonationsList(Stream<List<DonationModel>> donationsStream) {
    return StreamBuilder<List<DonationModel>>(
      stream: donationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final donations = snapshot.data ?? [];

        if (donations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fastfood, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No donations found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start by creating your first donation!',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Donation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22c55e),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: donations.length,
            itemBuilder: (context, index) {
              final donation = donations[index];
              return EnhancedDonationCard(
                donation: donation,
                onUpdated: () {
                  setState(() {});
                },
              );
            },
          ),
        );
      },
    );
  }
}
