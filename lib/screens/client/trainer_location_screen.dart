import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/session_model.dart';
import '../../services/location_service.dart';
import '../../theme/app_styles.dart';
import '../../theme/app_widgets.dart';
import '../../theme/app_animations.dart';

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
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppWidgets.circularProgressIndicator(
              color: AppStyles.primaryBlue,
              size: 50,
            ),
            const SizedBox(height: 24),
            AppAnimations.fadeIn(
              child: const Text(
                'Loading trainer location...',
                style: TextStyle(
                  color: AppStyles.textWhite,
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
                    color: AppStyles.surfaceCharcoal,
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
                    color: AppStyles.textWhite,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Trainers can share their location when heading to your session.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppStyles.textGrey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _checkTrainerSharing();
                  },
                  style: AppStyles.primaryButtonStyle,
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
            color: AppStyles.textWhite,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    
    return Stack(
      children: [
        // Darkened map style
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
          child: AppAnimations.fadeIn(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppStyles.backgroundCharcoal.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppStyles.primaryBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppWidgets.pulsatingDot(color: AppStyles.primaryBlue),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: AppStyles.textWhite,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Focus on trainer button (moved to top right)
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: AppStyles.backgroundCharcoal.withOpacity(0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _moveCamera,
              icon: const Icon(Icons.my_location),
              tooltip: 'Focus on trainer',
              color: AppStyles.primaryBlue,
              iconSize: 24,
              splashRadius: 24,
            ),
          ),
        ),
        
        // Location info panel with glass effect
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: AppAnimations.fadeSlide(
            beginOffset: const Offset(0, 0.3),
            child: Container(
              decoration: BoxDecoration(
                color: AppStyles.backgroundCharcoal.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppStyles.primaryBlue.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.darken,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: AppStyles.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.fitness_center,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Training Session',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: AppStyles.textWhite,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    widget.session.formattedDate,
                                    style: TextStyle(
                                      color: AppStyles.textGrey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _buildInfoItem(
                              icon: Icons.person,
                              label: 'Trainer',
                              value: widget.session.trainerName,
                            ),
                            _buildInfoItem(
                              icon: Icons.access_time,
                              label: 'Time',
                              value: widget.session.formattedTimeRange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppStyles.surfaceCharcoal.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 20,
                                color: AppStyles.textGrey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.session.location,
                                  style: const TextStyle(
                                    color: AppStyles.textWhite,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(
                          color: AppStyles.dividerGrey,
                          height: 1,
                          thickness: 1,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDistanceInfo(),
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: AppStyles.dividerGrey,
                            ),
                            Expanded(
                              child: _buildTimeInfo(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // Info item with icon, label and value
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppStyles.surfaceCharcoal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppStyles.primaryBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppStyles.textGrey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppStyles.textWhite,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
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
  Widget _buildDistanceInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.directions,
                size: 16,
                color: AppStyles.primaryBlue,
              ),
              const SizedBox(width: 6),
              Text(
                'Distance',
                style: TextStyle(
                  fontSize: 14,
                  color: AppStyles.textGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_distanceToTrainer != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_distanceToTrainer!.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _getDistanceColor(_distanceToTrainer!),
                  ),
                ),
                const Text(
                  ' miles',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppStyles.textWhite,
                  ),
                ),
              ],
            )
          else
            const Text(
              'Calculating...',
              style: TextStyle(
                fontSize: 16,
                color: AppStyles.textWhite,
              ),
            ),
        ],
      ),
    );
  }
  
  // Time info card
  Widget _buildTimeInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer,
                size: 16,
                color: AppStyles.softGold,
              ),
              const SizedBox(width: 6),
              Text(
                'Est. Arrival',
                style: TextStyle(
                  fontSize: 14,
                  color: AppStyles.textGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_travelTimeMinutes != null)
            Text(
              _formatArrivalTime(_travelTimeMinutes!),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppStyles.softGold,
              ),
            )
          else
            const Text(
              'Calculating...',
              style: TextStyle(
                fontSize: 16,
                color: AppStyles.textWhite,
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
    const String darkMapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#212121"
          }
        ]
      },
      {
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#212121"
          }
        ]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "administrative.country",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9e9e9e"
          }
        ]
      },
      {
        "featureType": "administrative.land_parcel",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "administrative.locality",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#bdbdbd"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#181818"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#616161"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#1b1b1b"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#2c2c2c"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#8a8a8a"
          }
        ]
      },
      {
        "featureType": "road.arterial",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#373737"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#3c3c3c"
          }
        ]
      },
      {
        "featureType": "road.highway.controlled_access",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#4e4e4e"
          }
        ]
      },
      {
        "featureType": "road.local",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#616161"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#000000"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#3d3d3d"
          }
        ]
      }
    ]
    ''';
    
    await controller.setMapStyle(darkMapStyle);
  }
} 