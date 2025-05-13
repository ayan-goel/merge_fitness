import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/profile_image_service.dart';
import '../../models/user_model.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProfileImageService _profileImageService = ProfileImageService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
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
  List<String> _goals = [];
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
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
      
      setState(() {
        _user = user;
        _nameController.text = user.displayName ?? '';
        _emailController.text = user.email;
        _phoneController.text = user.phoneNumber ?? '';
        _heightFeetController.text = feet > 0 ? feet.toString() : '';
        _heightInchesController.text = inches > 0 ? inches.toString() : '';
        _weightController.text = weightLbs != null ? weightLbs.toStringAsFixed(1) : '';
        _dateOfBirth = user.dateOfBirth;
        _goals = user.goals ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
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
        displayName: _nameController.text,
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
    final goal = _goalController.text.trim();
    if (goal.isEmpty) return;
    
    setState(() {
      _goals.add(goal);
      _goalController.clear();
    });
  }
  
  void _removeGoal(int index) {
    setState(() {
      _goals.removeAt(index);
    });
  }
  
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
        title: const Text('My Profile'),
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
                _isEditing 
                  ? TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Full Name',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.person, color: themeColor),
                              const SizedBox(width: 10),
                              Text(
                                _nameController.text.isEmpty ? 'Not specified' : _nameController.text,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                        ],
                      ),
                    ),
                const SizedBox(height: 16),
                
                // Email
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.email, color: themeColor),
                          const SizedBox(width: 10),
                          Text(
                            _emailController.text,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Phone Number
                _isEditing 
                  ? TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phone Number',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.phone, color: themeColor),
                              const SizedBox(width: 10),
                              Text(
                                _phoneController.text.isEmpty ? 'Not specified' : _phoneController.text,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                        ],
                      ),
                    ),
                const SizedBox(height: 16),
                
                // Date of Birth
                _isEditing
                  ? GestureDetector(
                      onTap: () async {
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
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _dateOfBirth != null
                              ? DateFormat('MM/dd/yyyy').format(_dateOfBirth!)
                              : 'Not specified',
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date of Birth',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: themeColor),
                              const SizedBox(width: 10),
                              Text(
                                _dateOfBirth != null
                                  ? DateFormat('MM/dd/yyyy').format(_dateOfBirth!)
                                  : 'Not specified',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                        ],
                      ),
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
                          decoration: const InputDecoration(
                            labelText: 'Height (feet)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.height),
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
                          decoration: const InputDecoration(
                            labelText: 'Inches',
                            border: OutlineInputBorder(),
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
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Height',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.height, color: themeColor),
                            const SizedBox(width: 10),
                            Text(
                              _heightFeetController.text.isNotEmpty || _heightInchesController.text.isNotEmpty
                                ? '${_heightFeetController.text} ft ${_heightInchesController.text} in'
                                : 'Not specified',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                
                // Weight (in pounds)
                _isEditing
                  ? TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Current Weight (lbs)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.monitor_weight),
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
                  : Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Weight (lbs)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.monitor_weight, color: themeColor),
                              const SizedBox(width: 10),
                              Text(
                                _weightController.text.isEmpty ? 'Not specified' : '${_weightController.text} lbs',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                        ],
                      ),
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
                
                // Goals List
                _goals.isEmpty && !_isEditing
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
                      children: [
                        ..._goals.asMap().entries.map((entry) {
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            leading: Icon(Icons.fitness_center, color: themeColor),
                            title: Text(
                              entry.value,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            trailing: _isEditing ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeGoal(entry.key),
                            ) : null,
                          );
                        }).toList(),
                      ],
                    ),
                
                // Add Goal Input
                if (_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _goalController,
                          decoration: const InputDecoration(
                            labelText: 'Add Goal',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: themeColor),
                        onPressed: _addGoal,
                      ),
                    ],
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
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                            )
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