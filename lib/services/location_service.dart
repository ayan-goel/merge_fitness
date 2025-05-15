import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection for storing real-time location data
  static const String _locationCollection = 'trainer_locations';
  
  // Stream subscription for background location updates
  StreamSubscription<Position>? _positionStreamSubscription;
  
  // Check location permissions
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    
    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    
    // Check for location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }
  
  // Get current trainer location
  Future<Map<String, dynamic>?> getTrainerLocation(String trainerId) async {
    try {
      final doc = await _firestore.collection(_locationCollection).doc(trainerId).get();
      
      if (!doc.exists) {
        print('Trainer location document does not exist for trainer: $trainerId');
        return null;
      }
      
      final data = doc.data() as Map<String, dynamic>;
      
      // Check if trainer is sharing location
      if (data['isSharing'] != true) {
        return null;
      }
      
      // Add timestamp age if available
      final timestamp = data['timestamp'] as Timestamp?;
      int ageInMinutes = 0;
      
      if (timestamp != null) {
        final DateTime locationTime = timestamp.toDate();
        final DateTime now = DateTime.now();
        ageInMinutes = now.difference(locationTime).inMinutes;
      } else {
        print('Timestamp is null for trainer: $trainerId');
      }
      
      // Return data regardless of age as long as isSharing is true
      return {
        ...data,
        'ageInMinutes': ageInMinutes,
      };
    } catch (e) {
      print('Error getting trainer location: $e');
      return null;
    }
  }
  
  // Start sharing location for trainers
  Future<void> startSharingLocation({
    int distanceFilter = 10, // Only update when moved at least this many meters
    LocationAccuracy accuracy = LocationAccuracy.high, // High accuracy
  }) async {
    // Check permission
    final hasPermission = await checkLocationPermission();
    if (!hasPermission) {
      throw Exception('Location permission not granted');
    }
    
    // Get current user ID
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    // Stop any existing stream
    await stopSharingLocation();
    
    // Get current position first to set initial data
    try {
      final Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      // Set initial location data immediately, don't wait for stream updates
      await _firestore.collection(_locationCollection).doc(userId).set({
        'latitude': initialPosition.latitude,
        'longitude': initialPosition.longitude,
        'accuracy': initialPosition.accuracy,
        'heading': initialPosition.heading,
        'speed': initialPosition.speed,
        'timestamp': FieldValue.serverTimestamp(),
        'isSharing': true,
      }, SetOptions(merge: true));
      
      print('Initial location set for trainer $userId: ${initialPosition.latitude}, ${initialPosition.longitude}');
    } catch (e) {
      print('Error getting initial position: $e');
      // Continue anyway, as the position stream might still work
    }
    
    // Start a new stream
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).listen(
      (Position position) async {
        try {
          // Update location in Firestore
          await _firestore.collection(_locationCollection).doc(userId).set({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'heading': position.heading,
            'speed': position.speed,
            'timestamp': FieldValue.serverTimestamp(),
            'isSharing': true,
          }, SetOptions(merge: true));
          
          print('Updated location for trainer $userId: ${position.latitude}, ${position.longitude}');
        } catch (e) {
          print('Error updating location: $e');
        }
      },
      onError: (error) {
        print('Error getting location: $error');
        stopSharingLocation();
      },
    );
    
    // Update status in Firestore
    await _firestore.collection(_locationCollection).doc(userId).set({
      'isSharing': true,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  
  // Stop sharing location
  Future<void> stopSharingLocation() async {
    // Cancel the subscription if it exists
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    
    // Get current user ID
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      return;
    }
    
    // Update status in Firestore
    await _firestore.collection(_locationCollection).doc(userId).set({
      'isSharing': false,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  
  // Check if trainer is currently sharing location
  Future<bool> isTrainerSharingLocation(String trainerId) async {
    try {
      final doc = await _firestore.collection(_locationCollection).doc(trainerId).get();
      
      if (!doc.exists) {
        print('Trainer location document does not exist for trainer: $trainerId');
        return false;
      }
      
      final data = doc.data() as Map<String, dynamic>;
      final isSharing = data['isSharing'] == true;
      
      // Check if there's actual location data present
      if (isSharing) {
        final hasLatitude = data.containsKey('latitude') && data['latitude'] != null;
        final hasLongitude = data.containsKey('longitude') && data['longitude'] != null;
        
        // If sharing is true but no location data, print debug info
        if (!hasLatitude || !hasLongitude) {
          print('Trainer is set as sharing but missing location data. Has lat: $hasLatitude, has lng: $hasLongitude');
        }
        
        // Still return true if isSharing is true, even if location data isn't present yet
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error checking if trainer is sharing location: $e');
      return false;
    }
  }
  
  // Get client's current position
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        return null;
      }
      
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }
  
  // Calculate distance between client and trainer in miles
  Future<double?> calculateDistanceToTrainer(String trainerId) async {
    try {
      // Get trainer location
      final trainerLocation = await getTrainerLocation(trainerId);
      if (trainerLocation == null) {
        return null;
      }
      
      // Get client's current position
      final clientPosition = await getCurrentPosition();
      if (clientPosition == null) {
        return null;
      }
      
      // Calculate distance in meters
      final distanceInMeters = Geolocator.distanceBetween(
        clientPosition.latitude, 
        clientPosition.longitude,
        trainerLocation['latitude'], 
        trainerLocation['longitude']
      );
      
      // Convert to miles (1 meter = 0.000621371 miles)
      return distanceInMeters * 0.000621371;
    } catch (e) {
      print('Error calculating distance: $e');
      return null;
    }
  }
  
  // Estimate travel time (very basic calculation)
  Future<int?> estimateTravelTimeInMinutes(String trainerId, {double averageSpeedMph = 30}) async {
    try {
      final distanceInMiles = await calculateDistanceToTrainer(trainerId);
      if (distanceInMiles == null) {
        return null;
      }
      
      // Time = distance / speed (in hours)
      final timeInHours = distanceInMiles / averageSpeedMph;
      
      // Convert to minutes
      return (timeInHours * 60).round();
    } catch (e) {
      print('Error estimating travel time: $e');
      return null;
    }
  }
} 