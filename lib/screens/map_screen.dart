import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/location_tracking_service.dart';
import '../services/donation_service.dart';
import '../services/donor_stats_service.dart';
import '../models/donation_model.dart';
import '../widgets/custom_marker_widget.dart';
import '../widgets/donor_info_popup.dart';
import '../screens/chat_screen.dart';
import '../screens/market_details_screen.dart';
import 'dart:async';
import 'package:get/get.dart';
import '../services/messaging_service.dart';

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
  final DonorStatsService _donorStatsService = Get.put(DonorStatsService());
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isTracking = false;
  bool _isMapCreated = false;
  bool _isLoading = true;
  bool _hasLocationError = false;
  bool _hasMapError = false;
  String? _trackingDonationId;
  String? _selectedDonorId;

  // Custom markers
  BitmapDescriptor? _donorMarker;
  BitmapDescriptor? _userLocationMarker;
  BitmapDescriptor? _donationMarker;

  // Default Davao City coordinates
  static const LatLng _davaoCityCenter = LatLng(7.1907, 125.4553);
  static const double _defaultZoom = 12.0;

  @override
  void initState() {
    super.initState();
    // Delay initialization to ensure widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
      _initializeCustomMarkers();
    });
  }

  Future<void> _initializeCustomMarkers() async {
    try {
      _donorMarker = await CustomMarkerWidget.createCustomMarker(
        text: 'D',
        color: const Color(0xFF22c55e),
        isOnline: true,
        rating: 4.5,
      );
      
      _userLocationMarker = await CustomMarkerWidget.createUserLocationMarker();
      
      _donationMarker = await CustomMarkerWidget.createCustomMarker(
        text: 'F',
        color: Colors.orange,
        isOnline: false,
        rating: 0.0,
      );
      
      setState(() {});
    } catch (e) {
      print('Error initializing custom markers: $e');
    }
  }

  Future<void> _initializeMap() async {
    try {
      print('🗺️ Initializing enhanced map...');
      if (!mounted) return;
      
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
      
      // Load donor locations with real-time updates
      _loadDonorLocations();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('✅ Enhanced map initialized successfully');
      
    } catch (e) {
      print('❌ Error initializing map: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLocationError = true;
        });
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      print('📍 Requesting location permission...');
      
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
      
      print('✅ Location permission granted');
      
    } catch (e) {
      print('❌ Location permission error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    // Stop live location tracking
    _locationService.stopLocationTracking();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      print('📍 Getting current location...');
      final locationData = await _location.getLocation();
      print('Location data: $locationData');

      if (locationData.latitude != null && locationData.longitude != null) {
        if (mounted) {
          setState(() {
            _currentLocation = locationData;
          });
          // If map already created, move camera to current location
          if (_isMapCreated && _mapController != null) {
            _moveToLocation(
              LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
              14.0,
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error getting current location: $e');
      if (mounted) {
        setState(() {
          _hasLocationError = true;
        });
      }
    }
  }

  void _moveToLocation(LatLng location, double zoom) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(location, zoom),
      );
    }
  }

  // Zoom helpers
  void _zoomIn() {
    if (_mapController == null) return;
    _mapController!.animateCamera(CameraUpdate.zoomIn());
  }
  
  void _zoomOut() {
    if (_mapController == null) return;
    _mapController!.animateCamera(CameraUpdate.zoomOut());
  }

  // Load donor locations with real-time updates
  void _loadDonorLocations() {
    _donorStatsService.getDonorLocations().listen((donorLocations) {
      if (!mounted) return;
      
      Set<Marker> donorMarkers = {};
      
      for (var donorData in donorLocations) {
        if (donorData['location'] != null) {
          final location = donorData['location'] as GeoPoint;
          final donorId = donorData['donorId'] as String? ?? '';
          final donorName = donorData['donorName'] as String? ?? '';
          final donorEmail = donorData['donorEmail'] as String? ?? '';
          final marketAddress = donorData['marketAddress'] as String? ?? '';
          final isOnline = donorData['isOnline'] as bool? ?? false;
          
          // Create custom marker for this donor
          _createDonorMarker(
            donorId: donorId,
            donorName: donorName,
            donorEmail: donorEmail,
            marketAddress: marketAddress,
            isOnline: isOnline,
            location: LatLng(location.latitude, location.longitude),
          ).then((marker) {
            if (marker != null && mounted) {
              setState(() {
                donorMarkers.add(marker);
              });
            }
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _markers.removeWhere((marker) => marker.markerId.value.startsWith('donor_'));
          _markers.addAll(donorMarkers);
        });
      }
    });
  }

  Future<Marker?> _createDonorMarker({
    required String donorId,
    required String donorName,
    required String donorEmail,
    required String marketAddress,
    required bool isOnline,
    required LatLng location,
  }) async {
    try {
      // Get donor stats for rating
      final stats = await _donorStatsService.getDonorStats(donorId);
      final rating = stats['averageRating'] ?? 0.0;
      
      // Create custom marker
      final customMarker = await CustomMarkerWidget.createCustomMarker(
        text: 'D',
        color: isOnline ? const Color(0xFF22c55e) : Colors.grey,
        isOnline: isOnline,
        rating: rating,
      );
      
      return Marker(
        markerId: MarkerId('donor_$donorId'),
        position: location,
        icon: customMarker,
        infoWindow: InfoWindow(
          title: donorName,
          snippet: marketAddress.isNotEmpty ? marketAddress : 'Location not specified',
        ),
        onTap: () => _showDonorInfoPopup(
          donorId: donorId,
          donorName: donorName,
          donorEmail: donorEmail,
          location: LatLng(location.latitude, location.longitude),
          marketAddress: marketAddress,
          isOnline: isOnline,
        ),
      );
    } catch (e) {
      print('Error creating donor marker: $e');
      return null;
    }
  }

  void _showDonorInfoPopup({
    required String donorId,
    required String donorName,
    required String donorEmail,
    required LatLng location,
    required String marketAddress,
    required bool isOnline,
  }) async {
    try {
      // Fetch donor stats (avg rating, review count) from DonorStatsService
      Map<String, dynamic> stats = {};
      try {
        stats = await _donorStatsService.getDonorStats(donorId);
      } catch (e) {
        print('Error fetching donor stats: $e');
        stats = {};
      }
      final double avgRating = (stats['averageRating'] ?? 0.0) is double
          ? stats['averageRating'] as double
          : (stats['averageRating'] ?? 0.0).toDouble();
      final int reviewCount = (stats['reviewCount'] ?? 0) as int;

      // Fetch latest reviews (try common collection names, fallback)
      QuerySnapshot reviewsSnap;
      try {
        reviewsSnap = await FirebaseFirestore.instance
            .collection('feedbacks')
            .where('donorId', isEqualTo: donorId)
            .where('isVisible', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
      } catch (_) {
        reviewsSnap = await FirebaseFirestore.instance
            .collection('feedback')
            .where('donorId', isEqualTo: donorId)
            .where('isVisible', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
      }

      final reviews = reviewsSnap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>? ?? {};
        final ratingRaw = data['rating'];
        final int rating = ratingRaw is int ? ratingRaw : (ratingRaw is double ? ratingRaw.round() : 0);
        final comment = (data['comment'] ?? '').toString();
        final reviewer = (data['receiverName'] ?? data['receiverDisplayName'] ?? 'Anonymous').toString();
        return {'rating': rating, 'comment': comment, 'reviewer': reviewer};
      }).toList();

      // Show DonorInfoPopup with all details
      showDialog(
        context: context,
        builder: (context) => DonorInfoPopup(
          donorId: donorId,
          donorName: donorName,
          donorEmail: donorEmail,
          location: GeoPoint(location.latitude, location.longitude),
          marketAddress: marketAddress,
          isOnline: isOnline,
          onGetDirections: () {
            Navigator.of(context).pop();
            _showDirectionsToDonor(location, donorName);
          },
          onStartChat: () {
            Navigator.of(context).pop();
            _startChatWithDonor(donorId, donorName);
          },
          onShowMoreDetails: () {
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MarketDetailsScreen(
                  donorId: donorId,
                  donorName: donorName,
                  marketAddress: marketAddress,
                  isOnline: isOnline,
                ),
              ),
            );
          },
        ),
      );
      
      // Old AlertDialog code removed - replaced with DonorInfoPopup
      /*
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF22c55e).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFF22c55e),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  donorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22c55e),
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(
                  icon: Icons.location_on_rounded,
                  title: 'Market',
                  children: [
                    _buildInfoRow('Address', marketAddress.isNotEmpty ? marketAddress : 'Not specified'),
                    _buildInfoRow('Email', donorEmail.isNotEmpty ? donorEmail : 'Not provided'),
                    _buildInfoRow('Status', isOnline ? 'Online' : 'Offline'),
                  ],
                ),
                const SizedBox(height: 12),

                // Statistics (rating + reviews count)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: List.generate(5, (i) {
                              return Icon(
                                i < avgRating.round() ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '$reviewCount review${reviewCount == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showDirectionsToDonor(location, donorName);
                        },
                        icon: const Icon(Icons.directions),
                        label: const Text('Directions'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22c55e)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Recent reviews
                if (reviews.isNotEmpty) ...[
                  const Text('Recent reviews', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Column(
                    children: reviews.map((r) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text((r['reviewer'] ?? 'Anonymous').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Row(
                                  children: List.generate(5, (i) {
                                    return Icon(
                                      i < (r['rating'] as int) ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 14,
                                    );
                                  }),
                                )
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ((r['comment'] ?? '')).toString().isNotEmpty ? (r['comment'] ?? '').toString() : 'No comment',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ] else
                  const Text('No reviews yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          */
    } catch (e) {
      print('Error showing donor popup: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading donor info: $e')));
    }
  }

  void _showDirectionsToDonor(LatLng donorLocation, String donorName) async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get your current location')),
      );
      return;
    }

    try {
      await _drawDirectionLine(
        LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
        donorLocation,
      );

      // Move camera to show both locations
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              _currentLocation!.latitude! < donorLocation.latitude
                  ? _currentLocation!.latitude!
                  : donorLocation.latitude,
              _currentLocation!.longitude! < donorLocation.longitude
                  ? _currentLocation!.longitude!
                  : donorLocation.longitude,
            ),
            northeast: LatLng(
              _currentLocation!.latitude! > donorLocation.latitude
                  ? _currentLocation!.latitude!
                  : donorLocation.latitude,
              _currentLocation!.longitude! > donorLocation.longitude
                  ? _currentLocation!.longitude!
                  : donorLocation.longitude,
            ),
          ),
          100.0,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Directions to $donorName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting directions: $e')),
      );
    }
  }

  void _startChatWithDonor(String donorId, String donorName) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to start a chat')),
      );
      return;
    }

    // Create the chat using MessagingService
    final messagingService = MessagingService();  // Add this import if not already: import '../services/messaging_service.dart';
    final chatId = await messagingService.createChat(
      donationId: '',  // No specific donation, so use empty string or a default
      donorId: donorId,
      receiverId: currentUser.uid,
      donorName: donorName,
      receiverName: currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Receiver',
    );

    // Navigate to ChatScreen with correct parameters
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,              // Now provided
          otherUserName: donorName,    // Matches constructor
          otherUserType: 'donor',      // Since chatting with a donor
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error starting chat: $e')),
    );
  }
}

  // Fixed: moved market donor markers logic into a proper async function
  Future<void> _loadMarketDonorMarkers() async {
    try {
      print('🏪 Loading market donor markers...');
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
        final donorName = data['displayName'] ??
            (donorEmail.isNotEmpty ? donorEmail.split('@')[0] : 'Donor');
        final phoneNumber = data['phoneNumber'] ?? 'Not provided';
        final marketHours = data['marketHours'] ?? 'Not specified';
        final marketDescription = data['marketDescription'] ?? 'Fresh food market';

        // support GeoPoint or map {latitude, longitude}
        double? lat;
        double? lng;
        if (marketLocation is GeoPoint) {
          lat = marketLocation.latitude;
          lng = marketLocation.longitude;
        } else if (marketLocation is Map) {
          lat = (marketLocation['latitude'] as num?)?.toDouble();
          lng = (marketLocation['longitude'] as num?)?.toDouble();
        }

        if (lat != null && lng != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId('market_${doc.id}'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: marketName,
                snippet: 'Tap for market details & directions',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              onTap: () => _showEnhancedMarketDetails(
                marketName: marketName,
                marketAddress: marketAddress,
                donorName: donorName,
                donorEmail: donorEmail,
                phoneNumber: phoneNumber,
                marketHours: marketHours,
                marketDescription: marketDescription,
                marketLocation: LatLng(lat!, lng!),
                donorId: doc.id,
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
      print('✅ Loaded ${newMarkers.length} market markers');
    } catch (e) {
      print('❌ Error loading market donor markers: $e');
    }
  }

  void _showEnhancedMarketDetails({
    required String marketName,
    required String marketAddress,
    required String donorName,
    required String donorEmail,
    required String phoneNumber,
    required String marketHours,
    required String marketDescription,
    required LatLng marketLocation,
    required String donorId,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF22c55e).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFF22c55e),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                marketName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22c55e),
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Market Description
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        marketDescription,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              _buildInfoSection(
                icon: Icons.location_on_rounded,
                title: 'Location Details',
                children: [
                  _buildInfoRow('Address', marketAddress.isNotEmpty ? marketAddress : 'Not specified'),
                  _buildInfoRow('Hours', marketHours.isNotEmpty ? marketHours : 'Not specified'),
                ],
              ),
              
              const SizedBox(height: 16),
              
              _buildInfoSection(
                icon: Icons.person_rounded,
                title: 'Donor Information',
                children: [
                  _buildInfoRow('Name', donorName),
                  _buildInfoRow('Email', donorEmail),
                  _buildInfoRow('Phone', phoneNumber.isNotEmpty ? phoneNumber : 'Not provided'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showDirectionsToMarket(marketLocation, marketName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22c55e),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.directions, size: 18),
            label: const Text('Get Directions'),
          ),
        ],
      ),
    );
  }

  void _showDirectionsToMarket(LatLng marketLocation, String marketName) async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your current location for directions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Draw direction line
      await _drawDirectionLine(
        LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
        marketLocation,
      );

      // Move camera to show both locations
      _moveToLocation(marketLocation, 14.0);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Directions to $marketName shown on map'),
          backgroundColor: const Color(0xFF22c55e),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting directions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _drawDirectionLine(LatLng start, LatLng end) async {
    try {
      // Use Google Directions API to get route
      final directions = await _getDirections(start, end);
      
      if (directions != null && (directions['routes'] as List).isNotEmpty) {
        final route = directions['routes'][0];
        final points = route['overview_polyline']['points'];
        final decodedPoints = _decodePolyline(points);
        
        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('direction_line'),
              points: decodedPoints,
              color: const Color(0xFF22c55e),
              width: 4,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          );
        });
      }
    } catch (e) {
      print('❌ Error drawing direction line: $e');
    }
  }

  Future<Map<String, dynamic>?> _getDirections(LatLng start, LatLng end) async {
    try {
      // Note: You'll need to add your Google Maps API key here
      const apiKey = 'AIzaSyCsTChi88TYeupPvBX5z4BAjDDCPWYxL5s'; // Replace with your actual API key
      final url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${start.latitude},${start.longitude}&'
          'destination=${end.latitude},${end.longitude}&'
          'key=$apiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('❌ Error getting directions: $e');
    }
    return null;
  }

  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0;
    int len = polyline.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
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
            ),
          ),
        ],
      ),
    );
  }

  void _loadDonationMarkers() {
    print('🍽️ Loading donation markers...');
    _donationService.getAvailableDonations().listen((donations) {
      if (!mounted) return;
      
      print('✅ Loaded ${donations.length} donations');
      
      setState(() {
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
      print('❌ Error loading donation markers: $error');
    });
  }

  void _showDonationDetails(DonationModel donation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.restaurant_rounded,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                donation.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(donation.description),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Text('Donor: ${donation.donorEmail.split('@')[0]}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Text('Pickup: ${_formatDateTime(donation.pickupTime)}'),
              ],
            ),
            if (donation.marketAddress != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Market: ${donation.marketAddress}')),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _startTrackingToMarket(donation);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22c55e),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.directions, size: 18),
            label: const Text('Get Directions'),
          ),
        ],
      ),
    );
  }

  void _startTrackingToMarket(DonationModel donation) async {
    try {
      await _locationService.startDonationTracking(donation.id);
      if (!mounted) return;
      
      setState(() {
        _isTracking = true;
        _trackingDonationId = donation.id;
      });

      // Draw direction line to donation location
      if (_currentLocation != null && donation.marketLocation != null) {
        await _drawDirectionLine(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
          LatLng(donation.marketLocation!.latitude, donation.marketLocation!.longitude),
        );
      }

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
            Text('Loading Map...'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
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
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(7.1907, 125.4553),
          zoom: 12.0,
        ),
        onMapCreated: (GoogleMapController controller) {
          print('✅ GoogleMap created successfully');
          _mapController = controller;
          
          if (mounted) {
            setState(() {
              _isMapCreated = true;
            });
          }

          // Move to current location after map is created
          if (_currentLocation != null) {
            _moveToLocation(
              LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
              14.0,
            );
          }
        },
        markers: _markers,
        polylines: _polylines,
        mapType: MapType.normal,
        // Explicitly enable gesture controls (pinch to zoom included)
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        compassEnabled: true,
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
         // Zoom in / Zoom out buttons (pinch still works; these provide quick taps)
         FloatingActionButton(
           onPressed: _zoomIn,
           backgroundColor: const Color(0xFF22c55e),
           foregroundColor: Colors.white,
           mini: true,
           heroTag: "zoom_in",
           child: const Icon(Icons.add),
         ),
         const SizedBox(height: 8),
         FloatingActionButton(
           onPressed: _zoomOut,
           backgroundColor: const Color(0xFF22c55e),
           foregroundColor: Colors.white,
           mini: true,
           heroTag: "zoom_out",
           child: const Icon(Icons.remove),
         ),
         const SizedBox(height: 8),
          if (_polylines.isNotEmpty)
            FloatingActionButton(
              onPressed: () {
                setState(() {
                  _polylines.clear();
                });
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              heroTag: "clear_directions",
              child: const Icon(Icons.clear),
            ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _getCurrentLocation,
            backgroundColor: const Color(0xFF22c55e),
            foregroundColor: Colors.white,
            heroTag: "my_location",
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}