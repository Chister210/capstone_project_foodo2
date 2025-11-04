import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/donation_model.dart';
import '../models/user_model.dart';
import '../services/location_tracking_service.dart';
// Removed old notification service import
import '../services/donation_service.dart';
import 'dart:async';

class TrackingScreen extends StatefulWidget {
  final String donationId;

  const TrackingScreen({
    super.key,
    required this.donationId,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late GoogleMapController mapController;
  final LocationTrackingService _locationService = LocationTrackingService();
  // Removed legacy notification service field
  final DonationService _donationService = DonationService();
  
  DonationModel? _donation;
  UserModel? _donor;
  UserModel? _receiver;
  bool _isLoading = true;
  bool _isTracking = false;
  bool _hasArrived = false;
  
  Set<Marker> markers = {};
  Polyline? routePolyline;
  StreamSubscription? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _loadDonationData();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDonationData() async {
    try {
      // Get donation data
      final donationDoc = await FirebaseFirestore.instance
          .collection('donations')
          .doc(widget.donationId)
          .get();

      if (!donationDoc.exists) {
        Get.snackbar('Error', 'Donation not found');
        return;
      }

      _donation = DonationModel.fromFirestore(donationDoc);

      // Get donor data
      final donorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_donation!.donorId)
          .get();

      if (donorDoc.exists) {
        _donor = UserModel.fromFirestore(donorDoc);
      }

      // Get receiver data
      if (_donation!.claimedBy != null) {
        final receiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_donation!.claimedBy!)
            .get();

        if (receiverDoc.exists) {
          _receiver = UserModel.fromFirestore(receiverDoc);
        }
      }

      setState(() => _isLoading = false);
      _updateMapMarkers();
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'Failed to load donation data: $e');
    }
  }

  void _updateMapMarkers() {
    markers.clear();

    // Add donor market marker
    if (_donor?.marketLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('donor_market'),
          position: LatLng(
            _donor!.marketLocation!.latitude,
            _donor!.marketLocation!.longitude,
          ),
          infoWindow: InfoWindow(
            title: _donor!.marketName ?? 'Market',
            snippet: 'Donor Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    // Add receiver location marker if available
    if (_donation?.receiverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('receiver_location'),
          position: LatLng(
            _donation!.receiverLocation!.latitude,
            _donation!.receiverLocation!.longitude,
          ),
          infoWindow: InfoWindow(
            title: 'Receiver',
            snippet: 'Current Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Add current user location marker
    markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: _donor?.marketLocation != null
            ? LatLng(
                _donor!.marketLocation!.latitude,
                _donor!.marketLocation!.longitude,
              )
            : const LatLng(37.7749, -122.4194),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Current position',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    setState(() {});
  }

  Future<void> _startTracking() async {
    try {
      await _locationService.startDonationTracking(widget.donationId);
      setState(() => _isTracking = true);

      // Listen for location updates
      _locationSubscription = _locationService.getDonationLocationUpdates(widget.donationId).listen((location) {
        if (location != null) {
          setState(() {
            _donation = _donation?.copyWith(receiverLocation: location);
          });
          _updateMapMarkers();
          _checkArrival();
        }
      });

      Get.snackbar(
        'Tracking Started',
        'Location tracking has been enabled',
        backgroundColor: const Color(0xFF22c55e),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to start tracking: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _checkArrival() async {
    if (_donation?.receiverLocation == null || _donor?.marketLocation == null) return;

    final distance = _locationService.calculateDistance(
      _donation!.receiverLocation!.latitude,
      _donation!.receiverLocation!.longitude,
      _donor!.marketLocation!.latitude,
      _donor!.marketLocation!.longitude,
    );

    // If within 50 meters, show arrival dialog
    if (distance <= 50 && !_hasArrived) {
      _hasArrived = true;
      _showArrivalDialog();
    }
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Arrived at Location'),
        content: const Text('Have you arrived at the donor\'s location?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _hasArrived = false;
            },
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmArrival();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22c55e),
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, I\'m Here'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmArrival() async {
    try {
      // Update donation status to completed
      await _donationService.completeDonation(widget.donationId);

      Get.snackbar(
        'Success!',
        'Donation completed! You earned 10 points.',
        backgroundColor: const Color(0xFF22c55e),
        colorText: Colors.white,
      );

      // Navigate back
      Get.back();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to complete donation: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _stopTracking() async {
    try {
      _locationSubscription?.cancel();
      setState(() {
        _isTracking = false;
        _hasArrived = false;
      });

      Get.snackbar(
        'Tracking Stopped',
        'Location tracking has been disabled',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to stop tracking: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_donation == null || _donor == null) {
      return const Scaffold(
        body: Center(child: Text('Donation data not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Donation'),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
        actions: [
          if (_isTracking)
            IconButton(
              onPressed: _stopTracking,
              icon: const Icon(Icons.location_off),
              tooltip: 'Stop Tracking',
            ),
        ],
      ),
      body: Column(
        children: [
          // Donation info card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _donation!.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _donation!.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.storefront, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _donor!.marketName ?? 'Market',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _donor!.marketAddress ?? 'Address not available',
                        style: const TextStyle(color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_donation!.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(_donation!.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_donation!.claimedBy != null)
                      Text(
                        'Claimed by: ${_receiver?.displayName ?? 'Receiver'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _donor!.marketLocation != null
                        ? LatLng(
                            _donor!.marketLocation!.latitude,
                            _donor!.marketLocation!.longitude,
                          )
                        : const LatLng(37.7749, -122.4194),
                    zoom: 15,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                  },
                  markers: markers,
                  polylines: routePolyline != null ? {routePolyline!} : {},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),
                if (_isTracking)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_searching,
                            color: const Color(0xFF22c55e),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tracking Active',
                            style: TextStyle(
                              color: const Color(0xFF22c55e),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (!_isTracking && _donation!.status == 'claimed')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22c55e),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_searching),
                          SizedBox(width: 8),
                          Text('Start Tracking'),
                        ],
                      ),
                    ),
                  ),
                if (_isTracking)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _stopTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off),
                          SizedBox(width: 8),
                          Text('Stop Tracking'),
                        ],
                      ),
                    ),
                  ),
                if (_donation!.status == 'completed')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22c55e).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF22c55e)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF22c55e)),
                        SizedBox(width: 8),
                        Text(
                          'Donation Completed',
                          style: TextStyle(
                            color: Color(0xFF22c55e),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.blue;
      case 'claimed':
        return Colors.orange;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return const Color(0xFF22c55e);
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'available':
        return 'Available';
      case 'claimed':
        return 'Claimed';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }
}