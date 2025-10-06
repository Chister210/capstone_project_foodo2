import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../models/donation_model.dart';
import '../services/donation_service.dart';

class DonorMapScreen extends StatefulWidget {
  const DonorMapScreen({super.key});

  @override
  State<DonorMapScreen> createState() => _DonorMapScreenState();
}

class _DonorMapScreenState extends State<DonorMapScreen> {
  late GoogleMapController mapController;
  final DonationService _donationService = DonationService();
  
  Set<Marker> markers = {};
  List<DonationModel> availableDonations = [];
  List<UserModel> donors = [];
  
  LatLng? currentLocation;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDonorsAndDonations();
  }

  Future<void> _loadDonorsAndDonations() async {
    try {
      // Get all donors with market locations
      final donorsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'donor')
          .where('marketLocation', isNull: false)
          .get();

      final donorsList = donorsQuery.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Get available donations
      final donationsStream = _donationService.getAvailableDonations();
      donationsStream.listen((donations) {
        setState(() {
          availableDonations = donations;
          donors = donorsList;
          _updateMarkers();
          isLoading = false;
        });
      });
    } catch (e) {
      print('Error loading donors and donations: $e');
      setState(() => isLoading = false);
    }
  }

  void _updateMarkers() {
    markers.clear();
    
    // Add markers for each donor with available donations
    for (final donor in donors) {
      if (donor.marketLocation != null) {
        final donorDonations = availableDonations
            .where((donation) => donation.donorId == donor.id)
            .toList();
        
        if (donorDonations.isNotEmpty) {
          markers.add(
            Marker(
              markerId: MarkerId('donor_${donor.id}'),
              position: LatLng(
                donor.marketLocation!.latitude,
                donor.marketLocation!.longitude,
              ),
              infoWindow: InfoWindow(
                title: donor.marketName ?? 'Market',
                snippet: '${donorDonations.length} donation(s) available',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              onTap: () => _showDonorDetails(donor, donorDonations),
            ),
          );
        }
      }
    }
  }

  void _showDonorDetails(UserModel donor, List<DonationModel> donations) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.storefront, color: Color(0xFF22c55e)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          donor.marketName ?? 'Market',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          donor.marketAddress ?? 'Address not available',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Donations list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: donations.length,
                itemBuilder: (context, index) {
                  final donation = donations[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: donation.hasImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Builder(
                                builder: (context) {
                                  final uriData = Uri.dataFromString(donation.imageUrl).data;
                                  if (uriData != null) {
                                    return Image.memory(
                                      uriData.contentAsBytes(),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    );
                                  } else {
                                    // Fallback: show a placeholder icon or empty container
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.broken_image, color: Colors.grey),
                                    );
                                  }
                                },
                              ),
                            )
                          : const Icon(Icons.fastfood, color: Color(0xFF22c55e)),
                      title: Text(
                        donation.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(donation.description),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Pickup: ${donation.pickupTime.day}/${donation.pickupTime.month} ${donation.pickupTime.hour}:${donation.pickupTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _claimDonation(donation),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22c55e),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Claim'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _claimDonation(DonationModel donation) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update donation status
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(donation.id)
          .update({
        'status': 'claimed',
        'claimedBy': user.uid,
        'claimedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create chat for communication
      final chatId = '${donation.donorId}_${user.uid}_${donation.id}';
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .set({
        'donationId': donation.id,
        'donorId': donation.donorId,
        'receiverId': user.uid,
        'donorName': donors.firstWhere((d) => d.id == donation.donorId).displayName,
        'receiverName': user.displayName ?? 'Receiver',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': 'Donation claimed!',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'donorActive': false,
        'receiverActive': true,
      });

      // Update donation with chat ID
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(donation.id)
          .update({
        'chatId': chatId,
        'status': 'in_progress',
      });

      // Show success message
      Get.snackbar(
        'Success!',
        'Donation claimed! You can now communicate with the donor.',
        backgroundColor: const Color(0xFF22c55e),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );

      Navigator.pop(context);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to claim donation. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Donors'),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDonorsAndDonations,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(37.7749, -122.4194), // Default to San Francisco
                zoom: 12,
              ),
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
              markers: markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (markers.isNotEmpty) {
            // Fit all markers in view
            final bounds = _calculateBounds();
            mapController.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 100),
            );
          }
        },
        backgroundColor: const Color(0xFF22c55e),
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  LatLngBounds _calculateBounds() {
    if (markers.isEmpty) {
      return LatLngBounds(
        southwest: LatLng(37.7749, -122.4194),
        northeast: LatLng(37.7749, -122.4194),
      );
    }

    double minLat = markers.first.position.latitude;
    double maxLat = markers.first.position.latitude;
    double minLng = markers.first.position.longitude;
    double maxLng = markers.first.position.longitude;

    for (final marker in markers) {
      minLat = minLat < marker.position.latitude ? minLat : marker.position.latitude;
      maxLat = maxLat > marker.position.latitude ? maxLat : marker.position.latitude;
      minLng = minLng < marker.position.longitude ? minLng : marker.position.longitude;
      maxLng = maxLng > marker.position.longitude ? maxLng : marker.position.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
