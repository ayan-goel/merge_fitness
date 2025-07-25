import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/workout_template_service.dart';
import '../../services/onboarding_service.dart';
import '../../services/auth_service.dart';
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
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _clientDetails;
  String? _errorMessage;
  bool _isSuperTrainer = false;
  List<String> _currentTrainerNames = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _checkUserRole();
    await _loadClientDetails();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = await _authService.getUserModel();
      setState(() {
        _isSuperTrainer = user.isSuperTrainer;
      });
    } catch (e) {
      print('Error checking user role: $e');
    }
  }

  Future<void> _loadClientDetails() async {
    print('=== LOADING CLIENT DETAILS ===');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('Getting client details for ID: ${widget.clientId}');
      final details = await _workoutService.getClientDetails(widget.clientId);
      print('Client details loaded. Keys: ${details.keys.toList()}');
      print('Client trainerId: ${details['trainerId']}');
      print('Client trainerIds: ${details['trainerIds']}');
      
      // Get current trainer names if assigned
      List<String> trainerNames = [];
      final trainerIds = _getTrainerIdsFromDetails(details);
      
      for (final trainerId in trainerIds) {
        final trainerName = await _getTrainerName(trainerId);
        trainerNames.add(trainerName);
      }
      
      setState(() {
        _clientDetails = details;
        _currentTrainerNames = trainerNames;
        _isLoading = false;
      });
      
      print('Client details state updated. _currentTrainerNames: $_currentTrainerNames');
      print('=== CLIENT DETAILS LOADED ===');
    } catch (e) {
      print('Error in _loadClientDetails: $e');
      setState(() {
        _errorMessage = 'Error loading client details: $e';
        _isLoading = false;
      });
    }
  }

  Future<String> _getTrainerName(String trainerId) async {
    try {
      print('_getTrainerName called with trainerId: $trainerId');
      final doc = await FirebaseFirestore.instance.collection('users').doc(trainerId).get();
      if (doc.exists) {
        final data = doc.data()!;
        print('Trainer document found. Data keys: ${data.keys.toList()}');
        print('Trainer displayName: ${data['displayName']}');
        print('Trainer firstName: ${data['firstName']}');
        print('Trainer lastName: ${data['lastName']}');
        print('Trainer email: ${data['email']}');
        
        final displayName = data['displayName'] ?? 
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final result = displayName.isNotEmpty ? displayName : data['email'] ?? 'Unknown Trainer';
        print('_getTrainerName returning: $result');
        return result;
      }
      print('Trainer document not found for ID: $trainerId');
      return 'Unknown Trainer';
    } catch (e) {
      print('Error in _getTrainerName: $e');
      return 'Unknown Trainer';
    }
  }

  Future<void> _showReassignTrainerDialog() async {
    try {
      // Get all available trainers
      List<Map<String, dynamic>> trainers = [];
      
      // Get both regular trainers and super trainers
      final trainerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'trainer')
          .get();
          
      final superTrainerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'superTrainer')
          .get();
      
      for (final doc in [...trainerQuery.docs, ...superTrainerQuery.docs]) {
        final data = doc.data();
        final displayName = data['displayName'] ?? 
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final name = displayName.isNotEmpty ? displayName : data['email'] ?? 'Unknown';
        
        trainers.add({
          'id': doc.id,
          'name': name,
          'email': data['email'] ?? '',
          'role': data['role'] ?? 'trainer',
        });
      }
      
      if (trainers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No trainers available for assignment'),
              backgroundColor: AppStyles.errorRed,
            ),
          );
        }
        return;
      }
      
      // Get current trainer assignments
      final currentTrainerIds = _getCurrentTrainerIds();
      
      // Show multi-selection dialog
      // Initialize with current trainers
      List<Map<String, dynamic>> selectedTrainers = trainers
          .where((trainer) => currentTrainerIds.contains(trainer['id']))
          .toList();
      
      final result = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              
              return AlertDialog(
                title: const Text('Reassign Trainers'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select trainers for ${widget.clientName}:',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Column(
                          children: trainers.map((trainer) {
                            final isSelected = selectedTrainers.any((t) => t['id'] == trainer['id']);
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      selectedTrainers.removeWhere((t) => t['id'] == trainer['id']);
                                    } else {
                                      selectedTrainers.add(trainer);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected 
                                          ? AppStyles.primarySage 
                                          : AppStyles.primarySage.withOpacity(0.2),
                                    ),
                                    color: isSelected 
                                        ? AppStyles.primarySage.withOpacity(0.1) 
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppStyles.primarySage.withOpacity(0.2),
                                        child: Text(
                                          trainer['name'].isNotEmpty ? trainer['name'][0].toUpperCase() : 'T',
                                          style: TextStyle(
                                            color: AppStyles.primarySage,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              trainer['name'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              trainer['role'] == 'superTrainer' ? 'Super Trainer' : 'Trainer',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppStyles.primarySage,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            if (value == true) {
                                              selectedTrainers.add(trainer);
                                            } else {
                                              selectedTrainers.removeWhere((t) => t['id'] == trainer['id']);
                                            }
                                          });
                                        },
                                        activeColor: AppStyles.primarySage,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    if (selectedTrainers.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Selected: ${selectedTrainers.map((t) => t['name']).join(', ')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.primarySage,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppStyles.slateGray),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: selectedTrainers.isNotEmpty 
                        ? () => Navigator.of(context).pop(selectedTrainers)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStyles.primarySage,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Assign (${selectedTrainers.length})'),
                  ),
                ],
              );
            },
          );
        },
      );
      
      if (result != null) {
        await _reassignTrainers(result);
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading trainers: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
    }
  }

  /// Get trainer IDs from client details
  List<String> _getTrainerIdsFromDetails(Map<String, dynamic> details) {
    // Check for new format first (trainerIds array)
    if (details['trainerIds'] is List) {
      return List<String>.from(details['trainerIds']);
    }
    
    // Fall back to legacy format (single trainerId)
    final trainerId = details['trainerId'];
    if (trainerId is String) {
      return [trainerId];
    }
    
    return [];
  }

  /// Get current trainer IDs for the client
  List<String> _getCurrentTrainerIds() {
    if (_clientDetails == null) return [];
    return _getTrainerIdsFromDetails(_clientDetails!);
  }

  Future<void> _reassignTrainers(List<Map<String, dynamic>> newTrainers) async {
    try {
      print('=== REASSIGN TRAINERS DEBUG ===');
      print('Client ID: ${widget.clientId}');
      print('Client Name: ${widget.clientName}');
      print('New Trainers: ${newTrainers.map((t) => '${t['id']} (${t['name']})').join(', ')}');
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final trainerIds = newTrainers.map((trainer) => trainer['id'] as String).toList();
      
      // Update the client's assigned trainers
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .update({
            'trainerIds': trainerIds,
            'trainerId': trainerIds.isNotEmpty ? trainerIds.first : null, // Keep legacy field for backwards compatibility
          });
      
      print('Firestore update completed successfully');
      
      // Dismiss loading dialog
      if (mounted) {
        Navigator.pop(context);
      }
      
      // Reload client details to reflect changes
      print('Reloading client details...');
      await _loadClientDetails();
      
      if (mounted) {
        final trainerNames = newTrainers.map((trainer) => trainer['name']).join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.clientName} has been reassigned to: $trainerNames'),
            backgroundColor: AppStyles.successGreen,
          ),
        );
      }
      
      print('=== REASSIGN TRAINERS DEBUG END ===');
    } catch (e) {
      print('ERROR in _reassignTrainers: $e');
      print('Stack trace: ${StackTrace.current}');
      
      // Dismiss loading dialog if showing
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reassigning trainers: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
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
                            
                            // Action Buttons
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _viewClientOnboardingForm(),
                                  icon: const Icon(Icons.description),
                                  label: const Text('View Form'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppStyles.primarySage,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                if (_isSuperTrainer) ...[
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: _showReassignTrainerDialog,
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Reassign'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppStyles.mutedBlue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Assigned Trainers Section (only show for super trainers)
                      if (_isSuperTrainer)
                        InfoSection(
                          title: 'Assigned Trainers',
                          icon: Icons.person_pin,
                          children: [
                            if (_currentTrainerNames.isEmpty)
                              InfoItem(
                                icon: Icons.warning,
                                value: 'No trainers assigned',
                                valueColor: Colors.orange[700],
                              )
                            else
                              for (int i = 0; i < _currentTrainerNames.length; i++)
                                InfoItem(
                                  icon: Icons.check_circle,
                                  value: _currentTrainerNames[i],
                                  label: _currentTrainerNames.length > 1 ? 'Trainer ${i + 1}' : null,
                                ),
                          ],
                        ),
                      
                      if (_isSuperTrainer)
                        const SizedBox(height: 24),
                      
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