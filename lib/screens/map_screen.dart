import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' hide LocationAccuracy;
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
import '../constants.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LocationData? _currentLocation;
  final Location _location = Location();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  final LocationTrackingService _locationService = LocationTrackingService();
  final DonationService _donationService = DonationService();
  final DonorStatsService _donorStatsService = Get.put(DonorStatsService());
  final MessagingService _messagingService = MessagingService();
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

  Future<void> _getDirectionsToDonor(GeoPoint location, String donorName) async {
    try {
      // Get current location first
      if (_currentLocation == null) {
        // Try to get current location using Location package
        try {
          bool serviceEnabled = await _location.serviceEnabled();
          if (!serviceEnabled) {
            serviceEnabled = await _location.requestService();
            if (!serviceEnabled) {
              Get.snackbar(
                'Error',
                'Location services are disabled. Please enable them in settings.',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
              );
              return;
            }
          }

          PermissionStatus permissionGranted = await _location.hasPermission();
          if (permissionGranted == PermissionStatus.denied) {
            permissionGranted = await _location.requestPermission();
            if (permissionGranted != PermissionStatus.granted) {
              Get.snackbar(
                'Error',
                'Location permission denied. Please grant location permission.',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
              );
              return;
            }
          }

          _currentLocation = await _location.getLocation();
        } catch (e) {
          Get.snackbar(
            'Error',
            'Unable to get your current location. Please enable location services.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
          return;
        }
      }

      if (_currentLocation == null) {
        Get.snackbar(
          'Error',
          'Current location not available',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final double destLat = location.latitude;
      final double destLng = location.longitude;
      final LatLng destination = LatLng(destLat, destLng);
      final LatLng origin = LatLng(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
      );

      // Show loading indicator
      Get.snackbar(
        'Loading',
        'Getting directions to $donorName...',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      // Draw direction line on the map
      try {
        await _drawDirectionLine(origin, destination);
      } catch (e) {
        print('❌ Error in _drawDirectionLine: $e');
        String errorMessage = 'Failed to get directions';
        if (e.toString().contains('API key')) {
          errorMessage = 'Google Maps API key issue. Please configure your API key.';
        } else if (e.toString().contains('quota') || e.toString().contains('QUERY_LIMIT')) {
          errorMessage = 'Directions API quota exceeded. Please try again later.';
        } else if (e.toString().contains('route') || e.toString().contains('No route')) {
          errorMessage = 'No route found between locations.';
        } else if (e.toString().contains('timeout') || e.toString().contains('connection')) {
          errorMessage = 'Connection timeout. Please check your internet and try again.';
        } else {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        
        Get.snackbar(
          'Directions Unavailable',
          errorMessage,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Move camera to show both locations with the route
      if (_mapController != null) {
        final bounds = LatLngBounds(
          southwest: LatLng(
            origin.latitude < destination.latitude
                ? origin.latitude
                : destination.latitude,
            origin.longitude < destination.longitude
                ? origin.longitude
                : destination.longitude,
          ),
          northeast: LatLng(
            origin.latitude > destination.latitude
                ? origin.latitude
                : destination.latitude,
            origin.longitude > destination.longitude
                ? origin.longitude
                : destination.longitude,
          ),
        );

        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100.0),
        );
      }

      // Show success message
      Get.snackbar(
        'Success',
        'Directions to $donorName shown on map',
        backgroundColor: const Color(0xFF22c55e),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to get directions: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _startChatWithDonor(String donorId, String donorName) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        Get.snackbar(
          'Error',
          'You must be logged in to start a chat',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Get current user data
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!currentUserDoc.exists) {
        Get.snackbar(
          'Error',
          'User data not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final currentUserData = currentUserDoc.data()!;
      final receiverName = currentUserData['displayName'] ?? 
                          currentUser.displayName ?? 
                          currentUser.email?.split('@')[0] ?? 
                          'User';
      
      // Create a general chat ID (without donationId)
      final chatId = '${donorId}_${currentUser.uid}_general';
      
      // Check if chat already exists
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      
      String finalChatId = chatId;
      
      if (!chatDoc.exists) {
        // Create new general chat
        final chat = {
          'id': chatId,
          'donorId': donorId,
          'receiverId': currentUser.uid,
          'donorName': donorName,
          'receiverName': receiverName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': 'Chat started',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': currentUser.uid,
          'donorActive': false,
          'receiverActive': true,
          'donationId': null, // General chat without specific donation
        };
        
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .set(chat);
        
        finalChatId = chatId;
      } else {
        finalChatId = chatDoc.id;
      }

      // Navigate to chat screen
      Navigator.of(context).pop(); // Close the popup first
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: finalChatId,
            otherUserName: donorName,
            otherUserType: 'donor',
          ),
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to start chat: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
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

      // Show DonorInfoPopup with "Go to Market" button (Shopee/Lazada style)
      showDialog(
        context: context,
        builder: (context) => DonorInfoPopup(
          donorId: donorId,
          donorName: donorName,
          donorEmail: donorEmail,
          location: GeoPoint(location.latitude, location.longitude),
          marketAddress: marketAddress,
          isOnline: isOnline,
          onStartChat: () {
            _startChatWithDonor(donorId, donorName);
          },
          onShowMoreDetails: () {
            Navigator.of(context).pop();
            // Navigate to Market Details Screen showing statistics and feedback
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
        // Use marketName instead of displayName for donor name
        final donorName = marketName.isNotEmpty 
            ? marketName
            : (data['name'] ?? data['displayName'] ?? (donorEmail.isNotEmpty ? donorEmail.split('@')[0] : 'Donor'));
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
  }) async {
    // Get online status
    bool isOnline = false;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(donorId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        isOnline = userData?['isOnline'] ?? false;
      }
    } catch (e) {
      print('Error getting online status: $e');
    }

    // Show DonorInfoPopup with "Go to Market" button (Shopee/Lazada style)
    showDialog(
      context: context,
      builder: (context) => DonorInfoPopup(
        donorId: donorId,
        donorName: donorName,
        donorEmail: donorEmail,
        location: GeoPoint(marketLocation.latitude, marketLocation.longitude),
        marketAddress: marketAddress,
        isOnline: isOnline,
        onStartChat: () {
          _startChatWithDonor(donorId, donorName);
        },
        onShowMoreDetails: () {
          Navigator.of(context).pop();
          // Navigate to Market Details Screen showing statistics and feedback
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
      print('📍 Drawing direction line from ${start.latitude},${start.longitude} to ${end.latitude},${end.longitude}');
      
      // Use Google Directions API to get route
      final directions = await _getDirections(start, end);
      
      if (directions == null) {
        print('❌ Directions API returned null');
        throw Exception('Failed to get directions from API');
      }
      
      print('📊 Directions response: ${directions['status']}');
      
      if (directions['status'] != 'OK') {
        print('❌ Directions API status: ${directions['status']}');
        print('❌ Error message: ${directions['error_message'] ?? 'No error message'}');
        throw Exception('Directions API returned: ${directions['status']}');
      }
      
      if ((directions['routes'] as List).isEmpty) {
        print('❌ No routes found in directions response');
        throw Exception('No routes found');
      }
      
      final route = directions['routes'][0];
      final overviewPolyline = route['overview_polyline'];
      
      if (overviewPolyline == null || overviewPolyline['points'] == null) {
        print('❌ No polyline points found in route');
        throw Exception('No polyline data in route');
      }
      
      final points = overviewPolyline['points'] as String;
      print('📈 Polyline string length: ${points.length}');
      
      final decodedPoints = _decodePolyline(points);
      print('✅ Decoded ${decodedPoints.length} points from polyline');
      
      if (decodedPoints.isEmpty) {
        print('❌ Decoded points list is empty');
        throw Exception('Failed to decode polyline points');
      }
      
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('direction_line'),
            points: decodedPoints,
            color: Colors.blue, // Changed to blue for better visibility
            width: 6, // Increased width
            geodesic: true,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      });
      
      print('✅ Polyline added to map with ${decodedPoints.length} points');
      print('✅ Polyline bounds: ${decodedPoints.first} to ${decodedPoints.last}');
      
      // Force map update by moving camera slightly then back
      if (_mapController != null && decodedPoints.isNotEmpty) {
        // Calculate bounds of the route
        double minLat = decodedPoints.first.latitude;
        double maxLat = decodedPoints.first.latitude;
        double minLng = decodedPoints.first.longitude;
        double maxLng = decodedPoints.first.longitude;
        
        for (final point in decodedPoints) {
          if (point.latitude < minLat) minLat = point.latitude;
          if (point.latitude > maxLat) maxLat = point.latitude;
          if (point.longitude < minLng) minLng = point.longitude;
          if (point.longitude > maxLng) maxLng = point.longitude;
        }
        
        // Add padding
        final latPadding = (maxLat - minLat) * 0.1;
        final lngPadding = (maxLng - minLng) * 0.1;
        
        final bounds = LatLngBounds(
          southwest: LatLng(minLat - latPadding, minLng - lngPadding),
          northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
        );
        
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100.0),
        );
        
        print('✅ Camera moved to show route bounds');
      }
    } catch (e, stackTrace) {
      print('❌ Error drawing direction line: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _getDirections(LatLng start, LatLng end) async {
    try {
      // Validate coordinates first
      if (start.latitude.isNaN || start.longitude.isNaN || 
          end.latitude.isNaN || end.longitude.isNaN) {
        print('❌ Invalid coordinates: start=(${start.latitude}, ${start.longitude}), end=(${end.latitude}, ${end.longitude})');
        throw Exception('Invalid location coordinates');
      }
      
      if (start.latitude.abs() > 90 || start.longitude.abs() > 180 ||
          end.latitude.abs() > 90 || end.longitude.abs() > 180) {
        print('❌ Coordinates out of bounds: start=(${start.latitude}, ${start.longitude}), end=(${end.latitude}, ${end.longitude})');
        throw Exception('Coordinates are out of valid range');
      }
      
      // Use API key from constants
      final apiKey = google_api_key;
      
      if (apiKey.isEmpty || apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        print('❌ Google API key is not configured');
        throw Exception('Google Maps API key is not configured. Please set up your API key.');
      }
      
      print('🔑 Using API key: ${apiKey.substring(0, 10)}...${apiKey.substring(apiKey.length - 4)}');
      
      final url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${start.latitude},${start.longitude}&'
          'destination=${end.latitude},${end.longitude}&'
          'key=$apiKey&'
          'mode=driving';
      
      print('🗺️ Requesting directions from (${start.latitude}, ${start.longitude}) to (${end.latitude}, ${end.longitude})');
      print('🗺️ API URL (key hidden): ${url.replaceAll(apiKey, 'API_KEY_HIDDEN')}');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Directions API request timed out. Please check your internet connection.');
        },
      );
      
      print('🗺️ Directions API response status: ${response.statusCode}');
      print('🗺️ Response headers: ${response.headers}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;
        print('🗺️ API Status: $status');
        print('🗺️ Routes count: ${(data['routes'] as List?)?.length ?? 0}');
        
        // Log the full response for debugging (first 500 chars to avoid spam)
        final responsePreview = response.body.length > 500 
            ? '${response.body.substring(0, 500)}...' 
            : response.body;
        print('🗺️ API Response preview: $responsePreview');
        
        if (status == 'OK') {
          if ((data['routes'] as List).isNotEmpty) {
            print('✅ Directions received successfully');
            return data;
          } else {
            print('⚠️ Directions API returned OK but no routes');
            print('⚠️ Full response: ${response.body}');
            throw Exception('No route found between the selected locations.');
          }
        } else {
          final errorMessage = data['error_message'] as String? ?? 'Unknown error';
          print('⚠️ Directions API returned: $status');
          print('⚠️ Error message: $errorMessage');
          print('⚠️ Full API response: ${response.body}');
          
          // Provide user-friendly error messages
          String userMessage;
          switch (status) {
            case 'REQUEST_DENIED':
              userMessage = 'Directions API access denied. The API key may be invalid, restricted, or Directions API is not enabled. Check your Google Cloud Console settings.';
              break;
            case 'OVER_QUERY_LIMIT':
              userMessage = 'Directions API quota exceeded. Please check your billing or try again later.';
              break;
            case 'ZERO_RESULTS':
              userMessage = 'No route found between the selected locations.';
              break;
            case 'NOT_FOUND':
              userMessage = 'Location not found. Please check the destination address.';
              break;
            case 'INVALID_REQUEST':
              userMessage = 'Invalid request. Please check the coordinates and try again.';
              break;
            default:
              userMessage = 'Directions API error ($status): $errorMessage';
          }
          throw Exception(userMessage);
        }
      } else {
        print('❌ Directions API HTTP error: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        throw Exception('Failed to connect to Directions API. HTTP ${response.statusCode}. Please check your API key and internet connection.');
      }
    } catch (e, stackTrace) {
      print('❌ Error getting directions: $e');
      print('❌ Stack trace: $stackTrace');
      // Re-throw with a more user-friendly message if it's already an Exception
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get directions: ${e.toString()}');
    }
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