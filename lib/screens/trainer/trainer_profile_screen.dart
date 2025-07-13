import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/profile_image_service.dart';
import '../../services/calendly_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_styles.dart';

class TrainerProfileScreen extends StatefulWidget {
  const TrainerProfileScreen({super.key});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final CalendlyService _calendlyService = CalendlyService();
  final ProfileImageService _profileImageService = ProfileImageService();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  UserModel? _trainer;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isCalendlyConnected = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;
  String? _calendlyUrl;
  List<Map<String, dynamic>> _eventTypes = [];
  String? _selectedEventType;
  String? _selectedEventTypeName;
  bool _hasShownEventTypeDialog = false;
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTrainerData();
    _setupFirestoreListener();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userDataSubscription?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload data when app comes back from background (after OAuth flow)
    if (state == AppLifecycleState.resumed) {
      print('TrainerProfileScreen: App resumed, reloading data...');
      _loadTrainerData();
    }
  }
  
  void _setupFirestoreListener() async {
    try {
      final user = await _authService.getUserModel();
      _userDataSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (mounted && snapshot.exists) {
          final data = snapshot.data();
          final isConnected = data?['calendlyConnected'] == true;
          final hasToken = data?['calendlyToken'] != null;
          
          print('TrainerProfileScreen: Firestore listener - connected: $isConnected, hasToken: $hasToken');
          
          // If Calendly just got connected and we haven't shown the dialog yet
          if (isConnected && hasToken && !_hasShownEventTypeDialog && !_isCalendlyConnected) {
            print('TrainerProfileScreen: Calendly just connected, refreshing data...');
            _loadTrainerData();
          }
        }
      });
    } catch (e) {
      print('Error setting up Firestore listener: $e');
    }
  }
  
  Future<void> _loadTrainerData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load trainer profile
      final trainer = await _authService.getUserModel();
      
      // Load Calendly URL and connection status
      final calendlyUrl = await _calendlyService.getTrainerCalendlyUrl(trainer.uid);
      
      bool isConnected = false;
      _calendlyUrl = calendlyUrl;
      
      // Check if trainer has a Calendly token (more reliable than just URL)
      final doc = await FirebaseFirestore.instance.collection('users').doc(trainer.uid).get();
      final userData = doc.data();
      final hasToken = userData?['calendlyToken'] != null;
      final calendlyConnectedFlag = userData?['calendlyConnected'] == true;
      
      print('TrainerProfileScreen: _loadTrainerData - calendlyUrl: $calendlyUrl');
      print('TrainerProfileScreen: _loadTrainerData - hasToken: $hasToken');
      print('TrainerProfileScreen: _loadTrainerData - calendlyConnectedFlag: $calendlyConnectedFlag');
      
      if (hasToken && calendlyConnectedFlag) {
        isConnected = true;
        
        // Load event types if connected
        if (isConnected) {
          try {
            print('TrainerProfileScreen: _loadTrainerData - Loading event types for connected trainer...');
            final eventTypes = await _calendlyService.getTrainerEventTypes(trainer.uid);
            _eventTypes = eventTypes;
            print('TrainerProfileScreen: _loadTrainerData - Loaded ${_eventTypes.length} event types');
            
            // Get selected event type
            _selectedEventType = userData?['selectedCalendlyEventType'] as String?;
            print('TrainerProfileScreen: _loadTrainerData - Selected event type: $_selectedEventType');
            
            // Find the matching event type name
            if (_selectedEventType != null) {
              final selectedEvent = _eventTypes.firstWhere(
                (event) => event['uri'] == _selectedEventType,
                orElse: () => {'name': 'Unknown Event Type'},
              );
              _selectedEventTypeName = selectedEvent['name'];
              print('TrainerProfileScreen: _loadTrainerData - Selected event type name: $_selectedEventTypeName');
            }
          } catch (e) {
            print('Error loading event types: $e');
            // If token expired, mark as disconnected
            if (e.toString().contains('token has expired') || e.toString().contains('Unauthenticated')) {
              isConnected = false;
              _calendlyUrl = null;
              _eventTypes = [];
              _selectedEventType = null;
              _selectedEventTypeName = null;
            }
          }
        }
      }
      
      setState(() {
        _trainer = trainer;
        final fullName = trainer.displayName ?? '';
        final nameParts = fullName.split(' ');
        _firstNameController.text = nameParts.isNotEmpty ? nameParts.first : '';
        _lastNameController.text = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        _emailController.text = trainer.email;
        _phoneController.text = trainer.phoneNumber ?? '';
        _isCalendlyConnected = isConnected;
        _isLoading = false;
      });
      
      // If connected but no event type selected, show selection dialog
      if (isConnected && _eventTypes.isNotEmpty && _selectedEventType == null && !_hasShownEventTypeDialog) {
        print('TrainerProfileScreen: _loadTrainerData - Connected but no event type selected, showing dialog...');
        _hasShownEventTypeDialog = true;
        // Use a slight delay to ensure the UI is fully built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showEventTypeSelectionDialog();
          }
        });
      }
    } catch (e) {
      print('Error loading trainer data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
    Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Dismiss keyboard before saving
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isSaving = true;
    });

    try {
      // Update user profile
      await _authService.updateUserProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phoneNumber: _phoneController.text,
      );
      
      // Reload trainer data
      await _loadTrainerData();
      
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      print('Error saving profile: $e');
      setState(() {
        _isSaving = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    }
  }
  
  Future<void> _connectCalendly() async {
    if (!mounted) return;
    
    setState(() {
      _isConnecting = true;
    });
    
    try {
      print('TrainerProfileScreen: Starting Calendly connection...');
      print('TrainerProfileScreen: Current connection status: $_isCalendlyConnected');
      print('TrainerProfileScreen: Current event types count: ${_eventTypes.length}');
      print('TrainerProfileScreen: Current selected event type: $_selectedEventType');
      
      // If already connected and has event types but no selection, just show the dialog
      if (_isCalendlyConnected && _eventTypes.isNotEmpty && _selectedEventType == null) {
        print('TrainerProfileScreen: Already connected, showing event type selection...');
        if (mounted) {
          await _showEventTypeSelectionDialog();
        }
        return;
      }
      
      final token = await _calendlyService.connectCalendlyAccount();
      
      if (!mounted) {
        print('TrainerProfileScreen: Widget not mounted after OAuth, but connection may have succeeded');
        print('TrainerProfileScreen: The app will reload data when it resumes');
        return;
      }
      
      print('TrainerProfileScreen: Token received: ${token != null ? 'Yes' : 'No'}');
      print('TrainerProfileScreen: About to process token...');
      
      if (token != null) {
        print('TrainerProfileScreen: Processing token...');
        try {
          // After connecting, load event types to let the user select one
          print('TrainerProfileScreen: Loading trainer data...');
          await _loadTrainerData();
          
          print('TrainerProfileScreen: Event types loaded: ${_eventTypes.length} types');
          print('TrainerProfileScreen: Event types: $_eventTypes');
          print('TrainerProfileScreen: Widget mounted: $mounted');
          print('TrainerProfileScreen: _isCalendlyConnected: $_isCalendlyConnected');
          
          if (mounted && _eventTypes.isNotEmpty) {
            // Show dialog to select event type
            print('TrainerProfileScreen: Showing event type selection dialog...');
            await _showEventTypeSelectionDialog();
            print('TrainerProfileScreen: Event type selection dialog completed');
          } else {
            print('TrainerProfileScreen: Not showing dialog - mounted: $mounted, eventTypes: ${_eventTypes.length}');
          }
          
          if (mounted) {
            print('TrainerProfileScreen: Showing success message');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Calendly connected successfully')),
            );
          }
        } catch (e) {
          print('TrainerProfileScreen: Error processing token: $e');
          print('TrainerProfileScreen: Error stack: ${StackTrace.current}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error processing Calendly connection: $e')),
            );
          }
        }
      } else {
        print('TrainerProfileScreen: No token received');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to connect Calendly - no token received')),
          );
        }
      }
    } catch (e) {
      print('Error connecting Calendly: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting Calendly: $e')),
        );
      }
    } finally {
      print('TrainerProfileScreen: In finally block, mounted: $mounted');
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
        print('TrainerProfileScreen: Set _isConnecting = false');
      }
    }
  }
  
  Future<void> _disconnectCalendly() async {
    // Show confirmation dialog
    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Calendly'),
        content: const Text('Are you sure you want to disconnect your Calendly account? Clients will no longer be able to schedule sessions with you.'),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop(false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop(true);
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!shouldDisconnect) return;
    
    setState(() {
      _isDisconnecting = true;
    });
    
    try {
      await _calendlyService.disconnectCalendlyAccount();
      
      // Reset dialog flag and reload trainer data to update UI
      _hasShownEventTypeDialog = false;
      await _loadTrainerData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calendly disconnected successfully')),
        );
      }
    } catch (e) {
      print('Error disconnecting Calendly: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error disconnecting Calendly: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDisconnecting = false;
        });
      }
    }
  }
  
  Future<void> _showEventTypeSelectionDialog() async {
    print('TrainerProfileScreen: _showEventTypeSelectionDialog - Starting...');
    
    // Store a local context reference to avoid using potentially deactivated context
    final BuildContext localContext = context;
    
    // Filter to only show active event types
    final activeEventTypes = _eventTypes.where((type) => type['active'] == true).toList();
    print('TrainerProfileScreen: _showEventTypeSelectionDialog - Active event types: ${activeEventTypes.length}');
    
    if (activeEventTypes.isEmpty) {
      print('TrainerProfileScreen: _showEventTypeSelectionDialog - No active event types found');
      if (mounted) {
        ScaffoldMessenger.of(localContext).showSnackBar(
          const SnackBar(content: Text('No active event types found. Please activate at least one event type in your Calendly account.')),
        );
      }
      return;
    }
    
    // Check if widget is still mounted before showing dialog
    if (!mounted) {
      print('TrainerProfileScreen: _showEventTypeSelectionDialog - Widget not mounted, returning');
      return;
    }
    
    print('TrainerProfileScreen: _showEventTypeSelectionDialog - About to show dialog...');
    
    // Show dialog to select event type
    await showDialog(
      context: localContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Session Type'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: activeEventTypes.length,
            itemBuilder: (context, index) {
              final eventType = activeEventTypes[index];
              return ListTile(
                title: Text(eventType['name']),
                subtitle: Text('${eventType['duration']} minutes'),
                onTap: () async {
                  FocusScope.of(dialogContext).unfocus();
                  Navigator.of(dialogContext).pop();
                  
                  // Save selected event type
                  try {
                    await _calendlyService.selectCalendlyEventType(eventType['uri']);
                    
                    // Reload trainer data
                    await _loadTrainerData();
                    
                    if (mounted) {
                      ScaffoldMessenger.of(localContext).showSnackBar(
                        SnackBar(content: Text('Selected ${eventType['name']} as default session type')),
                      );
                    }
                  } catch (e) {
                    print('Error selecting event type: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(localContext).showSnackBar(
                        SnackBar(content: Text('Error selecting event type: $e')),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(dialogContext).unfocus();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  // Sign out method
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
                    'Are you sure you want to delete your trainer account?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('This action will:'),
                  const SizedBox(height: 8),
                  const Text('• Permanently delete all your profile data'),
                  const Text('• Remove all client assignments'),
                  const Text('• Delete all workout templates you created'),
                  const Text('• Disconnect your Calendly integration'),
                  const Text('• Cancel all scheduled training sessions'),
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
                    textInputAction: TextInputAction.done,
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
  
  // Add input decoration method to match client profile screen
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
        color: AppStyles.textDark,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: AppStyles.offWhite,
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
        title: const Text('Trainer Profile'),
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
                    name: _firstNameController.text + ' ' + _lastNameController.text,
                    radius: 60,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 24),
                
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
                TextFormField(
                  controller: _firstNameController,
                  decoration: _getInputDecoration(
                    label: 'First Name',
                    hint: '',
                    prefixIcon: Icons.person,
                  ),
                  enabled: _isEditing,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (_isEditing && (value == null || value.isEmpty)) {
                      return 'Please enter your first name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  decoration: _getInputDecoration(
                    label: 'Last Name',
                    hint: '',
                    prefixIcon: Icons.person,
                  ),
                  enabled: _isEditing,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (_isEditing && (value == null || value.isEmpty)) {
                      return 'Please enter your last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: _getInputDecoration(
                    label: 'Email',
                    hint: '',
                    prefixIcon: Icons.email,
                  ),
                  enabled: false, // Email can't be changed through this screen
                ),
                const SizedBox(height: 16),
                
                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  decoration: _getInputDecoration(
                    label: 'Phone Number',
                    hint: '',
                    prefixIcon: Icons.phone,
                  ),
                  enabled: _isEditing,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 24),
                
                // Calendly Integration Section
                Text(
                  'Calendly Integration',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: themeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Scheduling',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Connect your Calendly account to allow clients to schedule training sessions with you.',
                        ),
                        const SizedBox(height: 16),
                        
                        if (_isCalendlyConnected) ...[
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Calendly Connected'),
                                    if (_calendlyUrl != null)
                                      Text(
                                        _calendlyUrl!,
                                        style: Theme.of(context).textTheme.bodySmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          if (_selectedEventType != null) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.event, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Selected Event Type'),
                                      Text(
                                        _selectedEventTypeName ?? 'Unknown Event Type',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _showEventTypeSelectionDialog,
                                icon: const Icon(Icons.event),
                                label: const Text('Change Event Type'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _isDisconnecting ? null : _disconnectCalendly,
                                icon: const Icon(Icons.link_off),
                                label: _isDisconnecting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Disconnect'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppStyles.errorRed,
                                  foregroundColor: AppStyles.textLight,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const Text(
                            'You need to connect your Calendly account to allow clients to schedule sessions with you.',
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _isConnecting ? null : _connectCalendly,
                              icon: const Icon(Icons.link),
                              label: _isConnecting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Connect Calendly'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                minimumSize: const Size(200, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Save Button
                if (_isEditing)
                  Center(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                  const SizedBox(height: 16),
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