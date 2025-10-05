import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/profile_image_service.dart';
import '../../services/payment_service.dart';
import '../../services/family_service.dart';
import '../../services/onboarding_service.dart';
import '../../models/user_model.dart';
import '../../models/goal_model.dart';
import '../../models/session_package_model.dart';
import '../../models/family_model.dart';
import '../../theme/app_styles.dart';
import 'client_payment_screen.dart';
import 'family_management_screen.dart';
import 'client_editable_onboarding_screen.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProfileImageService _profileImageService = ProfileImageService();
  final PaymentService _paymentService = PaymentService();
  final FamilyService _familyService = FamilyService();
  final OnboardingService _onboardingService = OnboardingService();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalController = TextEditingController();
  
  // Define a consistent style for text fields
  final _disabledTextStyle = const TextStyle(
    color: Colors.black87, // Use black text instead of grey
    fontSize: 16.0,
  );
  
  final _disabledDecoration = InputDecoration(
    filled: true,
    fillColor: Colors.white, // White background instead of grey
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.all(16.0),
    disabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
  );
  
  DateTime? _dateOfBirth;
  UserModel? _user;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  List<Goal> _goals = [];
  SessionPackage? _sessionPackage;
  Family? _family;
  List<FamilyInvitation> _pendingInvitations = [];
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    _goalController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = await _authService.getUserModel();
      
      // Get the most recent weight from weight history if available
      double? mostRecentWeight = user.weight;
      try {
        final weightHistoryDoc = await _firestore.collection('weightHistory')
            .where('userId', isEqualTo: user.uid)
            .orderBy('date', descending: true)
            .limit(1)
            .get();
        
        if (weightHistoryDoc.docs.isNotEmpty) {
          final mostRecentEntry = weightHistoryDoc.docs.first.data();
          mostRecentWeight = mostRecentEntry['weight'];
        }
      } catch (e) {
        print('Error loading weight history: $e');
        // Continue with the user's weight from their profile
      }
      
      // Convert height from cm to feet and inches
      int feet = 0;
      int inches = 0;
      if (user.height != null) {
        // 1 cm = 0.0328084 feet
        double totalFeet = user.height! * 0.0328084;
        feet = totalFeet.floor();
        inches = ((totalFeet - feet) * 12).round();
      }
      
      // Convert weight from kg to lbs
      double? weightLbs;
      if (mostRecentWeight != null) {
        // 1 kg = 2.20462 lbs
        weightLbs = mostRecentWeight * 2.20462;
      }
      
      if (mounted) {
        setState(() {
          _user = user;
          final fullName = user.displayName ?? '';
          final nameParts = fullName.split(' ');
          _firstNameController.text = nameParts.isNotEmpty ? nameParts.first : '';
          _lastNameController.text = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          _emailController.text = user.email;
          _phoneController.text = user.phoneNumber ?? '';
          _heightFeetController.text = feet > 0 ? feet.toString() : '';
          _heightInchesController.text = inches > 0 ? inches.toString() : '';
          _weightController.text = weightLbs != null ? weightLbs.toStringAsFixed(1) : '';
          _dateOfBirth = user.dateOfBirth;
          _goals = user.goals ?? [];
          _isLoading = false;
        });
      }
      
      // Load session package if user has a trainer
      if (user.trainerId != null) {
        _loadSessionPackage(user.uid, user.trainerId!);
      }
      
      // Load family data
      _loadFamilyData();
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadSessionPackage(String clientId, String trainerId) async {
    try {
      final package = await _paymentService.getSessionPackage(clientId, trainerId);
      if (mounted) {
        setState(() => _sessionPackage = package);
      }
    } catch (e) {
      print('Error loading session package: $e');
    }
  }

  Future<void> _loadFamilyData() async {
    try {
      // Load current family
      final family = await _familyService.getCurrentUserFamily();
      
      // Load pending invitations
      final invitations = await _familyService.getPendingInvitations();
      
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _family = family;
          _pendingInvitations = invitations;
        });
      }
    } catch (e) {
      print('Error loading family data: $e');
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _family = null;
          _pendingInvitations = [];
        });
      }
    }
  }

  // Stream for real-time session package updates
  Stream<SessionPackage?> _getSessionPackageStream(String clientId, String trainerId) {
    return FirebaseFirestore.instance
        .collection('sessionPackages')
        .where('clientId', isEqualTo: clientId)
        .where('trainerId', isEqualTo: trainerId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return SessionPackage.fromFirestore(snapshot.docs.first);
      }
      return null;
    });
  }
  
  void _navigateToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ClientPaymentScreen(),
      ),
    );
  }
  
    Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Dismiss keyboard before saving
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isSaving = true;
    });

    try {
      // Convert height from feet/inches to cm
      double? heightCm;
      if (_heightFeetController.text.isNotEmpty || _heightInchesController.text.isNotEmpty) {
        int feet = int.tryParse(_heightFeetController.text) ?? 0;
        int inches = int.tryParse(_heightInchesController.text) ?? 0;
        double totalInches = (feet * 12.0) + inches.toDouble();
        // 1 inch = 2.54 cm
        heightCm = totalInches * 2.54;
      }
      
      // Convert weight from lbs to kg
      double? weightKg;
      if (_weightController.text.isNotEmpty) {
        double? weightLbs = double.tryParse(_weightController.text);
        if (weightLbs != null) {
          // 1 lb = 0.453592 kg
          weightKg = weightLbs * 0.453592;
        }
      }
      
      // Update user profile
      await _authService.updateUserProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        height: heightCm,
        weight: weightKg,
        dateOfBirth: _dateOfBirth,
        goals: _goals,
        phoneNumber: _phoneController.text,
      );
      
      // Add to weight history if weight was changed
      if (weightKg != null && (_user!.weight == null || weightKg != _user!.weight)) {
        await _firestore.collection('weightHistory').add({
          'userId': _user!.uid,
          'weight': weightKg,
          'date': Timestamp.now(),
        });
      }
      
      // Reload user data
      await _loadUserData();
      
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      print('Error saving profile: $e');
      setState(() {
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    }
  }
  
  void _addGoal() {
    final goalText = _goalController.text.trim();
    if (goalText.isEmpty) return;
    
    // Dismiss keyboard before adding goal
    FocusScope.of(context).unfocus();
    
    setState(() {
      _goals.add(Goal(value: goalText));
      _goalController.clear();
    });
  }
  
  void _removeGoal(int index) {
    setState(() {
      _goals.removeAt(index);
    });
  }

  void _toggleGoalCompletion(int index) {
    if (index >= 0 && index < _goals.length) {
      setState(() {
        // Create a new goal with the opposite completed status
        _goals[index] = _goals[index].copyWith(completed: !_goals[index].completed);
      });
    }
  }
  
  Future<void> _selectDate() async {
    // Dismiss keyboard before showing date picker
    FocusScope.of(context).unfocus();
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (pickedDate != null) {
      setState(() {
        _dateOfBirth = pickedDate;
      });
    }
  }
  
  Future<void> _signOut() async {
    // Dismiss keyboard before signing out
    FocusScope.of(context).unfocus();
    
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      print('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  Future<void> _viewOnboardingInfo() async {
    if (_user == null) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: AppStyles.primarySage,
          ),
        ),
      );

      // Get onboarding form
      final onboardingForm = await _onboardingService.getClientOnboardingForm(_user!.uid);

      // Dismiss loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (onboardingForm != null) {
        if (mounted) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClientEditableOnboardingScreen(
                onboardingForm: onboardingForm,
                clientName: _user!.displayName ?? '${_user!.firstName} ${_user!.lastName}',
              ),
            ),
          );

          // Refresh data if changes were made
          if (result == true) {
            _loadUserData();
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No onboarding information found. Please contact your trainer.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Dismiss loading dialog if showing
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading onboarding information: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    bool isValidating = false;
    String? errorMessage;
    
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning, color: AppStyles.errorRed),
                  const SizedBox(width: 8),
                  const Text('Delete Account'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Are you sure you want to delete your account?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('This action will:'),
                  const SizedBox(height: 8),
                  const Text('• Permanently delete all your profile data'),
                  const Text('• Remove all your workout history'),
                  const Text('• Delete all your nutrition plans'),
                  const Text('• Cancel any active training sessions'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppStyles.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppStyles.errorRed.withOpacity(0.3)),
                    ),
                    child: const Text(
                      '⚠️ This action cannot be undone!',
                      style: TextStyle(
                        color: AppStyles.errorRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter your password to confirm deletion:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    enabled: !isValidating,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      errorText: errorMessage,
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: AppStyles.offWhite,
                    ),
                    onChanged: (value) {
                      if (errorMessage != null) {
                        setState(() {
                          errorMessage = null;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isValidating ? null : () {
                    FocusScope.of(context).unfocus();
                    Navigator.of(context).pop(false);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppStyles.slateGray),
                  ),
                ),
                ElevatedButton(
                  onPressed: isValidating ? null : () async {
                    if (passwordController.text.isEmpty) {
                      setState(() {
                        errorMessage = 'Password is required';
                      });
                      return;
                    }
                    
                    // Dismiss keyboard before processing
                    FocusScope.of(context).unfocus();
                    
                    setState(() {
                      isValidating = true;
                      errorMessage = null;
                    });
                    
                    try {
                      // Reauthenticate with password
                      await _authService.reauthenticateWithPassword(passwordController.text);
                      Navigator.of(context).pop(true);
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          isValidating = false;
                          errorMessage = e.toString().replaceFirst('Exception: ', '');
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyles.errorRed,
                    foregroundColor: AppStyles.textLight,
                  ),
                  child: isValidating 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Delete Account'),
                ),
              ],
            );
          },
        );
      },
    );

    // Dispose the controller after dialog is closed
    passwordController.dispose();

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Deleting account...'),
            ],
          ),
        ),
      );

      final user = await _authService.getUserModel();
      
      // Delete user data from Firestore
      await _authService.deleteUserAccount(user.uid);
      
      if (mounted) {
        // Dismiss loading dialog
        Navigator.pop(context);
        
        // Navigate to login and clear all routes
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        
        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: AppStyles.successGreen,
          ),
        );
      }
    } catch (e) {
      print('Error deleting account: $e');
      if (mounted) {
        // Dismiss loading dialog
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
    }
  }
  
  InputDecoration _getInputDecoration({
    required String label,
    required String hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      labelStyle: const TextStyle(
        fontSize: 14,
        color: AppStyles.textDark, // Use AppStyles instead of black87
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: AppStyles.offWhite, // Use AppStyles instead of white
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppStyles.slateGray.withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppStyles.primarySage, width: 2),
      ),
    );
  }

  // Family Management Methods
  Future<void> _createFamily() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isCreating = false;
    
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Create Family'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Family Name',
                    hintText: 'Enter a name for your family',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief description of your family',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isCreating ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isCreating ? null : () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a family name')),
                    );
                    return;
                  }
                  
                  setState(() => isCreating = true);
                  
                  try {
                    await _familyService.createFamily(
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim().isEmpty 
                          ? null 
                          : descriptionController.text.trim(),
                    );
                    Navigator.pop(context, true);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating family: $e')),
                    );
                  } finally {
                    setState(() => isCreating = false);
                  }
                },
                child: isCreating 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          ),
        ),
      );
      
      if (result == true) {
        await _loadFamilyData();
        await _loadUserData(); // Refresh user data to get family info
      }
    } finally {
      // Dispose controllers after all dialog operations are complete
      nameController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _leaveFamily() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Family'),
        content: Text('Are you sure you want to leave "${_family?.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _familyService.leaveFamily();
        await _loadFamilyData();
        await _loadUserData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Left family successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error leaving family: $e')),
          );
        }
      }
    }
  }

  Future<void> _acceptInvitation(FamilyInvitation invitation) async {
    try {
      await _familyService.acceptInvitation(invitation.id);
      await _loadFamilyData();
      await _loadUserData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined "${invitation.familyName}" successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting invitation: $e')),
        );
      }
    }
  }

  Future<void> _declineInvitation(FamilyInvitation invitation) async {
    try {
      await _familyService.declineInvitation(invitation.id);
      await _loadFamilyData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Declined invitation to "${invitation.familyName}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining invitation: $e')),
        );
      }
    }
    }

  Widget _buildFamilySection() {
    return Column(
      children: [
        // Family Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.family_restroom,
                          color: AppStyles.primarySage,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Family',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppStyles.textDark,
                          ),
                        ),
                      ],
                    ),
                    if (_user?.isFamilyOrganizer == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppStyles.primarySage.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'ORGANIZER',
                          style: TextStyle(
                            color: AppStyles.primarySage,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Family Content
                if (_family != null) ...[
                  // Family exists - show family info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _family!.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppStyles.primarySage,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_family!.activeMemberCount} member${_family!.activeMemberCount == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppStyles.slateGray,
                        ),
                      ),
                      if (_family!.description != null && _family!.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _family!.description!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppStyles.slateGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Family Members
                  FutureBuilder<List<UserModel>>(
                    future: _familyService.getFamilyMembers(_family!.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Text('Error loading members: ${snapshot.error}');
                      }
                      
                      final members = snapshot.data ?? [];
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Members',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppStyles.textDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...members.map((member) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppStyles.primarySage.withOpacity(0.1),
                                  child: Text(
                                    member.displayName?.substring(0, 1).toUpperCase() ?? 'U',
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
                                        member.displayName ?? '${member.firstName} ${member.lastName}',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (member.uid == _family!.organizerId) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Family Organizer',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppStyles.primarySage,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Family Actions
                  Row(
                    children: [
                      if (_user?.isFamilyOrganizer == true) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FamilyManagementScreen(
                                    familyId: _family!.id,
                                  ),
                                ),
                              ).then((_) {
                                // Refresh data when returning from family management
                                _loadFamilyData();
                                _loadUserData();
                              });
                            },
                            icon: const Icon(Icons.settings),
                            label: const Text('Manage Family'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppStyles.primarySage,
                              side: BorderSide(color: AppStyles.primarySage),
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _leaveFamily,
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('Leave Family'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppStyles.errorRed,
                              side: BorderSide(color: AppStyles.errorRed),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  // No family - show create or join options
                  Column(
                    children: [
                      // Pending Invitations
                      if (_pendingInvitations.isNotEmpty) ...[
                        ..._pendingInvitations.map((invitation) => Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppStyles.primarySage.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.family_restroom,
                                        color: AppStyles.primarySage,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Family Invitation',
                                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                              color: AppStyles.primarySage,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Join "${invitation.familyName}"',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppStyles.textDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppStyles.primarySage.withOpacity(0.1),
                                        child: Text(
                                          invitation.organizerName.substring(0, 1).toUpperCase(),
                                          style: TextStyle(
                                            color: AppStyles.primarySage,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'From: ${invitation.organizerName}',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppStyles.slateGray,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (invitation.message != null && invitation.message!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppStyles.primarySage.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppStyles.primarySage.withOpacity(0.1)),
                                    ),
                                    child: Text(
                                      invitation.message!,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppStyles.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _declineInvitation(invitation),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppStyles.slateGray,
                                        side: BorderSide(color: AppStyles.slateGray.withOpacity(0.5)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text('Decline'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: () => _acceptInvitation(invitation),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppStyles.primarySage,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                        const SizedBox(height: 20),
                      ],
                      
                      // Create Family Option
                      if (_user?.canCreateFamily == true) ...[
                        Icon(
                          Icons.family_restroom,
                          size: 48,
                          color: AppStyles.slateGray.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Create a Family',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppStyles.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a family to book sessions together and share the cost.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppStyles.slateGray,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _createFamily,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Family'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppStyles.primarySage,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.family_restroom,
                          size: 48,
                          color: AppStyles.slateGray.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Not in a Family',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppStyles.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You can join a family when someone invites you.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppStyles.slateGray,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
   
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppStyles.primarySage,
          ),
        ),
      );
    }
    
    final themeColor = AppStyles.primarySage;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.description_outlined),
          onPressed: _viewOnboardingInfo,
          tooltip: 'View Onboarding Info',
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
              tooltip: 'Sign Out',
            )
          else
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () => setState(() => _isEditing = false),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile image - now just using initials avatar
                Center(
                  child: _profileImageService.getProfileImage(
                    name: "${_firstNameController.text} ${_lastNameController.text}",
                    radius: 60,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Training Sessions Card (only show if user has a trainer)
                if (_user?.trainerId != null) ...[
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Simple Header
                          Row(
                            children: [
                              Icon(
                                Icons.fitness_center,
                                color: AppStyles.primarySage,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Training Sessions',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppStyles.textDark,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Clean Stats Row
                          // Real-time session package data
                          StreamBuilder<SessionPackage?>(
                            stream: _user?.trainerId != null 
                                ? _getSessionPackageStream(_user!.uid, _user!.trainerId!)
                                : null,
                            builder: (context, snapshot) {
                              final currentPackage = snapshot.data ?? _sessionPackage;
                              
                              return Row(
                                children: [
                                  // Sessions Left
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Sessions Remaining',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppStyles.slateGray,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${currentPackage?.sessionsRemaining ?? 0}',
                                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            color: AppStyles.primarySage,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Simple Divider
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: AppStyles.slateGray.withOpacity(0.2),
                                  ),
                                  
                                  const SizedBox(width: 16),
                                  
                                  // Package Cost
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Package Cost',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppStyles.slateGray,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          currentPackage != null 
                                              ? '\$${currentPackage.costPerTenSessions.toStringAsFixed(0)}'
                                              : '\$0',
                                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            color: AppStyles.primarySage,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Clean Payment Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _navigateToPayment,
                              icon: Icon(
                                Icons.payment,
                                size: 18,
                                color: AppStyles.primarySage,
                              ),
                              label: Text(
                                'Manage Payments',
                                style: TextStyle(
                                  color: AppStyles.primarySage,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppStyles.primarySage,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Family Section
                _buildFamilySection(),
                
                // Personal Information Section
                Text(
                  'Personal Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: themeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // First Name
                _isEditing 
                  ? TextFormField(
                      controller: _firstNameController,
                      decoration: _getInputDecoration(
                        label: 'First Name',
                        hint: '',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    )
                  : TextFormField(
                      controller: _firstNameController,
                      decoration: _getInputDecoration(
                        label: 'First Name',
                        hint: '',
                      ),
                      enabled: false,
                    ),
                const SizedBox(height: 16),
                
                // Last Name
                _isEditing 
                  ? TextFormField(
                      controller: _lastNameController,
                      decoration: _getInputDecoration(
                        label: 'Last Name',
                        hint: '',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name';
                        }
                        return null;
                      },
                    )
                  : TextFormField(
                      controller: _lastNameController,
                      decoration: _getInputDecoration(
                        label: 'Last Name',
                        hint: '',
                      ),
                      enabled: false,
                    ),
                const SizedBox(height: 16),
                
                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: _getInputDecoration(
                    label: 'Email',
                    hint: '',
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 16),
                
                // Phone Number
                _isEditing 
                  ? TextFormField(
                      controller: _phoneController,
                      decoration: _getInputDecoration(
                        label: 'Phone Number',
                        hint: '',
                      ),
                      keyboardType: TextInputType.phone,
                    )
                  : TextFormField(
                      controller: _phoneController,
                      decoration: _getInputDecoration(
                        label: 'Phone Number',
                        hint: '',
                      ),
                      enabled: false,
                    ),
                const SizedBox(height: 16),
                
                // Date of Birth
                _isEditing
                  ? InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: _getInputDecoration(
                          label: 'Date of Birth',
                          hint: '',
                        ),
                        child: Text(
                          _dateOfBirth != null
                            ? DateFormat('MM/dd/yyyy').format(_dateOfBirth!)
                            : 'Select Date',
                        ),
                      ),
                    )
                  : TextFormField(
                      decoration: _getInputDecoration(
                        label: 'Date of Birth',
                        hint: '',
                      ),
                      controller: TextEditingController(
                        text: _dateOfBirth != null
                            ? DateFormat('MM/dd/yyyy').format(_dateOfBirth!)
                            : 'Not specified'
                      ),
                      enabled: false,
                    ),
                const SizedBox(height: 24),
                
                // Fitness Information Section
                Text(
                  'Fitness Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: themeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Height (in feet and inches)
                if (_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _heightFeetController,
                          decoration: _getInputDecoration(
                            label: 'Height (feet)',
                            hint: '',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (int.tryParse(value) == null) {
                                return 'Enter a valid number';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _heightInchesController,
                          decoration: _getInputDecoration(
                            label: 'Inches',
                            hint: '',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              int? inches = int.tryParse(value);
                              if (inches == null) {
                                return 'Enter a valid number';
                              }
                              if (inches < 0 || inches >= 12) {
                                return 'Must be 0-11';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  )
                else
                  TextFormField(
                    decoration: _getInputDecoration(
                      label: 'Height',
                      hint: '',
                    ),
                    controller: TextEditingController(
                      text: _heightFeetController.text.isNotEmpty || _heightInchesController.text.isNotEmpty
                          ? '${_heightFeetController.text} ft ${_heightInchesController.text} in'
                          : 'Not specified'
                    ),
                    enabled: false,
                  ),
                const SizedBox(height: 16),
                
                // Weight (in pounds)
                _isEditing
                  ? TextFormField(
                      controller: _weightController,
                      decoration: _getInputDecoration(
                        label: 'Current Weight (lbs)',
                        hint: '',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                        }
                        return null;
                      },
                    )
                  : TextFormField(
                      decoration: _getInputDecoration(
                        label: 'Current Weight (lbs)',
                        hint: '',
                      ),
                      controller: TextEditingController(
                        text: _weightController.text.isEmpty ? 'Not specified' : '${_weightController.text} lbs'
                      ),
                      enabled: false,
                    ),
                const SizedBox(height: 24),
                
                // Fitness Goals Section
                Text(
                  'Fitness Goals',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: themeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Goals List in Card
                Card(
                  elevation: 2,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: _goals.isEmpty && !_isEditing
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          alignment: Alignment.center,
                          child: Text(
                            'No fitness goals added yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._goals.asMap().entries.map((entry) {
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                leading: Icon(Icons.fitness_center, color: themeColor, size: 20),
                                title: Text(
                                  entry.value.value,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: entry.value.completed ? AppStyles.slateGray : AppStyles.textDark,
                                    decoration: entry.value.completed ? TextDecoration.lineThrough : TextDecoration.none,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!_isEditing) 
                                      IconButton(
                                        icon: Icon(
                                          entry.value.completed ? Icons.check_circle : Icons.circle_outlined,
                                          color: entry.value.completed ? AppStyles.successGreen : AppStyles.slateGray,
                                          size: 20,
                                        ),
                                        onPressed: () => _toggleGoalCompletion(entry.key),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    if (_isEditing)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: AppStyles.errorRed, size: 20),
                                        onPressed: () => _removeGoal(entry.key),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                  ),
                ),
                
                // Add Goal Input
                if (_isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _goalController,
                            decoration: _getInputDecoration(
                              label: 'Add Goal',
                              hint: '',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add, color: themeColor),
                          onPressed: _addGoal,
                        ),
                      ],
                    ),
                  ),
                
                // Reduced spacing before logout section
                if (_isEditing)
                  const SizedBox(height: 32)
                else
                  const SizedBox(height: 16),
                
                // Save Button
                if (_isEditing)
                  Center(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                
                // Account Management Section
                if (!_isEditing) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _isEditing = true),
                          icon: const Icon(Icons.edit),
                          label: const Text("Edit Account"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppStyles.primarySage,
                            foregroundColor: AppStyles.textLight,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showDeleteAccountDialog,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text("Delete Account"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppStyles.errorRed,
                            foregroundColor: AppStyles.textLight,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 