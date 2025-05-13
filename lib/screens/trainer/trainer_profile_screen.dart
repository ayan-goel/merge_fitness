import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/profile_image_service.dart';
import '../../services/calendly_service.dart';
import '../../models/user_model.dart';

class TrainerProfileScreen extends StatefulWidget {
  const TrainerProfileScreen({super.key});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> {
  final AuthService _authService = AuthService();
  final CalendlyService _calendlyService = CalendlyService();
  final ProfileImageService _profileImageService = ProfileImageService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
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
  
  @override
  void initState() {
    super.initState();
    _loadTrainerData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
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
      if (calendlyUrl != null) {
        _calendlyUrl = calendlyUrl;
        isConnected = true;
        
        // Load event types if connected
        if (isConnected) {
          try {
            final eventTypes = await _calendlyService.getTrainerEventTypes(trainer.uid);
            _eventTypes = eventTypes;
            
            // Get selected event type
            final doc = await FirebaseFirestore.instance.collection('users').doc(trainer.uid).get();
            final data = doc.data();
            _selectedEventType = data?['selectedCalendlyEventType'] as String?;
            
            // Find the matching event type name
            if (_selectedEventType != null) {
              final selectedEvent = _eventTypes.firstWhere(
                (event) => event['uri'] == _selectedEventType,
                orElse: () => {'name': 'Unknown Event Type'},
              );
              _selectedEventTypeName = selectedEvent['name'];
            }
          } catch (e) {
            print('Error loading event types: $e');
          }
        }
      }
      
      setState(() {
        _trainer = trainer;
        _nameController.text = trainer.displayName ?? '';
        _emailController.text = trainer.email;
        _phoneController.text = trainer.phoneNumber ?? '';
        _isCalendlyConnected = isConnected;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading trainer data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Update user profile
      await _authService.updateUserProfile(
        displayName: _nameController.text,
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
    setState(() {
      _isConnecting = true;
    });
    
    try {
      final token = await _calendlyService.connectCalendlyAccount();
      
      // After connecting, load event types to let the user select one
      await _loadTrainerData();
      
      if (mounted && _eventTypes.isNotEmpty) {
        // Show dialog to select event type
        await _showEventTypeSelectionDialog();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calendly connected successfully')),
        );
      }
    } catch (e) {
      print('Error connecting Calendly: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting Calendly: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
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
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
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
      
      // Reload trainer data to update UI
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
    // Filter to only show active event types
    final activeEventTypes = _eventTypes.where((type) => type['active'] == true).toList();
    
    if (activeEventTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active event types found. Please activate at least one event type in your Calendly account.')),
      );
      return;
    }
    
    // Show dialog to select event type
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                  Navigator.of(context).pop();
                  
                  // Save selected event type
                  try {
                    await _calendlyService.selectCalendlyEventType(eventType['uri']);
                    
                    // Reload trainer data
                    await _loadTrainerData();
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selected ${eventType['name']} as default session type')),
                      );
                    }
                  } catch (e) {
                    print('Error selecting event type: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  // Sign out method
  Future<void> _signOut() async {
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
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final themeColor = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainer Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
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
                    name: _nameController.text,
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
                
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  enabled: _isEditing,
                  validator: (value) {
                    if (_isEditing && (value == null || value.isEmpty)) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  enabled: false, // Email can't be changed through this screen
                ),
                const SizedBox(height: 16),
                
                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  enabled: _isEditing,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                
                // Calendly Integration Section
                Text(
                  'Calendly Integration',
                  style: Theme.of(context).textTheme.titleLarge,
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Flexible(
                                child: OutlinedButton.icon(
                                  onPressed: _showEventTypeSelectionDialog,
                                  icon: const Icon(Icons.event),
                                  label: const Text('Change Event Type'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: OutlinedButton.icon(
                                  onPressed: _isDisconnecting ? null : _disconnectCalendly,
                                  icon: const Icon(Icons.link_off),
                                  label: _isDisconnecting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Disconnect'),
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
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Save Button
                if (_isEditing)
                  Center(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator()
                          : const Text('Save Changes'),
                    ),
                  ),
                
                // Logout Section
                if (!_isEditing) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                    ),
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