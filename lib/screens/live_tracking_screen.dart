import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_tracking_service.dart';
import '../services/donation_service.dart';
import '../models/donation_model.dart';
import 'dart:async';

class LiveTrackingScreen extends StatefulWidget {
  final String donationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserType;

  const LiveTrackingScreen({
    super.key,
    required this.donationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserType,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final LocationTrackingService _locationService = LocationTrackingService();
  final DonationService _donationService = DonationService();
  
  GoogleMapController? _mapController;
  Position? _currentPosition;
  GeoPoint? _otherUserLocation;
  DonationModel? _donation;
  bool _isTracking = false;
  String? _currentUserId;
  
  // Map variables
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<DocumentSnapshot>? _donationSubscription;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _startTracking();
    _loadDonation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _donationSubscription?.cancel();
    _locationService.stopLocationTracking();
    super.dispose();
  }

  Future<void> _loadDonation() async {
    try {
      final donation = await _donationService.getDonationById(widget.donationId);
      if (donation != null) {
        setState(() {
          _donation = donation;
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load donation: $e');
    }
  }

  Future<void> _startTracking() async {
    try {
      setState(() => _isTracking = true);
      
      // Start location tracking
      await _locationService.startLocationTracking();
      
      // Get current position
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });
        
        // Update receiver location for this donation
        await _donationService.updateReceiverLocation(
          widget.donationId,
          GeoPoint(position.latitude, position.longitude),
        );
        
        // Center map on current position
        _centerMapOnPosition(position);
      }
      
      // Listen to location updates
      _listenToLocationUpdates();
      
      // Listen to other user's location updates
      _listenToOtherUserLocation();
      
    } catch (e) {
      Get.snackbar('Error', 'Failed to start tracking: $e');
      setState(() => _isTracking = false);
    }
  }

  void _listenToLocationUpdates() {
    // Use Geolocator directly for location updates
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      
      // Update receiver location for this donation
      _donationService.updateReceiverLocation(
        widget.donationId,
        GeoPoint(position.latitude, position.longitude),
      );
      
      _updateMapMarkers();
      _updatePolyline();
    });
  }

  void _listenToOtherUserLocation() {
    _donationSubscription = FirebaseFirestore.instance
        .collection('donations')
        .doc(widget.donationId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final receiverLocation = data['receiverLocation'] as GeoPoint?;
        
        if (receiverLocation != null) {
          setState(() {
            _otherUserLocation = receiverLocation;
          });
          
          _updateMapMarkers();
          _updatePolyline();
        }
      }
    });
  }

  void _updateMapMarkers() {
    _markers.clear();

    // Add current user marker
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_user'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Add other user marker
    if (_otherUserLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('other_user'),
          position: LatLng(_otherUserLocation!.latitude, _otherUserLocation!.longitude),
          infoWindow: InfoWindow(title: widget.otherUserName),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    setState(() {});
  }

  void _updatePolyline() {
    _polylines.clear();

    if (_currentPosition != null && _otherUserLocation != null) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: const Color(0xFF22c55e),
          width: 4,
          points: [
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            LatLng(_otherUserLocation!.latitude, _otherUserLocation!.longitude),
          ],
        ),
      );
    }

    setState(() {});
  }

  void _centerMapOnPosition(Position position) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        15,
      ),
    );
  }

  void _centerMapOnBothUsers() {
    if (_currentPosition != null && _otherUserLocation != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _currentPosition!.latitude < _otherUserLocation!.latitude 
              ? _currentPosition!.latitude 
              : _otherUserLocation!.latitude,
          _currentPosition!.longitude < _otherUserLocation!.longitude 
              ? _currentPosition!.longitude 
              : _otherUserLocation!.longitude,
        ),
        northeast: LatLng(
          _currentPosition!.latitude > _otherUserLocation!.latitude 
              ? _currentPosition!.latitude 
              : _otherUserLocation!.latitude,
          _currentPosition!.longitude > _otherUserLocation!.longitude 
              ? _currentPosition!.longitude 
              : _otherUserLocation!.longitude,
        ),
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } else if (_currentPosition != null) {
      _centerMapOnPosition(_currentPosition!);
    }
  }

  double _calculateDistance() {
    if (_currentPosition == null || _otherUserLocation == null) return 0.0;
    
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _otherUserLocation!.latitude,
      _otherUserLocation!.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Tracking',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _centerMapOnBothUsers,
            tooltip: 'Center Map',
          ),
        ],
      ),
      body: Column(
        children: [
          // Map Section
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    if (_currentPosition != null) {
                      _centerMapOnPosition(_currentPosition!);
                    }
                  },
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(0, 0),
                    zoom: 15,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: true,
                ),
                
                // Distance overlay
                if (_currentPosition != null && _otherUserLocation != null)
                  Positioned(
                    top: 16,
                    left: 16,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Distance to ${widget.otherUserName}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_calculateDistance().toStringAsFixed(1)} meters',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF22c55e),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Tracking status overlay
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isTracking ? const Color(0xFF22c55e) : Colors.grey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isTracking ? Icons.location_searching : Icons.location_off,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isTracking ? 'LIVE' : 'OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Info Section
          Expanded(
            flex: 1,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (_donation != null)
                      Text(
                        _donation!.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Current User Location
                        _buildLocationInfo(
                          'Your Location',
                          _currentPosition != null 
                              ? '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                              : 'Not available',
                          Icons.person_pin_circle,
                          Colors.blue,
                        ),
                        
                        // Other User Location
                        _buildLocationInfo(
                          widget.otherUserName,
                          _otherUserLocation != null 
                              ? '${_otherUserLocation!.latitude.toStringAsFixed(4)}, ${_otherUserLocation!.longitude.toStringAsFixed(4)}'
                              : 'Not available',
                          Icons.location_on,
                          Colors.green,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _centerMapOnBothUsers,
                            icon: const Icon(Icons.center_focus_strong),
                            label: const Text('Center Map'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22c55e),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Close'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo(String title, String location, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            location,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}