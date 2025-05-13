import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/session_model.dart';
import '../../services/location_service.dart';

class TrainerLocationScreen extends StatefulWidget {
  final TrainingSession session;
  
  const TrainerLocationScreen({
    super.key,
    required this.session,
  });

  @override
  State<TrainerLocationScreen> createState() => _TrainerLocationScreenState();
}

class _TrainerLocationScreenState extends State<TrainerLocationScreen> {
  // Controller for the Google Map
  Completer<GoogleMapController> _mapController = Completer();
  
  // Trainer location service
  final LocationService _locationService = LocationService();
  
  // Map markers
  Set<Marker> _markers = {};
  
  // Trainer's current position
  LatLng? _trainerPosition;
  
  // Timer for refreshing trainer location
  Timer? _locationTimer;
  
  // Location refresh interval (in seconds)
  static const int _refreshInterval = 5;
  
  // Loading state
  bool _isLoading = true;
  
  // Error message
  String? _errorMessage;
  
  // Distance to trainer in miles
  double? _distanceToTrainer;
  
  // Estimated travel time in minutes
  int? _travelTimeMinutes;

  @override
  void initState() {
    super.initState();
    _checkTrainerSharing();
  }
  
  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }
  
  // Check if trainer is sharing their location
  Future<void> _checkTrainerSharing() async {
    try {
      final isSharing = await _locationService.isTrainerSharingLocation(widget.session.trainerId);
      
      if (!isSharing) {
        setState(() {
          _isLoading = false;
          _errorMessage = '${widget.session.trainerName} is not sharing their location yet.';
        });
        return;
      }
      
      // Check for client location permission
      final hasPermission = await _locationService.checkLocationPermission();
      if (!hasPermission) {
        setState(() {
          _errorMessage = 'Location permission is required to show distance information.';
          _isLoading = false;
        });
        return;
      }
      
      // Trainer is sharing location, get initial position
      await _updateTrainerLocation();
      
      // Start periodic updates
      _startLocationUpdates();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error checking trainer location: $e';
      });
    }
  }
  
  // Update the trainer's location
  Future<void> _updateTrainerLocation() async {
    try {
      final locationData = await _locationService.getTrainerLocation(widget.session.trainerId);
      
      if (locationData == null) {
        setState(() {
          _errorMessage = 'Trainer location not available.';
          _isLoading = false;
        });
        return;
      }
      
      final lat = locationData['latitude'] as double;
      final lng = locationData['longitude'] as double;
      final heading = locationData['heading'] as double? ?? 0.0;
      final updatedAt = locationData['timestamp'];
      
      // Calculate distance and travel time
      final distance = await _locationService.calculateDistanceToTrainer(widget.session.trainerId);
      final travelTime = await _locationService.estimateTravelTimeInMinutes(widget.session.trainerId);
      
      setState(() {
        _trainerPosition = LatLng(lat, lng);
        _markers = {
          Marker(
            markerId: const MarkerId('trainer'),
            position: _trainerPosition!,
            infoWindow: InfoWindow(
              title: widget.session.trainerName,
              snippet: 'Last updated: ${_formatTimestamp(updatedAt)}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            rotation: heading, // Point marker in direction of travel
          ),
        };
        _distanceToTrainer = distance;
        _travelTimeMinutes = travelTime;
        _isLoading = false;
      });
      
      // Move camera to trainer position
      _moveCamera();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting trainer location: $e';
        _isLoading = false;
      });
    }
  }
  
  // Format timestamp for display
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      final DateTime dateTime = timestamp.toDate();
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  // Start periodic location updates
  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(
      Duration(seconds: _refreshInterval),
      (_) => _updateTrainerLocation(),
    );
  }
  
  // Move camera to focus on the trainer
  Future<void> _moveCamera() async {
    if (_trainerPosition == null) return;
    
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _trainerPosition!,
          zoom: 15.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking ${widget.session.trainerName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateTrainerLocation,
            tooltip: 'Refresh location',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _trainerPosition != null ? FloatingActionButton(
        onPressed: _moveCamera,
        child: const Icon(Icons.my_location),
        tooltip: 'Focus on trainer',
      ) : null,
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading trainer location...'),
          ],
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Trainers can share their location when heading to your session.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _checkTrainerSharing();
                },
                child: const Text('Check Again'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_trainerPosition == null) {
      return const Center(
        child: Text('Trainer location not available'),
      );
    }
    
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _trainerPosition!,
            zoom: 15.0,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          mapToolbarEnabled: true,
          onMapCreated: (GoogleMapController controller) {
            _mapController.complete(controller);
          },
        ),
        
        // Location info panel
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Training Session',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 8),
                      Text('Trainer: ${widget.session.trainerName}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 8),
                      Text('Time: ${widget.session.formattedTimeRange}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Location: ${widget.session.location}'),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.directions, size: 16),
                      const SizedBox(width: 8),
                      _distanceToTrainer != null 
                          ? Row(
                              children: [
                                Text(
                                  'Distance: ${_distanceToTrainer!.toStringAsFixed(1)} miles',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getDistanceColor(_distanceToTrainer!),
                                  ),
                                ),
                              ],
                            )
                          : const Text('Distance: Calculating...'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 16),
                      const SizedBox(width: 8),
                      _travelTimeMinutes != null
                          ? Text(
                              'Est. arrival: ${_formatArrivalTime(_travelTimeMinutes!)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )
                          : const Text('Est. arrival: Calculating...'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getDistanceColor(double distance) {
    if (distance < 0.5) {
      return Colors.green;
    } else if (distance < 1.0) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  String _formatArrivalTime(int minutes) {
    final now = DateTime.now();
    final arrival = now.add(Duration(minutes: minutes));
    return '${arrival.hour}:${arrival.minute.toString().padLeft(2, '0')}';
  }
} 