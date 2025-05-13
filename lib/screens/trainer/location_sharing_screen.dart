import 'package:flutter/material.dart';
import '../../models/session_model.dart';
import '../../services/location_service.dart';
import '../../services/calendly_service.dart';
import 'package:intl/intl.dart';

class LocationSharingScreen extends StatefulWidget {
  final TrainingSession session;
  
  const LocationSharingScreen({
    super.key,
    required this.session,
  });

  @override
  State<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends State<LocationSharingScreen> {
  final LocationService _locationService = LocationService();
  final CalendlyService _calendlyService = CalendlyService();
  
  bool _isLoading = true;
  bool _isSharing = false;
  bool _hasLocationPermission = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  
  Future<void> _initialize() async {
    try {
      // Check location permission
      final hasPermission = await _locationService.checkLocationPermission();
      
      // Check current sharing status
      final isSharing = await _locationService.isTrainerSharingLocation(widget.session.trainerId);
      
      setState(() {
        _hasLocationPermission = hasPermission;
        _isSharing = isSharing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _toggleLocationSharing() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (_isSharing) {
        // Stop sharing
        await _locationService.stopSharingLocation();
        
        setState(() {
          _isSharing = false;
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location sharing stopped')),
          );
        }
      } else {
        // Start sharing
        if (!_hasLocationPermission) {
          // Request permission first
          final hasPermission = await _locationService.checkLocationPermission();
          
          if (!hasPermission) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Location permission is required to share your location';
            });
            return;
          }
          
          _hasLocationPermission = true;
        }
        
        // Start sharing location
        await _locationService.startSharingLocation();
        
        setState(() {
          _isSharing = true;
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location sharing started')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Your Location'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClientInfoCard(),
                  const SizedBox(height: 24),
                  _buildLocationSharingCard(),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
  
  Widget _buildClientInfoCard() {
    final DateTime sessionTime = widget.session.startTime;
    final DateTime now = DateTime.now();
    final difference = sessionTime.difference(now);
    
    final String timeUntilSession = difference.inHours > 0
        ? '${difference.inHours}h ${difference.inMinutes.remainder(60)}m'
        : '${difference.inMinutes}m';
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Session',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.person, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Client: ${widget.session.clientName}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Time: ${DateFormat('h:mm a').format(sessionTime)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: difference.isNegative 
                        ? Colors.red 
                        : (difference.inMinutes < 30 ? Colors.orange : Colors.green),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    difference.isNegative 
                        ? 'Started ${-difference.inMinutes}m ago' 
                        : 'In $timeUntilSession',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Date: ${DateFormat('EEEE, MMMM d, yyyy').format(sessionTime)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location: ${widget.session.location}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationSharingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: _isSharing ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isSharing ? Icons.location_on : Icons.location_off,
                  size: 24,
                  color: _isSharing ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location Sharing',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isSharing ? Colors.green : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _isSharing ? 'ON' : 'OFF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSharing
                      ? 'Your location is being shared. Your client can track your location on their app.'
                      : 'Turn on location sharing to allow your client to track your location.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (!_hasLocationPermission) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.amber),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Location permission is required to share your location',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Toggle location sharing:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Switch(
                      value: _isSharing,
                      onChanged: (_) => _toggleLocationSharing(),
                      activeColor: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _toggleLocationSharing,
                    icon: Icon(_isSharing ? Icons.location_off : Icons.location_on),
                    label: Text(_isSharing ? 'Stop Sharing' : 'Start Sharing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSharing ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 