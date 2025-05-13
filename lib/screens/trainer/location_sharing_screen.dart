import 'package:flutter/material.dart';
import '../../models/session_model.dart';
import '../../services/location_service.dart';
import '../../services/calendly_service.dart';
import '../../theme/app_styles.dart';
import '../../theme/app_widgets.dart';
import '../../theme/app_animations.dart';
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

class _LocationSharingScreenState extends State<LocationSharingScreen> with SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final CalendlyService _calendlyService = CalendlyService();
  
  bool _isLoading = true;
  bool _isSharing = false;
  bool _hasLocationPermission = false;
  String? _errorMessage;
  
  // Animation controller for the toggle effect
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    
    // Set up animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _initialize();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      
      // Set animation state based on sharing status
      if (isSharing) {
        _animationController.value = 1.0;
      } else {
        _animationController.value = 0.0;
      }
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
        // Animate first, then stop sharing
        await _animationController.reverse();
        
        // Stop sharing
        await _locationService.stopSharingLocation();
        
        setState(() {
          _isSharing = false;
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location sharing stopped'),
              backgroundColor: AppStyles.backgroundCharcoal,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // Request permission first if needed
        if (!_hasLocationPermission) {
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
        
        // Then animate
        await _animationController.forward();
        
        setState(() {
          _isSharing = true;
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location sharing started'),
              backgroundColor: AppStyles.backgroundCharcoal,
              behavior: SnackBarBehavior.floating,
            ),
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
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: AppWidgets.circularProgressIndicator())
          : AppAnimations.fadeSlide(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildClientInfoCard(),
                    const SizedBox(height: 24),
                    _buildLocationSharingCard(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppStyles.statusDecoration(AppStyles.errorRed),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppStyles.errorRed),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppStyles.errorRed),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
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
    
    return AppWidgets.styledCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppStyles.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming Session',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppStyles.textWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(sessionTime),
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
          const SizedBox(height: 24),
          const Divider(color: AppStyles.dividerGrey, height: 1),
          const SizedBox(height: 24),
          _buildInfoRow(
            icon: Icons.person,
            title: 'Client',
            value: widget.session.clientName,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.access_time,
            title: 'Time',
            value: DateFormat('h:mm a').format(sessionTime),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getSessionTimeColor(difference),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                difference.isNegative 
                    ? 'Started ${-difference.inMinutes}m ago' 
                    : 'In $timeUntilSession',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.location_on,
            title: 'Location',
            value: widget.session.location,
          ),
          if (widget.session.notes != null && widget.session.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.notes,
              title: 'Notes',
              value: widget.session.notes!,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppStyles.surfaceCharcoal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppStyles.primaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
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
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
  
  Color _getSessionTimeColor(Duration difference) {
    if (difference.isNegative) {
      return AppStyles.errorRed;  // Session already started
    } else if (difference.inMinutes < 30) {
      return AppStyles.warningAmber;  // Starting soon
    } else {
      return AppStyles.successGreen;  // Plenty of time
    }
  }
  
  Widget _buildLocationSharingCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.surfaceCharcoal,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppStyles.cardShadow,
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final Color startColor = AppStyles.surfaceCharcoal;
              final Color endColor = _isSharing 
                  ? AppStyles.successGreen.withOpacity(0.15)
                  : AppStyles.surfaceCharcoal;
              
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Color.lerp(startColor, endColor, _animation.value),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: _isSharing 
                        ? AppStyles.successGreen.withOpacity(_animation.value * 0.3)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        _isSharing ? Icons.location_on : Icons.location_off,
                        key: ValueKey<bool>(_isSharing),
                        size: 28,
                        color: _isSharing ? AppStyles.successGreen : AppStyles.textGrey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location Sharing',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppStyles.textWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _isSharing ? 'Enabled' : 'Disabled',
                          style: TextStyle(
                            color: _isSharing ? AppStyles.successGreen : AppStyles.textGrey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isSharing ? AppStyles.successGreen : AppStyles.surfaceCharcoal,
                        borderRadius: BorderRadius.circular(16),
                        border: _isSharing 
                            ? null 
                            : Border.all(color: AppStyles.textGrey, width: 1),
                      ),
                      child: Text(
                        _isSharing ? 'ON' : 'OFF',
                        style: TextStyle(
                          color: _isSharing ? Colors.white : AppStyles.textGrey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSharing
                      ? 'Your location is currently being shared with your client. They can track your location on their app in real-time.'
                      : 'Enable location sharing to allow your client to track your location as you head to your session.',
                  style: TextStyle(
                    color: AppStyles.textWhite,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                if (!_hasLocationPermission) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppStyles.warningAmber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppStyles.warningAmber.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: AppStyles.warningAmber,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Location permission is required to share your location',
                            style: TextStyle(
                              color: AppStyles.warningAmber,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Share your location',
                            style: TextStyle(
                              color: AppStyles.textWhite,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Toggle to ${_isSharing ? 'disable' : 'enable'} location sharing',
                            style: TextStyle(
                              color: AppStyles.textGrey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      width: 60,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: Switch(
                          value: _isSharing,
                          onChanged: (_) => _toggleLocationSharing(),
                          activeColor: AppStyles.successGreen,
                          activeTrackColor: AppStyles.successGreen.withOpacity(0.3),
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _toggleLocationSharing,
                    icon: Icon(_isSharing ? Icons.location_off : Icons.location_on),
                    label: Text(_isSharing ? 'Stop Sharing' : 'Start Sharing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSharing ? AppStyles.errorRed : AppStyles.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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