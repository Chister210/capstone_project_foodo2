import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_tracking_service.dart';
import '../services/donation_service.dart';
import '../models/donation_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LocationData? _currentLocation;
  Location _location = Location();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  final LocationTrackingService _locationService = LocationTrackingService();
  final DonationService _donationService = DonationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isTracking = false;
  bool _isMapCreated = false;
  bool _isLoading = true;
  bool _hasLocationError = false;
  bool _hasMapError = false;
  String? _trackingDonationId;
  LatLng? _selectedMarketLocation;

  // Default Davao City coordinates
  static const LatLng _davaoCityCenter = LatLng(7.1907, 125.4553);
  static const double _defaultZoom = 12.0;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      print('Initializing map...');
      setState(() {
        _isLoading = true;
        _hasLocationError = false;
        _hasMapError = false;
      });

      // Request location permission first
      await _requestLocationPermission();
      
      // Get current location
      await _getCurrentLocation();

      // Load markers after location is obtained
      _loadDonationMarkers();
      await _loadMarketDonorMarkers();

      setState(() {
        _isLoading = false;
      });
      print('Map initialized successfully');
      
    } catch (e) {
      print('Error initializing map: $e');
      setState(() {
        _isLoading = false;
        _hasLocationError = true;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      print('Requesting location permission...');
      
      // Check if location service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      print('Location service enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled');
        }
      }

      // Check location permission
      PermissionStatus permissionGranted = await _location.hasPermission();
      print('Location permission status: $permissionGranted');
      
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Location permission denied');
        }
      }
      
      if (permissionGranted == PermissionStatus.deniedForever) {
        throw Exception('Location permission permanently denied');
      }
      
      print('Location permission granted');
      
    } catch (e) {
      print('Location permission error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _locationService.stopLocationTracking();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      print('Getting current location...');
      final locationData = await _location.getLocation();
      print('Location data: $locationData');
      
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentLocation = locationData;
        });
        
        // Move camera to current location
        _moveToLocation(
          LatLng(locationData.latitude!, locationData.longitude!),
          14.0,
        );
        
      } else {
        // If no current location, use Davao City center
        _moveToLocation(_davaoCityCenter, _defaultZoom);
      }
      
    } catch (e) {
      print('Error getting current location: $e');
      // Use default location if current location fails
      _moveToLocation(_davaoCityCenter, _defaultZoom);
      setState(() {
        _hasLocationError = true;
      });
    }
  }

  void _moveToLocation(LatLng location, double zoom) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(location, zoom),
      );
    }
  }

  // Add market donor pins for receivers
  Future<void> _loadMarketDonorMarkers() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'donor')
          .where('isActive', isEqualTo: true)
          .get();
      
      final newMarkers = <Marker>{};
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final marketLocation = data['marketLocation'];
        final marketName = data['marketName'] ?? 'Market';
        final marketAddress = data['marketAddress'] ?? '';
        final donorEmail = data['email'] ?? '';
        final donorName = data['displayName'] ?? donorEmail.split('@')[0];
        final phoneNumber = data['phoneNumber'] ?? 'Not provided';
        final marketHours = data['marketHours'] ?? 'Not specified';
        
        if (marketLocation != null && marketLocation['latitude'] != null && marketLocation['longitude'] != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId('market_${doc.id}'),
              position: LatLng(marketLocation['latitude'], marketLocation['longitude']),
              infoWindow: InfoWindow(
                title: marketName,
                snippet: 'Tap for market details',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              onTap: () => _showMarketDetails(
                marketName: marketName,
                marketAddress: marketAddress,
                donorName: donorName,
                donorEmail: donorEmail,
                phoneNumber: phoneNumber,
                marketHours: marketHours,
                marketLocation: LatLng(marketLocation['latitude'], marketLocation['longitude']),
              ),
            ),
          );
        }
      }
      
      if (mounted) {
        setState(() {
          _markers.addAll(newMarkers);
        });
      }
    } catch (e) {
      print('Error loading market donor markers: $e');
    }
  }

  void _showMarketDetails({
    required String marketName,
    required String marketAddress,
    required String donorName,
    required String donorEmail,
    required String phoneNumber,
    required String marketHours,
    required LatLng marketLocation,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          marketName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF22c55e),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Market Information Section
              _buildInfoSection(
                icon: Icons.storefront_rounded,
                title: 'Market Information',
                children: [
                  _buildInfoRow('Address', marketAddress.isNotEmpty ? marketAddress : 'Not specified'),
                  _buildInfoRow('Operating Hours', marketHours.isNotEmpty ? marketHours : 'Not specified'),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Donor Information Section
              _buildInfoSection(
                icon: Icons.person_rounded,
                title: 'Donor Information',
                children: [
                  _buildInfoRow('Name', donorName),
                  _buildInfoRow('Email', donorEmail),
                  _buildInfoRow('Phone', phoneNumber.isNotEmpty ? phoneNumber : 'Not provided'),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Location Coordinates
              _buildInfoSection(
                icon: Icons.location_on_rounded,
                title: 'Location Coordinates',
                children: [
                  _buildInfoRow('Latitude', marketLocation.latitude.toStringAsFixed(6)),
                  _buildInfoRow('Longitude', marketLocation.longitude.toStringAsFixed(6)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _moveToLocation(marketLocation, 16.0); // Zoom in closer to the market
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22c55e),
              foregroundColor: Colors.white,
            ),
            child: const Text('View Location'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF22c55e),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _loadDonationMarkers() {
    print('Loading donation markers...');
    _donationService.getAvailableDonations().listen((donations) {
      if (!mounted) return;
      
      print('Loaded ${donations.length} donations');
      
      setState(() {
        // Clear only donation markers, keep market markers
        _markers.removeWhere((marker) => marker.markerId.value.startsWith('donation_'));
        
        for (final donation in donations) {
          if (donation.marketLocation != null) {
            _markers.add(
              Marker(
                markerId: MarkerId('donation_${donation.id}'),
                position: LatLng(
                  donation.marketLocation!.latitude,
                  donation.marketLocation!.longitude,
                ),
                infoWindow: InfoWindow(
                  title: donation.title,
                  snippet: '${donation.marketAddress ?? 'Market Location'}\nTap to claim',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                onTap: () => _showDonationDetails(donation),
              ),
            );
          }
        }
      });
    }, onError: (error) {
      print('Error loading donation markers: $error');
    });
  }

  void _showDonationDetails(DonationModel donation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(donation.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description: ${donation.description}'),
            const SizedBox(height: 8),
            Text('Donor: ${donation.donorEmail.split('@')[0]}'),
            const SizedBox(height: 8),
            Text('Pickup Time: ${_formatDateTime(donation.pickupTime)}'),
            if (donation.marketAddress != null) ...[
              const SizedBox(height: 8),
              Text('Market: ${donation.marketAddress}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startTrackingToMarket(donation);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22c55e),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Tracking'),
          ),
        ],
      ),
    );
  }

  void _startTrackingToMarket(DonationModel donation) async {
    try {
      await _locationService.startDonationTracking(donation.id);
      setState(() {
        _isTracking = true;
        _trackingDonationId = donation.id;
      });

      // Listen to live location updates
      _locationService.getDonationLocationUpdates(donation.id).listen((geoPoint) {
        if (geoPoint != null && donation.marketLocation != null) {
          _updateTrackingPolyline(
            LatLng(geoPoint.latitude, geoPoint.longitude),
            LatLng(
              donation.marketLocation!.latitude,
              donation.marketLocation!.longitude,
            ),
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live tracking started! Donor can see your location.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting tracking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateTrackingPolyline(LatLng receiverLocation, LatLng marketLocation) {
    if (!mounted) return;
    
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('tracking_route'),
          points: [receiverLocation, marketLocation],
          color: const Color(0xFF22c55e),
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    });
  }

  void _stopTracking() async {
    try {
      await _locationService.stopLocationTracking();
      if (!mounted) return;
      
      setState(() {
        _isTracking = false;
        _trackingDonationId = null;
        _polylines.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tracking stopped.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping tracking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _selectMarketLocation(LatLng location) {
    setState(() {
      _selectedMarketLocation = location;
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Market Location Selected'),
        content: Text(
          'Latitude: ${location.latitude.toStringAsFixed(6)}\n'
          'Longitude: ${location.longitude.toStringAsFixed(6)}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedMarketLocation = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showCreateDonationDialog(location);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22c55e),
              foregroundColor: Colors.white,
            ),
            child: const Text('Create Donation'),
          ),
        ],
      ),
    );
  }

  void _showCreateDonationDialog(LatLng location) {
    Navigator.pushNamed(context, '/donation-form', arguments: {
      'marketLocation': location,
    });
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Davao City Food Map'),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF22c55e)),
            SizedBox(height: 16),
            Text(
              'Loading Map...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Davao City Food Map'),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Map Loading Failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _initializeMap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22c55e),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isDonor = user?.email?.contains('donor') ?? false;
    final isReceiver = user?.email?.contains('receiver') ?? false;
    
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_hasLocationError && _hasMapError) {
      return _buildErrorScreen('Unable to load map. Please check your location permissions and try again.');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Davao City Food Map'),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
        actions: [
          if (_isTracking)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopTracking,
              tooltip: 'Stop Tracking',
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Current Location',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeMap,
            tooltip: 'Refresh Map',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              print('GoogleMap created successfully');
              _mapController = controller;
              setState(() {
                _isMapCreated = true;
                _hasMapError = false;
              });
              
              // Ensure we have a valid camera position
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_currentLocation != null) {
                  _moveToLocation(
                    LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                    14.0,
                  );
                } else {
                  _moveToLocation(_davaoCityCenter, _defaultZoom);
                }
              });
            },
            initialCameraPosition: CameraPosition(
              target: _currentLocation != null 
                  ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
                  : _davaoCityCenter,
              zoom: _currentLocation != null ? 14.0 : _defaultZoom,
            ),
            markers: _markers,
            polylines: _polylines,
            onTap: isDonor ? (LatLng location) {
              // Simple location validation for Davao City
              if (location.latitude >= 6.9 && location.latitude <= 7.3 && 
                  location.longitude >= 125.3 && location.longitude <= 125.7) {
                _selectMarketLocation(location);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a location within Davao City area'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            } : null,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            tiltGesturesEnabled: true,
            onCameraIdle: () => print('Camera idle'),
            onCameraMoveStarted: () => print('Camera move started'),
          ),
          
          // Davao City boundary indicator
          IgnorePointer(
            child: Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_city,
                      color: Colors.green[700],
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Davao City',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Legend for map markers
          IgnorePointer(
            child: Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem('Available Donations', BitmapDescriptor.hueGreen),
                    const SizedBox(height: 8),
                    _buildLegendItem('Donor Markets', BitmapDescriptor.hueOrange),
                    if (isReceiver) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tap on market icons\nto see details',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // Map loading indicator
          if (!_isMapCreated && !_hasMapError)
            const IgnorePointer(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF22c55e)),
              ),
            ),
          
          // Map error overlay
          if (_hasMapError)
            IgnorePointer(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.map_outlined,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Map Failed to Load',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please check your internet connection and try again',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initializeMap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22c55e),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Tracking status indicator
          if (_isTracking)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF22c55e),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Live Tracking Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Donor can see your location',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _stopTracking,
                      icon: const Icon(
                        Icons.stop,
                        color: Colors.white,
                      ),
                      tooltip: 'Stop Tracking',
                    ),
                  ],
                ),
              ),
            ),
          
          // Instructions for donors
          if (isDonor && !_isTracking && _isMapCreated)
            IgnorePointer(
              child: Positioned(
                bottom: _isTracking ? 80 : 16, // Adjust position if tracking is active
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap on the map to select your market location',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildLegendItem(String text, double hue) {
    return Row(
      children: [
        Icon(
          Icons.location_on,
          color: Color.fromRGBO(
            (hue / 360 * 255).round(),
            (hue / 360 * 255).round(),
            (hue / 360 * 255).round(),
            1,
          ),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}