import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/goal_model.dart';
import '../models/onboarding_form_model.dart';
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../widgets/onboarding_form_widgets.dart';
import '../widgets/photo_capture_widget.dart';
import '../widgets/signature_capture_widget.dart';
import '../theme/app_styles.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class OnboardingQuizScreen extends StatefulWidget {
  const OnboardingQuizScreen({super.key});

  @override
  State<OnboardingQuizScreen> createState() => _OnboardingQuizScreenState();
}

class _OnboardingQuizScreenState extends State<OnboardingQuizScreen> {
  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();
  final OnboardingService _onboardingService = OnboardingService();
  
  // Quiz state
  int _currentPage = 0;
  String? _firstName;
  String? _lastName;
  double? _height; // Stored in cm in database
  double? _weight; // Stored in kg in database
  DateTime? _dateOfBirth;
  List<String> _selectedGoals = [];
  String? _phoneNumber;
  String? _address;
  String? _email;
  String? _emergencyContact;
  String? _emergencyPhone;

  // Medical history
  bool? _hasHeartDisease;
  bool? _hasBreathingIssues;
  String? _lastPhysicalDate;
  String? _lastPhysicalResult;
  bool? _hasDoctorNoteHeartTrouble;
  bool? _hasAnginaPectoris;
  bool? _hasHeartPalpitations;
  bool? _hasHeartAttack;
  bool? _hasDiabetesOrHighBloodPressure;
  bool? _hasHeartDiseaseInFamily;
  bool? _hasCholesterolMedication;
  bool? _hasHeartMedication;
  bool? _sleepsWell;
  bool? _drinksDailyAlcohol;
  bool? _smokescigarettes;
  bool? _hasPhysicalCondition;
  bool? _hasJointOrMuscleProblems;
  bool? _isPregnant;
  String? _additionalMedicalInfo;

  // Exercise and lifestyle
  String? _exerciseFrequency;
  String? _medications;
  String? _healthGoals;
  String? _stressLevel;
  String? _bestLifePoint;
  List<String> _regularFoods = [];
  String? _eatingHabits;
  String? _typicalBreakfast;
  String? _typicalLunch;
  String? _typicalDinner;
  String? _typicalSnacks;

  // Fitness ratings (1-10)
  int _cardioRespiratoryRating = 5;
  int _strengthRating = 5;
  int _enduranceRating = 5;
  int _flexibilityRating = 5;
  int _powerRating = 5;
  int _bodyCompositionRating = 5;
  int _selfImageRating = 5;

  String? _additionalNotes;
  String? _signatureTimestamp;

  // Gym setup photos
  List<String> _gymSetupPhotos = [];
  List<File> _pendingPhotos = [];
  String? _onboardingFormId;
  
  // Height fields in US units
  int _feet = 5;
  int _inches = 8;
  
  // Weight field in US units
  final TextEditingController _weightController = TextEditingController(text: '160');

  // Form controllers for text fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _lastPhysicalDateController = TextEditingController();
  final TextEditingController _lastPhysicalResultController = TextEditingController();
  final TextEditingController _additionalMedicalInfoController = TextEditingController();
  final TextEditingController _exerciseFrequencyController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _healthGoalsController = TextEditingController();
  final TextEditingController _stressLevelController = TextEditingController();
  final TextEditingController _bestLifePointController = TextEditingController();
  final TextEditingController _eatingHabitsController = TextEditingController();
  final TextEditingController _typicalBreakfastController = TextEditingController();
  final TextEditingController _typicalLunchController = TextEditingController();
  final TextEditingController _typicalDinnerController = TextEditingController();
  final TextEditingController _typicalSnacksController = TextEditingController();
  final TextEditingController _additionalNotesController = TextEditingController();
  
  // Available goals
  final List<String> _availableGoals = [
    'Lose Weight',
    'Build Muscle',
    'Improve Flexibility',
    'Increase Endurance',
    'Better Overall Health',
    'Sports Performance',
    'Stress Relief',
  ];

  // Foods options
  final List<String> _foodOptions = [
    'Bread',
    'Chocolate', 
    'Cheese',
    'Fruit',
    'Cereal',
    'Pasta',
  ];
  
  // Loading state
  bool _isLoading = false;
  
