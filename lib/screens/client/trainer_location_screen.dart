import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/session_model.dart';
import '../../services/location_service.dart';
import '../../theme/app_styles.dart';
import '../../theme/app_widgets.dart';
import '../../theme/app_animations.dart';
import 'package:intl/intl.dart';

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
    if (!mounted) return;
    
    try {
      final isSharing = await _locationService.isTrainerSharingLocation(widget.session.trainerId);
      
      if (!mounted) return;
      
      if (!isSharing) {
        setState(() {
          _isLoading = false;
          _errorMessage = '${widget.session.trainerName} is not sharing their location yet.';
        });
        return;
      }
      
      // Check for client location permission
      final hasPermission = await _locationService.checkLocationPermission();
      
      if (!mounted) return;
      
      if (!hasPermission) {
        setState(() {
          _errorMessage = 'Location permission is required to show distance information.';
          _isLoading = false;
        });
        return;
      }
      
      // Trainer is sharing location, get initial position
      await _updateTrainerLocation();
      
      if (!mounted) return;
      
      // Start periodic updates
      _startLocationUpdates();
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error checking trainer location: $e';
      });
    }
  }
  
  // Update the trainer's location
  Future<void> _updateTrainerLocation() async {
    if (!mounted) return;
    
    try {
      final locationData = await _locationService.getTrainerLocation(widget.session.trainerId);
      
      if (!mounted) return;
      
      if (locationData == null) {
        setState(() {
          _errorMessage = '${widget.session.trainerName} has enabled location sharing, but their location data is not available yet. Please try again in a moment.';
          _isLoading = false;
        });
        return;
      }
      
      final lat = locationData['latitude'] as double?;
      final lng = locationData['longitude'] as double?;
      
      if (lat == null || lng == null) {
        setState(() {
          _errorMessage = '${widget.session.trainerName} has enabled location sharing, but their location data is still being updated. Please check again in a moment.';
          _isLoading = false;
        });
        return;
      }
      
      final heading = locationData['heading'] as double? ?? 0.0;
      final updatedAt = locationData['timestamp'];
      
      // Calculate distance and travel time
      final distance = await _locationService.calculateDistanceToTrainer(widget.session.trainerId);
      final travelTime = await _locationService.estimateTravelTimeInMinutes(widget.session.trainerId);
      
      if (!mounted) return;
      
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
        _errorMessage = null; // Clear any previous error
      });
      
      // Move camera to trainer position
      _moveCamera();
    } catch (e) {
      if (!mounted) return;
      
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
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
      ),
      body: _buildBody(),
      backgroundColor: AppStyles.offWhite,
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppWidgets.circularProgressIndicator(
              color: AppStyles.primarySage,
              size: 50,
            ),
            const SizedBox(height: 24),
            AppAnimations.fadeIn(
              child: const Text(
                'Loading trainer location...',
                style: TextStyle(
                  color: AppStyles.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    if (_errorMessage != null) {
      return AppAnimations.fadeSlide(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppStyles.slateGray.withOpacity(0.2),
                    shape: BoxShape.circle,
                    boxShadow: AppStyles.cardShadow,
                  ),
                  child: const Icon(
                    Icons.location_off,
                    size: 40,
                    color: AppStyles.errorRed,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Trainers can share their location with you at any time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppStyles.slateGray,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    
                    // Add a small delay to give time for location data to update
                    await Future.delayed(const Duration(seconds: 2));
                    
                    if (mounted) {
                      _checkTrainerSharing();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyles.primarySage,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Check Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (_trainerPosition == null) {
      return const Center(
        child: Text(
          'Trainer location not available',
          style: TextStyle(
            color: AppStyles.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    
    return Stack(
      children: [
        // Map with light style
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
            _setMapStyle(controller);
          },
        ),
        
        // "Live" indicator
        Positioned(
          top: 16,
          left: 16,
          child: _buildLiveIndicator(),
        ),
        
        // Focus on trainer button
        Positioned(
          top: 16,
          right: 16,
          child: _buildFocusButton(),
        ),
        
        // Location info panel - positioned at the bottom
        Positioned(
          bottom: 40,
          left: 16,
          right: 16,
          child: _buildLocationInfoPanel(),
        ),
      ],
    );
  }
  
  Widget _buildLiveIndicator() {
    return AppAnimations.fadeIn(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppStyles.primarySage,
            width: 1,
          ),
          boxShadow: AppStyles.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppWidgets.pulsatingDot(color: AppStyles.primarySage),
            const SizedBox(width: 8),
            const Text(
              'LIVE',
              style: TextStyle(
                color: AppStyles.textDark,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFocusButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: AppStyles.cardShadow,
      ),
      child: IconButton(
        onPressed: _moveCamera,
        icon: const Icon(Icons.my_location),
        tooltip: 'Focus on trainer',
        color: AppStyles.primarySage,
        iconSize: 24,
        splashRadius: 24,
      ),
    );
  }
  
  Widget _buildLocationInfoPanel() {
    return AppAnimations.fadeSlide(
      beginOffset: const Offset(0, 0.3),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppStyles.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppStyles.primarySage,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Training Session',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppStyles.textDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.session.formattedDate,
                          style: const TextStyle(
                            color: AppStyles.slateGray,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoItem(
                    icon: Icons.person,
                    label: 'Trainer',
                    value: widget.session.trainerName,
                    isDark: false,
                  ),
                  _buildInfoItem(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: widget.session.formattedTimeRange,
                    isDark: false,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppStyles.offWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.dividerGrey,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 18,
                      color: AppStyles.slateGray,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.session.location,
                        style: const TextStyle(
                          color: AppStyles.textDark,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(
                color: AppStyles.dividerGrey,
                height: 1,
                thickness: 1,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDistanceInfo(isDark: false),
                  ),
                  Container(
                    height: 36,
                    width: 1,
                    color: AppStyles.dividerGrey,
                  ),
                  Expanded(
                    child: _buildTimeInfo(isDark: false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Info item with icon, label and value
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool isDark = true,
  }) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? AppStyles.lightCharcoal : AppStyles.offWhite,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 14,
              color: AppStyles.primarySage,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppStyles.slateGray,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? AppStyles.textLight : AppStyles.textDark,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Distance info card
  Widget _buildDistanceInfo({bool isDark = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.directions,
                size: 14,
                color: AppStyles.primarySage,
              ),
              const SizedBox(width: 4),
              Text(
                'Distance',
                style: TextStyle(
                  fontSize: 11,
                  color: AppStyles.slateGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_distanceToTrainer != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_distanceToTrainer!.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _getDistanceColor(_distanceToTrainer!),
                  ),
                ),
                Text(
                  ' miles',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppStyles.textLight : AppStyles.textDark,
                  ),
                ),
              ],
            )
          else
            Text(
              'Calculating...',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppStyles.textLight : AppStyles.textDark,
              ),
            ),
        ],
      ),
    );
  }
  
  // Time info card
  Widget _buildTimeInfo({bool isDark = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer,
                size: 14,
                color: AppStyles.softGold,
              ),
              const SizedBox(width: 4),
              Text(
                'Est. Arrival',
                style: TextStyle(
                  fontSize: 11,
                  color: AppStyles.slateGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_travelTimeMinutes != null)
            Text(
              _formatArrivalTime(_travelTimeMinutes!),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppStyles.softGold,
              ),
            )
          else
            Text(
              'Calculating...',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppStyles.textLight : AppStyles.textDark,
              ),
            ),
        ],
      ),
    );
  }

  Color _getDistanceColor(double distance) {
    if (distance < 0.5) {
      return AppStyles.successGreen;
    } else if (distance < 1.0) {
      return AppStyles.warningAmber;
    } else {
      return AppStyles.errorRed;
    }
  }

  String _formatArrivalTime(int minutes) {
    final now = DateTime.now();
    final arrival = now.add(Duration(minutes: minutes));
    return '${arrival.hour}:${arrival.minute.toString().padLeft(2, '0')}';
  }
  
  // Set dark mode for Google Maps
  Future<void> _setMapStyle(GoogleMapController controller) async {
    const String lightMapStyle = '''
    [
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi",
        "stylers": [
          {
            "visibility": "simplified"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "transit",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      }
    ]
    ''';
    
    await controller.setMapStyle(lightMapStyle);
  }
} 