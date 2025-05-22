import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/profile_image_service.dart';
import '../../models/user_model.dart';
import '../../models/goal_model.dart';
import '../../theme/app_styles.dart';

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
                    name: "${_firstNameController.text} ${_lastNameController.text}",
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
                
                // Logout Section
                if (!_isEditing) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  // Log out button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text("Sign Out"),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
} 