  // More form controllers
  final TextEditingController _cardioRespiratoryRatingController = TextEditingController(text: '5');
  final TextEditingController _strengthRatingController = TextEditingController(text: '5');
  final TextEditingController _enduranceRatingController = TextEditingController(text: '5');
  final TextEditingController _flexibilityRatingController = TextEditingController(text: '5');
  final TextEditingController _powerRatingController = TextEditingController(text: '5');
  final TextEditingController _bodyCompositionRatingController = TextEditingController(text: '5');
  final TextEditingController _selfImageRatingController = TextEditingController(text: '5');

  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _lastPhysicalDateController.dispose();
    _lastPhysicalResultController.dispose();
    _additionalMedicalInfoController.dispose();
    _exerciseFrequencyController.dispose();
    _medicationsController.dispose();
    _healthGoalsController.dispose();
    _stressLevelController.dispose();
    _bestLifePointController.dispose();
    _eatingHabitsController.dispose();
    _typicalBreakfastController.dispose();
    _typicalLunchController.dispose();
    _typicalDinnerController.dispose();
    _typicalSnacksController.dispose();
    _additionalNotesController.dispose();
    _cardioRespiratoryRatingController.dispose();
    _strengthRatingController.dispose();
    _enduranceRatingController.dispose();
    _flexibilityRatingController.dispose();
    _powerRatingController.dispose();
    _bodyCompositionRatingController.dispose();
    _selfImageRatingController.dispose();
    super.dispose();
  }
  
  // Convert feet/inches to centimeters
  void _updateHeightFromFeetInches() {
    // Convert feet and inches to cm: (feet * 12 + inches) * 2.54
    _height = ((_feet * 12) + _inches) * 2.54;
  }
  
  // Convert pounds to kilograms
  void _updateWeightFromPounds(String pounds) {
    if (pounds.isNotEmpty) {
      // Convert pounds to kg: pounds / 2.20462
      _weight = double.tryParse(pounds)! / 2.20462;
    } else {
      _weight = null;
    }
  }
  
  // Initialize data
  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  // Initialize form fields with user data if available
  Future<void> _initializeFields() async {
    try {
      // Get current user email
      final user = _authService.currentUser;
      if (user != null && user.email != null) {
        _email = user.email;
        _emailController.text = user.email!;
      }
    } catch (e) {
      print('Error initializing fields: $e');
    }
  }
  
  // Navigate to next page
  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Check if ready to finish before completing onboarding
      if (_canFinishOnboarding()) {
      _completeOnboarding();
      } else {
        _showCompletionRequiredDialog();
      }
    }
  }
  
  // Check if user can finish onboarding
  bool _canFinishOnboarding() {
    // Must have signed the agreement
    if (_signatureTimestamp == null) {
      return false;
    }
    
    // Must have uploaded at least one gym photo
    if (_pendingPhotos.isEmpty && _gymSetupPhotos.isEmpty) {
      return false;
    }
    
    return true;
  }
  
  // Show dialog explaining what's required to finish
  void _showCompletionRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Complete Your Onboarding'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('To finish your onboarding, you need to:'),
              const SizedBox(height: 12),
              
              // Agreement requirement
              Row(
                children: [
                  Icon(
                    _signatureTimestamp != null ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: _signatureTimestamp != null ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Sign the consent agreement'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Photos requirement
              Row(
                children: [
                  Icon(
                    (_pendingPhotos.isNotEmpty || _gymSetupPhotos.isNotEmpty) ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: (_pendingPhotos.isNotEmpty || _gymSetupPhotos.isNotEmpty) ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Upload at least one photo of your gym setup'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  // Navigate to previous page
  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  // Total number of pages in the onboarding process
  int get _totalPages => 8;
  
  // Submit onboarding data
  Future<void> _completeOnboarding() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    // Ensure height and weight are converted to metric for storage
    _updateHeightFromFeetInches();
    _updateWeightFromPounds(_weightController.text);
    
    try {
      // Get current user
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Convert string goals to Goal objects for the user profile
      List<Goal> goalObjects = _selectedGoals.map((goalStr) => 
        Goal(value: goalStr, completed: false)
      ).toList();
      
      // Update basic user profile in Auth and Firestore
      await _authService.updateUserProfile(
        firstName: _firstName,
        lastName: _lastName,
        height: _height,
        weight: _weight,
        dateOfBirth: _dateOfBirth,
        goals: goalObjects,
        phoneNumber: _phoneNumber,
      );
      
      // Create onboarding form model
      final onboardingForm = OnboardingFormModel(
        clientId: user.uid,
        clientName: (_firstName != null && _lastName != null) 
            ? '$_firstName $_lastName' 
            : user.displayName ?? 'Client',
        phoneNumber: _phoneNumber,
        email: _email,
        address: _address,
        dateOfBirth: _dateOfBirth,
        height: _height,
        weight: _weight,
        emergencyContact: _emergencyContact,
        emergencyPhone: _emergencyPhone,
        hasHeartDisease: _hasHeartDisease,
        hasBreathingIssues: _hasBreathingIssues,
        lastPhysicalDate: _lastPhysicalDate,
        lastPhysicalResult: _lastPhysicalResult,
        hasDoctorNoteHeartTrouble: _hasDoctorNoteHeartTrouble,
        hasAnginaPectoris: _hasAnginaPectoris,
        hasHeartPalpitations: _hasHeartPalpitations,
        hasHeartAttack: _hasHeartAttack,
        hasDiabetesOrHighBloodPressure: _hasDiabetesOrHighBloodPressure,
        hasHeartDiseaseInFamily: _hasHeartDiseaseInFamily,
        hasCholesterolMedication: _hasCholesterolMedication,
        hasHeartMedication: _hasHeartMedication,
        sleepsWell: _sleepsWell,
        drinksDailyAlcohol: _drinksDailyAlcohol,
        smokescigarettes: _smokescigarettes,
        hasPhysicalCondition: _hasPhysicalCondition,
        hasJointOrMuscleProblems: _hasJointOrMuscleProblems,
        isPregnant: _isPregnant,
        additionalMedicalInfo: _additionalMedicalInfo,
        exerciseFrequency: _exerciseFrequency,
        medications: _medications,
        healthGoals: _healthGoals,
        stressLevel: _stressLevel,
        bestLifePoint: _bestLifePoint,
        regularFoods: _regularFoods,
        eatingHabits: _eatingHabits,
        typicalBreakfast: _typicalBreakfast,
        typicalLunch: _typicalLunch,
        typicalDinner: _typicalDinner,
        typicalSnacks: _typicalSnacks,
        cardioRespiratoryRating: _cardioRespiratoryRating,
        strengthRating: _strengthRating,
        enduranceRating: _enduranceRating,
        flexibilityRating: _flexibilityRating,
        powerRating: _powerRating,
        bodyCompositionRating: _bodyCompositionRating,
        selfImageRating: _selfImageRating,
        additionalNotes: _additionalNotes,
        signatureTimestamp: _signatureTimestamp,
      );
      
      // Save form to Firestore
      final formId = await _onboardingService.saveOnboardingForm(onboardingForm);
      _onboardingFormId = formId;
      
      // Upload any pending gym setup photos
      if (_pendingPhotos.isNotEmpty) {
        print("Uploading ${_pendingPhotos.length} gym setup photos for client ${user.uid}");
        
        for (int i = 0; i < _pendingPhotos.length; i++) {
          final photo = _pendingPhotos[i];
          print("Uploading photo ${i+1}/${_pendingPhotos.length}");
          
          try {
            final photoUrl = await _onboardingService.uploadGymSetupPhoto(photo, user.uid);
            print("Photo ${i+1} uploaded successfully: $photoUrl");
            
            await _onboardingService.addGymSetupPhotoToForm(formId, photoUrl);
            print("Photo ${i+1} added to form $formId");
          } catch (e) {
            print("Error uploading photo ${i+1}: $e");
          }
        }
      } else {
        print("No pending photos to upload");
      }
      
      // Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Show the signature dialog
  void _showSignatureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SignatureDialog(
        clientName: (_firstName != null && _lastName != null) 
            ? '$_firstName $_lastName' 
            : 'Client',
        onSigned: (timestamp) {
          setState(() {
            _signatureTimestamp = timestamp;
          });
        },
      ),
    );
  }

  // Handle photo selection
  void _handlePhotoSelected(File photo) {
    setState(() {
      _pendingPhotos.add(photo);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo added successfully')),
    );
  }

  // Return to login screen
  Future<void> _returnToLogin() async {
    // Sign out the user and return to login
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Page title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/mergelogo.png',
                    height: 32,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Client Onboarding',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.primarySage,
                    ),
                  ),
                ],
              ),
            ),

            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step ${_currentPage + 1} of $_totalPages',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.textDark.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_currentPage + 1) / _totalPages,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppStyles.primarySage,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPersonalInfoPage(),
                  _buildHeightWeightPage(),
                  _buildMedicalHistoryPage1(),
                  _buildMedicalHistoryPage2(),
                  _buildExerciseAndLifestylePage(),
                  _buildDietaryPage(),
                  _buildFitnessRatingsPage(),
                  _buildSignatureAndPhotosPage(),
                ],
              ),
            ),
            
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button or Back to Login button
                  if (_currentPage > 0)
                    SizedBox(
                      width: 100,
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppStyles.primarySage,
                          side: BorderSide(color: AppStyles.primarySage),
                        ),
                        child: const Text('Back'),
                      ),
                    )
                  else
                    SizedBox(
                      width: 120,
                      child: OutlinedButton(
                        onPressed: _returnToLogin,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  
                  // Next/Finish button
                  SizedBox(
                    width: 120,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_currentPage < _totalPages - 1 || _canFinishOnboarding()) 
                            ? AppStyles.primarySage 
                            : Colors.grey[400],
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_currentPage < _totalPages - 1 ? 'Next' : 'Finish'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Page 1: Basic personal info
  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormSectionTitle(
            title: 'Tell us about yourself',
            icon: Icons.person,
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll use this information to personalize your experience and complete your client profile.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 24),
          
          // Name fields
          Row(
            children: [
              // First Name field
              Expanded(
                child: TextField(
                  controller: _firstNameController,
                  decoration: AppStyles.inputDecoration(
                    labelText: 'First Name',
                    hintText: 'Enter your first name',
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (value) {
                    setState(() {
                      _firstName = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Last Name field
              Expanded(
                child: TextField(
                  controller: _lastNameController,
                  decoration: AppStyles.inputDecoration(
                    labelText: 'Last Name',
                    hintText: 'Enter your last name',
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (value) {
                    setState(() {
                      _lastName = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Email field
          TextField(
            controller: _emailController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email address',
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _email = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Phone field
          TextField(
            controller: _phoneController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Phone Number',
              hintText: 'Enter your phone number',
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _phoneNumber = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Address field
          TextField(
            controller: _addressController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Address',
              hintText: 'Enter your address',
              prefixIcon: const Icon(Icons.home_outlined),
            ),
            keyboardType: TextInputType.streetAddress,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _address = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Date of birth field
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
                firstDate: DateTime(1940),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: AppStyles.primarySage,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              
              if (picked != null) {
                setState(() {
                  _dateOfBirth = picked;
                });
              }
            },
            child: InputDecorator(
              decoration: AppStyles.inputDecoration(
                labelText: 'Date of Birth',
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              child: _dateOfBirth == null
                  ? const Text('Select your date of birth')
                  : Text(
                      DateFormat.yMd().format(_dateOfBirth!),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Emergency contact info
          const FormSectionTitle(
            title: 'Emergency Contact',
            icon: Icons.emergency,
          ),
          const SizedBox(height: 16),

          // Emergency Contact Name
          TextField(
            controller: _emergencyContactController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Emergency Contact Name',
              hintText: 'Who should we contact in an emergency?',
              prefixIcon: const Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _emergencyContact = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Emergency Contact Phone
          TextField(
            controller: _emergencyPhoneController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Emergency Contact Phone',
              hintText: 'Enter emergency contact\'s phone number',
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _emergencyPhone = value;
              });
            },
          ),
        ],
      ),
    );
  }
  
  // Page 2: Height and weight
  Widget _buildHeightWeightPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormSectionTitle(
            title: 'Your Body Metrics',
            icon: Icons.fitness_center,
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us track your progress over time and create personalized workouts.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 24),
          
          // Height field (feet and inches)
          const Text(
            'Height',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Feet dropdown
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: AppStyles.inputDecoration(
                    labelText: 'Feet',
                    prefixIcon: const Icon(Icons.height),
                  ),
                  value: _feet,
                  items: List.generate(8, (index) => index + 3)
                      .map((feet) => DropdownMenuItem(
                            value: feet,
                            child: Text('$feet ft'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _feet = value;
                        _updateHeightFromFeetInches();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Inches dropdown
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: AppStyles.inputDecoration(
                    labelText: 'Inches',
                    prefixIcon: const Icon(Icons.straighten),
                  ),
                  value: _inches,
                  items: List.generate(12, (index) => index)
                      .map((inches) => DropdownMenuItem(
                            value: inches,
                            child: Text('$inches in'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _inches = value;
                        _updateHeightFromFeetInches();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Weight field (in pounds)
          TextField(
            controller: _weightController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Weight (lbs)',
              hintText: 'Enter your weight in pounds',
              prefixIcon: const Icon(Icons.monitor_weight_outlined),
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              _updateWeightFromPounds(value);
            },
          ),
          
          const SizedBox(height: 24),
          
          // Informational card
          const InfoCard(
            message: 'Your height and weight help us calculate metrics like BMI and tailor workouts to your needs. You can update these values anytime in your profile.',
            backgroundColor: Color(0xFFE3F2FD), // Light blue background
            textColor: Color(0xFF1976D2), // Blue text
          ),
        ],
      ),
    );
  }
  
  // Page 3: Medical History (Part 1)
  Widget _buildMedicalHistoryPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormSectionTitle(
            title: 'Medical History',
            icon: Icons.medical_information,
          ),
          const SizedBox(height: 8),
          Text(
            'This information helps us ensure your training program is safe for your individual needs.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 24),
          
          // Last physical date
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2010),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: AppStyles.primarySage,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              
              if (picked != null) {
                setState(() {
                  _lastPhysicalDate = DateFormat.yMd().format(picked);
                  _lastPhysicalDateController.text = _lastPhysicalDate!;
                });
              }
            },
            child: InputDecorator(
              decoration: AppStyles.inputDecoration(
                labelText: 'Date of Last Physical',
                suffixIcon: const Icon(Icons.calendar_today),
                prefixIcon: const Icon(Icons.calendar_month_outlined),
              ),
              child: Text(_lastPhysicalDate ?? 'Select date of your last physical'),
            ),
          ),
          const SizedBox(height: 16),
          
          // Physical result
          TextField(
            controller: _lastPhysicalResultController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Result of Last Physical',
              hintText: 'E.g., Normal, Good, etc.',
              prefixIcon: const Icon(Icons.check_circle_outline),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _lastPhysicalResult = value;
              });
            },
          ),
          const SizedBox(height: 24),
          
          // Medical questions (Yes/No)
          YesNoQuestion(
            question: 'Have you ever had Heart Disease?',
            value: _hasHeartDisease,
            onChanged: (value) {
              setState(() {
                _hasHeartDisease = value;
              });
            },
          ),
          
          YesNoQuestion(
            question: 'Have you ever experienced shortness of breath or chest pains?',
            value: _hasBreathingIssues,
            onChanged: (value) {
              setState(() {
                _hasBreathingIssues = value;
              });
            },
          ),
          
          YesNoQuestion(
            question: 'Has your doctor ever said you have heart trouble?',
            value: _hasDoctorNoteHeartTrouble,
            onChanged: (value) {
              setState(() {
                _hasDoctorNoteHeartTrouble = value;
              });
            },
          ),
          
          YesNoQuestion(
            question: 'Have you ever had angina pectoris, sharp pain, or heavy pressure in your chest?',
            value: _hasAnginaPectoris,
            onChanged: (value) {
              setState(() {
                _hasAnginaPectoris = value;
              });
            },
          ),
          
          YesNoQuestion(
            question: 'Have you ever experienced rapid heart action or palpitations?',
            value: _hasHeartPalpitations,
            onChanged: (value) {
              setState(() {
                _hasHeartPalpitations = value;
              });
            },
          ),
        ],
      ),
    );
  }

  // Page 4: Medical History (Part 2)
  Widget _buildMedicalHistoryPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormSectionTitle(
            title: 'Medical History (Continued)',
            icon: Icons.medical_information,
          ),
          const SizedBox(height: 24),
          
          // More medical questions (Yes/No)
          YesNoQuestion(
            question: 'Have you ever had a real or suspected heart attack?',
            value: _hasHeartAttack,
            onChanged: (value) {
              setState(() {
                _hasHeartAttack = value;
              });
            },
          ),
          
          YesNoQuestion(
            question: 'Do you have diabetes, hypertension, or high blood pressure?',
            value: _hasDiabetesOrHighBloodPressure,
            onChanged: (value) {
              setState(() {
                _hasDiabetesOrHighBloodPressure = value;
              });
            },
          ),
          
          YesNoQuestion(
            question: 'Has more than one blood relative had a heart attack or coronary artery disease before the age of 60?',
            value: _hasHeartDiseaseInFamily,
            onChanged: (value) {
              setState(() {
                _hasHeartDiseaseInFamily = value;
              });
            },
          ),
          
          YesNoQuestion(
            question: 'Have you ever taken medications to lower your cholesterol?',
            value: _hasCholesterolMedication,
            onChanged: (value) {
              setState(() {
                _hasCholesterolMedication = value;
              });
            },
          ),
          
          YesNoQuestion(
            question: 'Have you ever taken any drug for your heart?',
            value: _hasHeartMedication,
            onChanged: (value) {
              setState(() {
                _hasHeartMedication = value;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // Sleep well question
          YesNoQuestion(
            question: 'Do you sleep well?',
            value: _sleepsWell,
            onChanged: (value) {
              setState(() {
                _sleepsWell = value;
              });
            },
          ),
          
          // More lifestyle questions
          YesNoQuestion(
            question: 'Do you drink alcohol daily?',
            value: _drinksDailyAlcohol,
            onChanged: (value) {
              setState(() {
                _drinksDailyAlcohol = value;
              });
            },
          ),
          
          YesNoQuestion(
            question: 'Do you smoke cigarettes?',
            value: _smokescigarettes,
            onChanged: (value) {
              setState(() {
                _smokescigarettes = value;
              });
            },
          ),
          
          YesNoQuestion(
            question: 'Do you have a physical condition that should be considered before undertaking exercise?',
            value: _hasPhysicalCondition,
            onChanged: (value) {
              setState(() {
                _hasPhysicalCondition = value;
              });
            },
          ),
          
          YesNoQuestion(
            question: 'Do you have any pain or stiffness in your muscles or joints?',
            value: _hasJointOrMuscleProblems,
            onChanged: (value) {
              setState(() {
                _hasJointOrMuscleProblems = value;
              });
            },
          ),
          
          YesNoQuestion(
            question: 'For females: Are you pregnant?',
            value: _isPregnant,
            onChanged: (value) {
              setState(() {
                _isPregnant = value;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // Additional medical information
          TextField(
            controller: _additionalMedicalInfoController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Additional Medical Information',
              hintText: 'If you answered YES to any of the questions, please provide additional information here',
              prefixIcon: const Icon(Icons.medical_information_outlined),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _additionalMedicalInfo = value;
              });
            },
          ),
        ],
      ),
    );
  }
  
  // Page 5: Exercise and lifestyle
  Widget _buildExerciseAndLifestylePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormSectionTitle(
            title: 'Exercise and Lifestyle',
            icon: Icons.directions_run,
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about your exercise habits and lifestyle.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 24),
          
          // Fitness goals section
          const FormSectionTitle(
            title: 'Fitness Goals',
            icon: Icons.flag,
          ),
          const SizedBox(height: 16),
          
          // Goals selection
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppStyles.slateGray.withOpacity(0.3)),
              borderRadius: AppStyles.defaultBorderRadius,
              color: Colors.grey.shade50,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _availableGoals.length,
              itemBuilder: (context, index) {
                final goal = _availableGoals[index];
                final isSelected = _selectedGoals.contains(goal);
                
                return CheckboxListTile(
                  title: Text(goal),
                  value: isSelected,
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedGoals.add(goal);
                      } else {
                        _selectedGoals.remove(goal);
                      }
                    });
                  },
                  activeColor: AppStyles.primarySage,
                  checkColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          
          // Exercise frequency
          TextField(
            controller: _exerciseFrequencyController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Exercise Frequency and Intensity',
              hintText: 'E.g., 3 times per week, moderate intensity',
              prefixIcon: const Icon(Icons.fitness_center_outlined),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _exerciseFrequency = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Medications
          TextField(
            controller: _medicationsController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Medications and Supplements',
              hintText: 'List any medications including herbal supplements',
              prefixIcon: const Icon(Icons.medication_outlined),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _medications = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Health goals
          TextField(
            controller: _healthGoalsController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Health Goals',
              hintText: 'What are your health goals?',
              prefixIcon: const Icon(Icons.emoji_events_outlined),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _healthGoals = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Stress level
          TextField(
            controller: _stressLevelController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Stress Level',
              hintText: 'Describe your general stress level',
              prefixIcon: const Icon(Icons.psychology_outlined),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _stressLevel = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Best life point
          TextField(
            controller: _bestLifePointController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Best Point in Life',
              hintText: 'At what point in your life did you feel your best? Why?',
              prefixIcon: const Icon(Icons.timeline_outlined),
            ),
            maxLines: 2,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _bestLifePoint = value;
              });
            },
          ),
        ],
      ),
    );
  }
  
  // Page 6: Dietary information
  Widget _buildDietaryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormSectionTitle(
            title: 'Dietary Information',
            icon: Icons.restaurant_menu,
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about your eating habits to help us create a nutrition plan.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 24),
          
          // Foods consumed regularly
          const Text(
            'Which of these foods do you eat regularly? (Select all that apply)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          
          // Food options
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _foodOptions.map((food) {
              final isSelected = _regularFoods.contains(food);
              return FilterChip(
                label: Text(food),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _regularFoods.add(food);
                    } else {
                      _regularFoods.remove(food);
                    }
                  });
                },
                selectedColor: AppStyles.primarySage.withOpacity(0.3),
                backgroundColor: Colors.grey.shade50,
                checkmarkColor: AppStyles.primarySage,
                labelStyle: TextStyle(
                  color: isSelected ? AppStyles.primarySage : AppStyles.textDark,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected 
                      ? AppStyles.primarySage 
                      : AppStyles.slateGray.withOpacity(0.3),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          
          // Eating habits
          TextField(
            controller: _eatingHabitsController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Describe your eating habits',
              hintText: 'E.g., I eat 3 meals a day with snacks, I follow a keto diet, etc.',
              prefixIcon: const Icon(Icons.restaurant_outlined),
            ),
            maxLines: 2,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _eatingHabits = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Typical meals
          const FormSectionTitle(
            title: 'Typical Daily Meals',
            icon: Icons.food_bank_outlined,
          ),
          const SizedBox(height: 16),
          
          // Typical breakfast
          TextField(
            controller: _typicalBreakfastController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Typical Breakfast',
              hintText: 'Describe a typical breakfast',
              prefixIcon: const Icon(Icons.wb_sunny_outlined),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _typicalBreakfast = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Typical lunch
          TextField(
            controller: _typicalLunchController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Typical Lunch',
              hintText: 'Describe a typical lunch',
              prefixIcon: const Icon(Icons.lunch_dining_outlined),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _typicalLunch = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Typical dinner
          TextField(
            controller: _typicalDinnerController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Typical Dinner',
              hintText: 'Describe a typical dinner',
              prefixIcon: const Icon(Icons.dinner_dining_outlined),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _typicalDinner = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Typical snacks
          TextField(
            controller: _typicalSnacksController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Typical Snacks',
              hintText: 'Describe your typical snacks',
              prefixIcon: const Icon(Icons.cookie_outlined),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _typicalSnacks = value;
              });
            },
          ),
        ],
      ),
    );
  }

  // Page 7: Fitness ratings
  Widget _buildFitnessRatingsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormSectionTitle(
            title: 'Fitness Ratings',
            icon: Icons.fitness_center,
          ),
          const SizedBox(height: 8),
          Text(
            'Rate your current fitness level in each category (1 = Poor, 5 = Average, 10 = Excellent).',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 24),
          
          // Cardio-respiratory fitness
          SliderRatingInput(
            label: 'Cardio-Respiratory',
            value: _cardioRespiratoryRating,
            onChanged: (value) {
              setState(() {
                _cardioRespiratoryRating = value.toInt();
                _cardioRespiratoryRatingController.text = value.toInt().toString();
              });
            },
          ),
          
          // Strength
          SliderRatingInput(
            label: 'Strength',
            value: _strengthRating,
            onChanged: (value) {
              setState(() {
                _strengthRating = value.toInt();
                _strengthRatingController.text = value.toInt().toString();
              });
            },
          ),
          
          // Endurance
          SliderRatingInput(
            label: 'Endurance',
            value: _enduranceRating,
            onChanged: (value) {
              setState(() {
                _enduranceRating = value.toInt();
                _enduranceRatingController.text = value.toInt().toString();
              });
            },
          ),
          
          // Flexibility
          SliderRatingInput(
            label: 'Flexibility',
            value: _flexibilityRating,
            onChanged: (value) {
              setState(() {
                _flexibilityRating = value.toInt();
                _flexibilityRatingController.text = value.toInt().toString();
              });
            },
          ),
          
          // Power
          SliderRatingInput(
            label: 'Power',
            value: _powerRating,
            onChanged: (value) {
              setState(() {
                _powerRating = value.toInt();
                _powerRatingController.text = value.toInt().toString();
              });
            },
          ),
          
          // Body composition
          SliderRatingInput(
            label: 'Body Composition',
            value: _bodyCompositionRating,
            onChanged: (value) {
              setState(() {
                _bodyCompositionRating = value.toInt();
                _bodyCompositionRatingController.text = value.toInt().toString();
              });
            },
          ),
          
          // Self image
          SliderRatingInput(
            label: 'Self Image',
            value: _selfImageRating,
            onChanged: (value) {
              setState(() {
                _selfImageRating = value.toInt();
                _selfImageRatingController.text = value.toInt().toString();
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // Additional notes
          TextField(
            controller: _additionalNotesController,
            decoration: AppStyles.inputDecoration(
              labelText: 'Additional Notes',
              hintText: 'Is there anything else you\'d like us to know about you?',
              prefixIcon: const Icon(Icons.note_outlined),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() {
                _additionalNotes = value;
              });
            },
          ),
        ],
      ),
    );
  }
  
  // Page 8: Signature and photos
  Widget _buildSignatureAndPhotosPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormSectionTitle(
            title: 'Confirmation and Gym Setup',
            icon: Icons.check_circle,
          ),
          const SizedBox(height: 8),
          Text(
            'Please sign the consent form and upload photos of your workout space.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 24),
          
          // Signature section
          const Text(
            'MERGE Health, Fitness & Nutrition, Inc. Agreement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Contract signature section
          SignatureBox(
            onSign: _showSignatureDialog,
            signatureTimestamp: _signatureTimestamp,
          ),
          const SizedBox(height: 24),
          
          // Gym setup photos section
          const FormSectionTitle(
            title: 'Gym Setup Photos',
            icon: Icons.photo_camera,
          ),
          const SizedBox(height: 8),
          
          // Photo capture widget
          PhotoCaptureWidget(
            onPhotoSelected: _handlePhotoSelected,
            existingPhotos: _gymSetupPhotos,
            pendingPhotos: _pendingPhotos,
            onRemovePhoto: (file) {
              setState(() {
                _pendingPhotos.remove(file);
              });
            },
          ),
          
          const SizedBox(height: 24),
          
          // Final confirmation and requirements status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _canFinishOnboarding() ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _canFinishOnboarding() ? Colors.green[200]! : Colors.orange[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _canFinishOnboarding() ? Icons.check_circle : Icons.info_outline,
                      color: _canFinishOnboarding() ? Colors.green[700] : Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _canFinishOnboarding() ? 'Ready to Complete!' : 'Complete Required Steps',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: _canFinishOnboarding() ? Colors.green[700] : Colors.orange[700],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                if (_canFinishOnboarding()) ...[
                Text(
                  'You\'re ready to complete your onboarding process. Click "Finish" to submit your information and begin your fitness journey with Merge Fitness.',
                  style: TextStyle(color: Colors.green[700]),
                ),
                ] else ...[
                  Text(
                    'Please complete the following requirements before finishing:',
                    style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(height: 12),
                  
                  // Agreement requirement
                  _buildRequirementRow(
                    'Sign the consent agreement',
                    _signatureTimestamp != null,
                  ),
                  const SizedBox(height: 8),
                  
                  // Photos requirement
                  _buildRequirementRow(
                    'Upload at least one gym setup photo',
                    _pendingPhotos.isNotEmpty || _gymSetupPhotos.isNotEmpty,
                          ),
                ],
                      ],
                    ),
                  ),
                ],
      ),
    );
  }
  
  // Helper method to build requirement status rows
  Widget _buildRequirementRow(String requirement, bool isCompleted) {
    return Row(
      children: [
        Icon(
          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isCompleted ? Colors.green : Colors.grey,
          size: 20,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            requirement,
            style: TextStyle(
              color: isCompleted ? Colors.green[700] : Colors.grey[700],
              fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
} 