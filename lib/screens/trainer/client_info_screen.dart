import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/workout_template_service.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/profile_avatar.dart';
import '../../theme/app_styles.dart';
import 'client_onboarding_details_screen.dart';

class ClientInfoScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  const ClientInfoScreen({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ClientInfoScreen> createState() => _ClientInfoScreenState();
}

class _ClientInfoScreenState extends State<ClientInfoScreen> {
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final OnboardingService _onboardingService = OnboardingService();
  bool _isLoading = true;
  Map<String, dynamic>? _clientDetails;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadClientDetails();
  }

  Future<void> _loadClientDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final details = await _workoutService.getClientDetails(widget.clientId);
      setState(() {
        _clientDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading client details: $e';
        _isLoading = false;
      });
    }
  }

  String get _safeDisplayName {
    final dn = _clientDetails?['displayName'];
    if (dn is String) return dn;
    if (dn is Map && dn['firstName'] is String && dn['lastName'] is String) {
      return '${dn['firstName']} ${dn['lastName']}';
    }
    return widget.clientName;
  }

  String _safeString(dynamic value, {String fallback = 'Not provided'}) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is Map && value['firstName'] is String && value['lastName'] is String) {
      return '${value['firstName']} ${value['lastName']}';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.clientName}\'s Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClientDetails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadClientDetails,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile header
                      Center(
                        child: Column(
                          children: [
                            ProfileAvatar(
                              name: _safeDisplayName,
                              radius: 60,
                              fontSize: 30,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _safeDisplayName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            
                            // Onboarding Form Button
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _viewClientOnboardingForm(),
                              icon: const Icon(Icons.description),
                              label: const Text('View Onboarding Form'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppStyles.primarySage,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Contact Information
                      InfoSection(
                        title: 'Contact Information',
                        icon: Icons.contact_phone,
                        children: [
                          InfoItem(
                            icon: Icons.email,
                            label: 'Email',
                            value: _safeString(_clientDetails?['email']),
                          ),
                          InfoItem(
                            icon: Icons.phone,
                            label: 'Phone',
                            value: _safeString(_clientDetails?['phoneNumber']),
                          ),
                          if (_clientDetails?['dateOfBirth'] != null)
                            InfoItem(
                              icon: Icons.cake,
                              label: 'Date of Birth',
                              value: DateFormat('MM/dd/yyyy').format(
                                (_clientDetails!['dateOfBirth'] as Timestamp).toDate(),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Physical Information
                      InfoSection(
                        title: 'Physical Information',
                        icon: Icons.fitness_center,
                        children: [
                          if (_clientDetails?['heightImperial'] != null && _clientDetails?['height'] != null)
                            InfoItem(
                              icon: Icons.height,
                              label: 'Height',
                              value: '${_clientDetails!['heightImperial']['feet']} ft ${_clientDetails!['heightImperial']['inches']} in (${_clientDetails!['height'].toStringAsFixed(1)} cm)',
                            ),
                          if (_clientDetails?['weightLbs'] != null && _clientDetails?['mostRecentWeight'] != null)
                            InfoItem(
                              icon: Icons.monitor_weight,
                              label: 'Current Weight',
                              value: '${_clientDetails!['weightLbs']} lbs (${_clientDetails!['mostRecentWeight'].toStringAsFixed(1)} kg)',
                            ),
                          if (_clientDetails?['bmi'] != null)
                            InfoItem(
                              icon: Icons.insights,
                              label: 'BMI',
                              value: '${_clientDetails!['bmi']} (${_getBmiCategory(_clientDetails!['bmi'])})',
                              valueColor: _getBmiColor(_clientDetails!['bmi'], theme),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Fitness Goals
                      if (_clientDetails?['goals'] != null && 
                          (_clientDetails!['goals'] as List).isNotEmpty)
                        InfoSection(
                          title: 'Fitness Goals',
                          icon: Icons.flag,
                          children: [
                            for (final goal in _clientDetails!['goals'])
                              if (goal is Map && goal['value'] is String)
                                InfoItem(
                                  icon: Icons.check_circle_outline,
                                  value: goal['value'],
                                ),
                          ],
                        ),
                      
                      // No goals message
                      if (_clientDetails?['goals'] == null || 
                          (_clientDetails!['goals'] as List).isEmpty)
                        InfoSection(
                          title: 'Fitness Goals',
                          icon: Icons.flag,
                          children: [
                            InfoItem(
                              icon: Icons.info_outline,
                              value: 'No fitness goals set',
                              valueColor: Colors.grey,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
  
  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) {
      return 'Underweight';
    } else if (bmi < 25) {
      return 'Healthy';
    } else if (bmi < 30) {
      return 'Overweight';
    } else {
      return 'Obese';
    }
  }
  
  Color _getBmiColor(double bmi, ThemeData theme) {
    if (bmi < 18.5) {
      return Colors.blue;
    } else if (bmi < 25) {
      return Colors.green;
    } else if (bmi < 30) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  void _viewClientOnboardingForm() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Try to get onboarding form
      final onboardingForm = await _onboardingService.getClientOnboardingForm(widget.clientId);
      
      // Dismiss loading dialog
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (onboardingForm != null) {
        if (mounted) {
          // Navigate to onboarding details screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClientOnboardingDetailsScreen(
                onboardingForm: onboardingForm,
                clientName: _safeDisplayName,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No onboarding form found for this client.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Dismiss loading dialog if showing
      if (mounted) {
        Navigator.pop(context);
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading onboarding form: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const InfoSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class InfoItem extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String value;
  final Color? valueColor;

  const InfoItem({
    super.key,
    required this.icon,
    this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: label != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: valueColor,
                        ),
                      ),
                    ],
                  )
                : Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: valueColor,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
} 