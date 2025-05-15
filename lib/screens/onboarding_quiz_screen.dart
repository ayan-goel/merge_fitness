import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/goal_model.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class OnboardingQuizScreen extends StatefulWidget {
  const OnboardingQuizScreen({super.key});

  @override
  State<OnboardingQuizScreen> createState() => _OnboardingQuizScreenState();
}

class _OnboardingQuizScreenState extends State<OnboardingQuizScreen> {
  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();
  
  // Quiz state
  int _currentPage = 0;
  String? _displayName;
  double? _height; // Stored in cm in database
  double? _weight; // Stored in kg in database
  DateTime? _dateOfBirth;
  List<String> _selectedGoals = [];
  String? _phoneNumber;
  
  // Height fields in US units
  int _feet = 5;
  int _inches = 8;
  
  // Weight field in US units
  final TextEditingController _weightController = TextEditingController(text: '160');
  
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
  
  // Loading state
  bool _isLoading = false;
  
  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
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
  
  // Navigate to next page
  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
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
      // Convert string goals to Goal objects
      List<Goal> goalObjects = _selectedGoals.map((goalStr) => 
        Goal(value: goalStr, completed: false)
      ).toList();
      
      await _authService.updateUserProfile(
        displayName: _displayName,
        height: _height,
        weight: _weight,
        dateOfBirth: _dateOfBirth,
        goals: goalObjects,
        phoneNumber: _phoneNumber,
      );
      
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentPage + 1) / 4,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
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
                  _buildGoalsPage(),
                  _buildContactInfoPage(),
                ],
              ),
            ),
            
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  if (_currentPage > 0)
                    SizedBox(
                      width: 100,
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        child: const Text('Back'),
                      ),
                    )
                  else
                    const SizedBox(width: 100),
                  
                  // Next/Finish button
                  SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _nextPage,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_currentPage < 3 ? 'Next' : 'Finish'),
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us about yourself',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll use this information to personalize your experience.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          
          // Name field
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Your Name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _displayName = value;
              });
            },
          ),
          const SizedBox(height: 32),
          
          // Date of birth field
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
                firstDate: DateTime(1940),
                lastDate: DateTime.now(),
              );
              
              if (picked != null) {
                setState(() {
                  _dateOfBirth = picked;
                });
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                border: OutlineInputBorder(),
              ),
              child: _dateOfBirth == null
                  ? const Text('Select your date of birth')
                  : Text(
                      DateFormat.yMd().format(_dateOfBirth!), // US format: MM/DD/YYYY
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Page 2: Height and weight
  Widget _buildHeightWeightPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your body metrics',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us track your progress over time.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          
          // Height field (feet and inches)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      decoration: const InputDecoration(
                        labelText: 'Feet',
                        border: OutlineInputBorder(),
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
                      decoration: const InputDecoration(
                        labelText: 'Inches',
                        border: OutlineInputBorder(),
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
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Weight field (in pounds)
          TextFormField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Weight (lbs)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              _updateWeightFromPounds(value);
            },
          ),
          
          const SizedBox(height: 24),
          
          // Informational card
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Why we collect this',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your height and weight help us calculate metrics like BMI and tailor workouts to your needs. You can update these values anytime in your profile.',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Page 3: Fitness goals
  Widget _buildGoalsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your fitness goals',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Select all that apply to you.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          
          // Goals selection
          Expanded(
            child: ListView.builder(
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
                  activeColor: Theme.of(context).colorScheme.primary,
                  checkColor: Colors.white,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // Page 4: Contact information
  Widget _buildContactInfoPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your contact information',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll use this for appointment reminders.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          
          // Phone number field
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
              hintText: '+1 (123) 456-7890',
            ),
            keyboardType: TextInputType.phone,
            onChanged: (value) {
              setState(() {
                _phoneNumber = value;
              });
            },
          ),
          
          const SizedBox(height: 32),
          
          // Confirmation message
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Almost done!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click "Finish" to complete your profile setup and start your fitness journey with Merge Fitness!',
                    style: TextStyle(color: Colors.green[700]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 