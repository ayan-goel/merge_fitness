import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/meal_entry_model.dart';
import '../../models/nutrition_plan_model.dart';
import '../../services/meal_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/auth_service.dart';
import 'meal_entry_screen.dart';

class ClientNutritionScreen extends StatefulWidget {
  const ClientNutritionScreen({super.key});

  @override
  State<ClientNutritionScreen> createState() => _ClientNutritionScreenState();
}

class _ClientNutritionScreenState extends State<ClientNutritionScreen> {
  final MealService _mealService = MealService();
  final NutritionService _nutritionService = NutritionService();
  final AuthService _authService = AuthService();

  DateTime _selectedDate = DateTime.now();
  String? _clientId;
  NutritionPlan? _activePlan;
  bool _isLoading = true;
  
  // Expanded state tracking
  bool _isPlanMicroExpanded = false;
  bool _isProgressMicroExpanded = false;
  Map<String, bool> _mealMicroExpanded = {};

  @override
  void initState() {
    super.initState();
    _loadClientId();
  }

  Future<void> _loadClientId() async {
    try {
      final user = await _authService.getUserModel();
      setState(() {
        _clientId = user.uid;
        _isLoading = false;
      });
      _loadActivePlan();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading client ID: $e');
    }
  }

  Future<void> _loadActivePlan() async {
    if (_clientId == null) return;
    
    try {
      final plan = await _nutritionService.getCurrentNutritionPlan(_clientId!);
      setState(() {
        _activePlan = plan;
      });
    } catch (e) {
      print('Error loading active nutrition plan: $e');
    }
  }

  void _goToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _goToNextDay() {
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    if (!tomorrow.isAfter(DateTime.now())) {
      setState(() {
        _selectedDate = tomorrow;
      });
    }
  }

