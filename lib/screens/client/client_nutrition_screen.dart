import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/meal_entry_model.dart';
import '../../models/nutrition_plan_model.dart';
import '../../services/meal_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_styles.dart';
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
  bool _isSampleMealsExpanded = false;
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
    // Dismiss keyboard before changing date
    FocusScope.of(context).unfocus();
    
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _goToNextDay() {
    // Dismiss keyboard before changing date
    FocusScope.of(context).unfocus();
    
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    if (!tomorrow.isAfter(DateTime.now())) {
      setState(() {
        _selectedDate = tomorrow;
      });
    }
  }

  void _selectDate() async {
    // Dismiss keyboard before showing date picker
    FocusScope.of(context).unfocus();
    
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

    // Dismiss keyboard before navigating
    FocusScope.of(context).unfocus();

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
    // Dismiss keyboard before navigating
    FocusScope.of(context).unfocus();
    
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
    // Dismiss keyboard before showing dialog
    FocusScope.of(context).unfocus();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Meal'),
          content: Text('Are you sure you want to delete "${meal.name}"?'),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                FocusScope.of(context).unfocus();
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
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppStyles.primarySage,
          ),
        ),
      );
    }

    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Nutrition'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
          ? Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: AppStyles.primarySage,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadActivePlan();
              },
              child: SingleChildScrollView(
        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date selector with arrows
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              color: AppStyles.primarySage.withOpacity(0.15),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: AppStyles.textDark,
                    ),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppStyles.textDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      color: isToday ? AppStyles.slateGray.withOpacity(0.3) : AppStyles.textDark,
                    ),
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppStyles.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Daily Target: ${_activePlan!.dailyCalories} calories',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppStyles.slateGray,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _macronutrientChip('Protein', '${_activePlan!.macronutrients['protein']?.toInt() ?? 0}g', AppStyles.errorRed.withOpacity(0.2)),
                            const SizedBox(width: 8),
                            _macronutrientChip('Carbs', '${_activePlan!.macronutrients['carbs']?.toInt() ?? 0}g', AppStyles.successGreen.withOpacity(0.2)),
                            const SizedBox(width: 8),
                            _macronutrientChip('Fat', '${_activePlan!.macronutrients['fat']?.toInt() ?? 0}g', AppStyles.mutedBlue.withOpacity(0.2)),
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
                                color: AppStyles.primarySage,
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
                              _macronutrientChip('Sodium', '${_activePlan!.micronutrients['sodium']?.toInt() ?? 0}mg', AppStyles.taupeBrown.withOpacity(0.2)),
                              _macronutrientChip('Cholesterol', '${_activePlan!.micronutrients['cholesterol']?.toInt() ?? 0}mg', AppStyles.taupeBrown.withOpacity(0.2)),
                              _macronutrientChip('Fiber', '${_activePlan!.micronutrients['fiber']?.toInt() ?? 0}g', AppStyles.taupeBrown.withOpacity(0.2)),
                              _macronutrientChip('Sugar', '${_activePlan!.micronutrients['sugar']?.toInt() ?? 0}g', AppStyles.taupeBrown.withOpacity(0.2)),
                            ],
                          ),
                        ],

                                // Sample meals section
                                if (_activePlan!.sampleMeals.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text(
                                        'Recommended Sample Meals',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppStyles.textDark,
                                        ),
                                      ),
                                      const Spacer(),
                                      // Expand/collapse button
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _isSampleMealsExpanded = !_isSampleMealsExpanded;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: AppStyles.primarySage.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _isSampleMealsExpanded
                                                ? Icons.keyboard_arrow_up
                                                : Icons.keyboard_arrow_down,
                                            color: AppStyles.primarySage,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  if (_isSampleMealsExpanded) ...[
                                    const SizedBox(height: 16),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _activePlan!.sampleMeals.length,
                                      itemBuilder: (context, index) {
                                        final meal = _activePlan!.sampleMeals[index];
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 12.0),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Meal name and calories
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.restaurant_menu,
                                                      color: AppStyles.primarySage,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        meal.name,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: AppStyles.primarySage.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        '${meal.calories} cal',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: AppStyles.primarySage,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                
                                                // Macronutrients
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                  children: [
                                                    _buildMacronutrientPill(
                                                      'Protein',
                                                      '${meal.macronutrients['protein']?.toInt() ?? 0}g',
                                                      AppStyles.errorRed,
                                                    ),
                                                    _buildMacronutrientPill(
                                                      'Carbs',
                                                      '${meal.macronutrients['carbs']?.toInt() ?? 0}g',
                                                      AppStyles.successGreen,
                                                    ),
                                                    _buildMacronutrientPill(
                                                      'Fat',
                                                      '${meal.macronutrients['fat']?.toInt() ?? 0}g',
                                                      AppStyles.mutedBlue,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                                
                                // Legacy meal suggestions support
                                if (_activePlan!.sampleMeals.isEmpty && 
                                    _activePlan!.mealSuggestions.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Meal Suggestions',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...List.generate(
                                    _activePlan!.mealSuggestions.length,
                                    (index) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.restaurant_menu, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(_activePlan!.mealSuggestions[index]),
                                          ),
                                        ],
                                      ),
                                    ),
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
                          color: AppStyles.slateGray,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No active nutrition plan',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppStyles.textDark,
                          ),
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
                              style: const TextStyle(
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
                                    color: AppStyles.primarySage,
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
                                crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                                  const Center(
                                    child: Icon(
                            Icons.no_food,
                            size: 64,
                            color: Colors.grey,
                                    ),
                          ),
                          const SizedBox(height: 16),
                                  const Center(
                                    child: Text(
                            'No meals recorded for this day',
                                      style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.textDark,
                                      ),
                                      textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                                  Center(
                                    child: ElevatedButton.icon(
                            onPressed: _navigateToAddMeal,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Meal'),
                                    ),
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
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Text(
                              'Meals',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
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
        ),
      ),
    );
  }

  Widget _buildMealCard(MealEntry meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.textDark,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat.jm().format(meal.timeConsumed),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppStyles.slateGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${meal.calories} calories',
                style: const TextStyle(
                  color: AppStyles.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _macronutrientChip(
                    'P',
                    '${meal.macronutrients['protein']?.toInt() ?? 0}g',
                    AppStyles.errorRed.withOpacity(0.2),
                  ),
                  const SizedBox(width: 8),
                  _macronutrientChip(
                    'C',
                    '${meal.macronutrients['carbs']?.toInt() ?? 0}g',
                    AppStyles.successGreen.withOpacity(0.2),
                  ),
                  const SizedBox(width: 8),
                  _macronutrientChip(
                    'F',
                    '${meal.macronutrients['fat']?.toInt() ?? 0}g',
                    AppStyles.mutedBlue.withOpacity(0.2),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (meal.description != null && meal.description!.isNotEmpty)
                Text(
                  meal.description!,
                  style: const TextStyle(
                    color: AppStyles.slateGray,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _navigateToEditMeal(meal),
                    icon: Icon(Icons.edit, size: 18, color: AppStyles.primarySage),
                    label: Text('Edit', style: TextStyle(color: AppStyles.primarySage)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppStyles.primarySage,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteMeal(meal),
                    icon: Icon(Icons.delete, size: 18, color: AppStyles.errorRed),
                    label: Text('Delete', style: TextStyle(color: AppStyles.errorRed)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppStyles.errorRed,
                    ),
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
    // Define darker, more mature colors to replace the pastels
    Color chipColor;
    Color textColor = AppStyles.textDark;
    
    // Determine color based on label if not provided
    if (color == null) {
      chipColor = AppStyles.primarySage.withOpacity(0.5);
    } else if (color == AppStyles.errorRed.withOpacity(0.2)) {
      chipColor = AppStyles.errorRed; // Use errorRed for protein
    } else if (color == AppStyles.successGreen.withOpacity(0.2)) {
      chipColor = AppStyles.successGreen; // Use successGreen for carbs
    } else if (color == AppStyles.mutedBlue.withOpacity(0.2)) {
      chipColor = AppStyles.mutedBlue; // Use mutedBlue for fat
    } else if (color == AppStyles.taupeBrown.withOpacity(0.2)) {
      chipColor = AppStyles.taupeBrown; // Use taupeBrown for micronutrients
    } else {
      chipColor = color;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: chipColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: chipColor, fontWeight: FontWeight.w500),
      ),
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
                color: isOverLimit ? AppStyles.errorRed : null,
                fontWeight: FontWeight.bold,
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
                color: AppStyles.offWhite,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            // Progress indicator
            Container(
              height: 10,
              width: MediaQuery.of(context).size.width * cappedProgress * 0.8, // Account for padding
              decoration: BoxDecoration(
                color: isOverLimit 
                    ? AppStyles.errorRed
                    : (progress > 0.9 ? AppStyles.successGreen : AppStyles.mutedBlue),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper method to build the macro pill display
  Widget _buildMacronutrientPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
} 