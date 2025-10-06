import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class LocationTrackingService {

  /// Returns true if the given latitude/longitude is within Davao City bounds.
  /// Adjust the bounding box as needed for more accuracy.
  bool isWithinDavaoCity(double latitude, double longitude) {
    // Rough bounding box for Davao City
    return latitude >= 7.0 && latitude <= 7.3 && longitude >= 125.3 && longitude <= 125.7;
  }
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription<Position>? _positionStream;
  Timer? _locationUpdateTimer;
  Position? _lastKnownPosition;
  
  // Start tracking user location
  Future<void> startLocationTracking() async {
    try {
      // Request location permission
      final permission = await Permission.location.request();
      if (permission != PermissionStatus.granted) {
        throw Exception('Location permission denied');
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Get initial position
      try {
        _lastKnownPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await _updateUserLocation(_lastKnownPosition!);
      } catch (e) {
        print('Error getting initial position: $e');
      }

      // Start listening to position changes
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Update every 5 meters
        ),
      ).listen(
        (Position position) {
          _lastKnownPosition = position;
          _updateUserLocation(position);
        },
        onError: (error) {
          print('Location tracking error: $error');
        },
      );

      // Set up periodic location updates to Firestore
      _locationUpdateTimer = Timer.periodic(
        const Duration(seconds: 15), // Update every 15 seconds
        (timer) {
          if (_lastKnownPosition != null) {
            _updateUserLocation(_lastKnownPosition!);
          }
        },
      );
    } catch (e) {
      throw Exception('Failed to start location tracking: $e');
    }
  }

  // Stop tracking user location
  Future<void> stopLocationTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    
    // Update user as offline
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Update user location in Firestore
  Future<void> _updateUserLocation(Position position) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final location = GeoPoint(position.latitude, position.longitude);
      
      await _firestore.collection('users').doc(user.uid).update({
        'location': location,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user location: $e');
    }
  }

  // Update receiver location for a specific donation (for tracking)
  Future<void> updateReceiverLocationForDonation(String donationId, Position position) async {
    try {
      final location = GeoPoint(position.latitude, position.longitude);
      
      await _firestore.collection('donations').doc(donationId).update({
        'receiverLocation': location,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating receiver location for donation: $e');
    }
  }

  // Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final permission = await Permission.location.request();
      if (permission != PermissionStatus.granted) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  // Calculate distance between two points
  double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Check if receiver is near donor's market
  Future<bool> isReceiverNearMarket(String donationId, double thresholdMeters) async {
    try {
      final donationDoc = await _firestore.collection('donations').doc(donationId).get();
      if (!donationDoc.exists) return false;

      final donationData = donationDoc.data()!;
      final marketLocation = donationData['marketLocation'] as GeoPoint?;
      final receiverLocation = donationData['receiverLocation'] as GeoPoint?;

      if (marketLocation == null || receiverLocation == null) return false;

      final distance = calculateDistance(
        marketLocation.latitude,
        marketLocation.longitude,
        receiverLocation.latitude,
        receiverLocation.longitude,
      );

      return distance <= thresholdMeters;
    } catch (e) {
      print('Error checking proximity: $e');
      return false;
    }
  }

  // Get user's location
  Future<GeoPoint?> getUserLocation(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      return userDoc.data()?['location'] as GeoPoint?;
    } catch (e) {
      print('Error getting user location: $e');
      return null;
    }
  }

  // Start tracking for a specific donation (receiver tracking donor)
  Future<void> startDonationTracking(String donationId) async {
    try {
      // Start general location tracking
      await startLocationTracking();
      
      // Set up periodic updates for this specific donation
      Timer.periodic(
        const Duration(seconds: 15), // Update every 15 seconds for active tracking
        (timer) async {
          if (_lastKnownPosition != null) {
            await updateReceiverLocationForDonation(donationId, _lastKnownPosition!);
            
            // Check if receiver is near market
            final isNear = await isReceiverNearMarket(donationId, 50.0); // 50 meters threshold
            if (isNear) {
              // Trigger arrival notification
              await _triggerArrivalNotification(donationId);
              timer.cancel(); // Stop tracking when arrived
            }
          }
        },
      );
    } catch (e) {
      throw Exception('Failed to start donation tracking: $e');
    }
  }

  // Trigger arrival notification
  Future<void> _triggerArrivalNotification(String donationId) async {
    try {
      await _firestore.collection('donations').doc(donationId).update({
        'receiverArrived': true,
        'arrivalTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error triggering arrival notification: $e');
    }
  }

  // Get real-time location updates for a donation
  Stream<GeoPoint?> getDonationLocationUpdates(String donationId) {
    return _firestore
        .collection('donations')
        .doc(donationId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return doc.data()?['receiverLocation'] as GeoPoint?;
      }
      return null;
    });
  }

  // Check location permissions
  Future<bool> hasLocationPermission() async {
    final permission = await Permission.location.status;
    return permission == PermissionStatus.granted;
  }

  // Request location permission
  Future<bool> requestLocationPermission() async {
    final permission = await Permission.location.request();
    return permission == PermissionStatus.granted;
  }
}