  void _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  void _navigateToAddMeal() async {
    if (_clientId == null) return;

    final emptyMeal = MealEntry.empty(_clientId!).copyWith(date: _selectedDate);
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealEntryScreen(
          meal: emptyMeal,
          nutritionPlan: _activePlan,
        ),
      ),
    );
    
    if (result == 'added' || result == 'updated') {
      // Progress bars will update automatically due to StreamBuilder
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meal ${result == 'added' ? 'added' : 'updated'} successfully')),
      );
    }
  }

  void _navigateToEditMeal(MealEntry meal) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealEntryScreen(
          meal: meal,
          nutritionPlan: _activePlan,
        ),
      ),
    );
    
    if (result == 'updated') {
      // Progress bars will update automatically due to StreamBuilder
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal updated successfully')),
      );
    } else if (result == 'deleted') {
      // Progress bars will update automatically due to StreamBuilder
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal deleted successfully')),
      );
    }
  }

  void _confirmDeleteMeal(MealEntry meal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Meal'),
          content: Text('Are you sure you want to delete "${meal.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _mealService.deleteMealEntry(meal.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Meal deleted successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting meal: $e')),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _clientId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Nutrition'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date selector with arrows
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: _goToPreviousDay,
                    tooltip: 'Previous day',
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDate,
                      child: Center(
                        child: Text(
                          isToday
                              ? 'Today'
                              : DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: isToday ? null : _goToNextDay,
                    tooltip: isToday ? 'Cannot go to future dates' : 'Next day',
                  ),
                ],
              ),
            ),

            // Active nutrition plan display
            if (_activePlan != null)
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activePlan!.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Daily Target: ${_activePlan!.dailyCalories} calories',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _macronutrientChip('Protein', '${_activePlan!.macronutrients['protein']?.toInt() ?? 0}g', Colors.red.shade100),
                            const SizedBox(width: 8),
                            _macronutrientChip('Carbs', '${_activePlan!.macronutrients['carbs']?.toInt() ?? 0}g', Colors.green.shade100),
                            const SizedBox(width: 8),
                            _macronutrientChip('Fat', '${_activePlan!.macronutrients['fat']?.toInt() ?? 0}g', Colors.blue.shade100),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isPlanMicroExpanded = !_isPlanMicroExpanded;
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isPlanMicroExpanded 
                                  ? Icons.keyboard_arrow_up 
                                  : Icons.keyboard_arrow_down,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                        if (_isPlanMicroExpanded) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _macronutrientChip('Sodium', '${_activePlan!.micronutrients['sodium']?.toInt() ?? 0}mg', Colors.purple.shade100),
                              _macronutrientChip('Cholesterol', '${_activePlan!.micronutrients['cholesterol']?.toInt() ?? 0}mg', Colors.purple.shade100),
                              _macronutrientChip('Fiber', '${_activePlan!.micronutrients['fiber']?.toInt() ?? 0}g', Colors.purple.shade100),
                              _macronutrientChip('Sugar', '${_activePlan!.micronutrients['sugar']?.toInt() ?? 0}g', Colors.purple.shade100),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No active nutrition plan',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your trainer has not assigned a nutrition plan yet.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Daily nutrition progress - MOVED UP BEFORE THE MEALS LIST
            if (_clientId != null && _activePlan != null)
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: StreamBuilder<Map<String, double>>(
                      stream: _mealService.calculateNutritionProgress(_clientId!, _selectedDate),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return const SizedBox(
                            height: 100,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final progress = snapshot.data ?? {
                          'calories': 0.0,
                          'protein': 0.0,
                          'carbs': 0.0,
                          'fat': 0.0,
                        };
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Progress',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Calories progress
                            _buildNutrientProgressBar(
                              'Calories',
                              progress['calories'] ?? 0.0,
                              '${(progress['calories'] ?? 0.0) * _activePlan!.dailyCalories ~/ 1} / ${_activePlan!.dailyCalories} kcal',
                            ),
                            const SizedBox(height: 8),
                            
                            // Macronutrients
                            _buildNutrientProgressBar(
                              'Protein',
                              progress['protein'] ?? 0.0,
                              '${((progress['protein'] ?? 0.0) * (_activePlan!.macronutrients['protein'] ?? 0)).toStringAsFixed(1)} / ${_activePlan!.macronutrients['protein']?.toStringAsFixed(1) ?? 0} g',
                            ),
                            const SizedBox(height: 4),
                            _buildNutrientProgressBar(
                              'Carbs',
                              progress['carbs'] ?? 0.0,
                              '${((progress['carbs'] ?? 0.0) * (_activePlan!.macronutrients['carbs'] ?? 0)).toStringAsFixed(1)} / ${_activePlan!.macronutrients['carbs']?.toStringAsFixed(1) ?? 0} g',
                            ),
                            const SizedBox(height: 4),
                            _buildNutrientProgressBar(
                              'Fat',
                              progress['fat'] ?? 0.0,
                              '${((progress['fat'] ?? 0.0) * (_activePlan!.macronutrients['fat'] ?? 0)).toStringAsFixed(1)} / ${_activePlan!.macronutrients['fat']?.toStringAsFixed(1) ?? 0} g',
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isProgressMicroExpanded = !_isProgressMicroExpanded;
                                });
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isProgressMicroExpanded 
                                      ? Icons.keyboard_arrow_up 
                                      : Icons.keyboard_arrow_down,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                            if (_isProgressMicroExpanded) ...[
                              const SizedBox(height: 16),
                              // Micronutrients progress
                              _buildNutrientProgressBar(
                                'Sodium',
                                progress['sodium'] ?? 0.0,
                                '${((progress['sodium'] ?? 0.0) * (_activePlan!.micronutrients['sodium'] ?? 0)).toStringAsFixed(0)} / ${_activePlan!.micronutrients['sodium']?.toStringAsFixed(0) ?? 0} mg',
                              ),
                              const SizedBox(height: 4),
                              _buildNutrientProgressBar(
                                'Cholesterol',
                                progress['cholesterol'] ?? 0.0,
                                '${((progress['cholesterol'] ?? 0.0) * (_activePlan!.micronutrients['cholesterol'] ?? 0)).toStringAsFixed(0)} / ${_activePlan!.micronutrients['cholesterol']?.toStringAsFixed(0) ?? 0} mg',
                              ),
                              const SizedBox(height: 4),
                              _buildNutrientProgressBar(
                                'Fiber',
                                progress['fiber'] ?? 0.0,
                                '${((progress['fiber'] ?? 0.0) * (_activePlan!.micronutrients['fiber'] ?? 0)).toStringAsFixed(1)} / ${_activePlan!.micronutrients['fiber']?.toStringAsFixed(1) ?? 0} g',
                              ),
                              const SizedBox(height: 4),
                              _buildNutrientProgressBar(
                                'Sugar',
                                progress['sugar'] ?? 0.0,
                                '${((progress['sugar'] ?? 0.0) * (_activePlan!.micronutrients['sugar'] ?? 0)).toStringAsFixed(1)} / ${_activePlan!.micronutrients['sugar']?.toStringAsFixed(1) ?? 0} g',
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

            // Meals list - No longer in an Expanded widget
            Container(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: StreamBuilder<List<MealEntry>>(
                stream: _mealService.getClientMealsForDate(_clientId!, _selectedDate),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  final meals = snapshot.data ?? [];

                  if (meals.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.no_food,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No meals recorded for this day',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _navigateToAddMeal,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Meal'),
                          ),
                        ],
                      ),
                    );
                  }

                  // Use a Column instead of ListView.builder for non-scrollable display
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Meals',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...meals.map((meal) => _buildMealCard(meal)).toList(),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _navigateToAddMeal,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Another Meal'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(MealEntry meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _navigateToEditMeal(meal),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meal.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat.jm().format(meal.timeConsumed),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${meal.calories} calories',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _macronutrientChip(
                    'P',
                    '${meal.macronutrients['protein']?.toInt() ?? 0}g',
                    Colors.red.shade100,
                  ),
                  const SizedBox(width: 8),
                  _macronutrientChip(
                    'C',
                    '${meal.macronutrients['carbs']?.toInt() ?? 0}g',
                    Colors.green.shade100,
                  ),
                  const SizedBox(width: 8),
                  _macronutrientChip(
                    'F',
                    '${meal.macronutrients['fat']?.toInt() ?? 0}g',
                    Colors.blue.shade100,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (meal.description != null && meal.description!.isNotEmpty)
                Text(
                  meal.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _navigateToEditMeal(meal),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteMeal(meal),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macronutrientChip(String label, String value, [Color? color]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label: $value'),
    );
  }

  Widget _buildNutrientProgressBar(String label, double progress, String valueText) {
    // Cap progress at 1.0 for the visual bar
    final cappedProgress = progress > 1.0 ? 1.0 : progress;
    final isOverLimit = progress > 1.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              valueText,
              style: TextStyle(
                color: isOverLimit ? Colors.red : null,
                fontWeight: isOverLimit ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            // Background track
            Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            // Progress indicator
            Container(
              height: 10,
              width: MediaQuery.of(context).size.width * cappedProgress * 0.8, // Account for padding
              decoration: BoxDecoration(
                color: isOverLimit 
                    ? Colors.red 
                    : (progress > 0.9 ? Colors.green : Theme.of(context).colorScheme.primary),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ],
    );
  }
} 