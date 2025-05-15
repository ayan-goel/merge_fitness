import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/meal_entry_model.dart';
import '../../models/nutrition_plan_model.dart';
import '../../services/meal_service.dart';
import '../../services/nutrition_service.dart';
import '../../theme/app_styles.dart';

class ClientMealHistoryScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final DateTime? initialDate;

  const ClientMealHistoryScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    this.initialDate,
  });

  @override
  State<ClientMealHistoryScreen> createState() => _ClientMealHistoryScreenState();
}

class _ClientMealHistoryScreenState extends State<ClientMealHistoryScreen> {
  final MealService _mealService = MealService();
  final NutritionService _nutritionService = NutritionService();
  
  late DateTime _selectedDate;
  NutritionPlan? _activePlan;
  
  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadActivePlan();
  }
  
  Future<void> _loadActivePlan() async {
    try {
      final plan = await _nutritionService.getCurrentNutritionPlan(widget.clientId);
      if (mounted) {
        setState(() {
          _activePlan = plan;
        });
      }
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
  
  @override
  Widget build(BuildContext context) {
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.clientName}\'s Meals'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
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
              
              const SizedBox(height: 16),
              
              // Active nutrition plan display
              if (_activePlan != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _macronutrientChip('Protein', '${_activePlan!.macronutrients['protein']?.toInt() ?? 0}g'),
                                const SizedBox(width: 8),
                                _macronutrientChip('Carbs', '${_activePlan!.macronutrients['carbs']?.toInt() ?? 0}g'),
                                const SizedBox(width: 8),
                                _macronutrientChip('Fat', '${_activePlan!.macronutrients['fat']?.toInt() ?? 0}g'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Meals list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Meals',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              StreamBuilder<List<MealEntry>>(
                stream: _mealService.getClientMealsForDate(widget.clientId, _selectedDate),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator())
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Error: ${snapshot.error}'),
                      ),
                    );
                  }

                  final meals = snapshot.data ?? [];

                  if (meals.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        child: SizedBox(
                          height: 200,
                          child: Center(
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
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text(
                                    'The client has not logged any meals for ${isToday ? 'today' : DateFormat('MMM d, yyyy').format(_selectedDate)}.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: meals.map((meal) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildMealCard(meal),
                      )).toList(),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              // Daily nutrition progress
              if (_activePlan != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Daily Progress',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                StreamBuilder<Map<String, double>>(
                  stream: _mealService.calculateNutritionProgress(widget.clientId, _selectedDate),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const SizedBox(
                        height: 150,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final progress = snapshot.data ?? {
                      'calories': 0.0,
                      'protein': 0.0,
                      'carbs': 0.0,
                      'fat': 0.0,
                    };
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Calories progress
                              _buildNutrientProgressBar(
                                'Calories',
                                progress['calories'] ?? 0.0,
                                '${(progress['calories'] ?? 0.0) * _activePlan!.dailyCalories ~/ 1} / ${_activePlan!.dailyCalories} kcal',
                              ),
                              const SizedBox(height: 16),
                              
                              // Macronutrients
                              _buildNutrientProgressBar(
                                'Protein',
                                progress['protein'] ?? 0.0,
                                '${((progress['protein'] ?? 0.0) * (_activePlan!.macronutrients['protein'] ?? 0)).toStringAsFixed(1)} / ${_activePlan!.macronutrients['protein']?.toStringAsFixed(1) ?? 0} g',
                              ),
                              const SizedBox(height: 12),
                              _buildNutrientProgressBar(
                                'Carbs',
                                progress['carbs'] ?? 0.0,
                                '${((progress['carbs'] ?? 0.0) * (_activePlan!.macronutrients['carbs'] ?? 0)).toStringAsFixed(1)} / ${_activePlan!.macronutrients['carbs']?.toStringAsFixed(1) ?? 0} g',
                              ),
                              const SizedBox(height: 12),
                              _buildNutrientProgressBar(
                                'Fat',
                                progress['fat'] ?? 0.0,
                                '${((progress['fat'] ?? 0.0) * (_activePlan!.macronutrients['fat'] ?? 0)).toStringAsFixed(1)} / ${_activePlan!.macronutrients['fat']?.toStringAsFixed(1) ?? 0} g',
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMealCard(MealEntry meal) {
    return Card(
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
            
            // Calories - more prominently displayed
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${meal.calories} calories',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Macronutrients section
            Text(
              'Macronutrients:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _macronutrientChip(
                    'Protein',
                    '${meal.macronutrients['protein']?.toInt() ?? 0}g',
                    Colors.red.shade100,
                  ),
                  const SizedBox(width: 8),
                  _macronutrientChip(
                    'Carbs',
                    '${meal.macronutrients['carbs']?.toInt() ?? 0}g',
                    Colors.green.shade100,
                  ),
                  const SizedBox(width: 8),
                  _macronutrientChip(
                    'Fat',
                    '${meal.macronutrients['fat']?.toInt() ?? 0}g',
                    Colors.blue.shade100,
                  ),
                ],
              ),
            ),
            
            // Micronutrients section
            if (meal.micronutrients.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Micronutrients:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (meal.micronutrients['sodium'] != null)
                    _macronutrientChip(
                      'Sodium',
                      '${meal.micronutrients['sodium']?.toInt() ?? 0}mg',
                      Colors.purple.shade100,
                    ),
                  if (meal.micronutrients['cholesterol'] != null)
                    _macronutrientChip(
                      'Cholesterol',
                      '${meal.micronutrients['cholesterol']?.toInt() ?? 0}mg',
                      Colors.purple.shade100,
                    ),
                  if (meal.micronutrients['fiber'] != null)
                    _macronutrientChip(
                      'Fiber',
                      '${meal.micronutrients['fiber']?.toInt() ?? 0}g',
                      Colors.purple.shade100,
                    ),
                  if (meal.micronutrients['sugar'] != null)
                    _macronutrientChip(
                      'Sugar',
                      '${meal.micronutrients['sugar']?.toInt() ?? 0}g',
                      Colors.purple.shade100,
                    ),
                ],
              ),
            ],
            
            const SizedBox(height: 12),
            if (meal.description != null && meal.description!.isNotEmpty)
              Text(
                meal.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _macronutrientChip(String label, String value, [Color? color]) {
    // Use pastel colors similar to the client side
    Color chipColor;
    Color textColor = AppStyles.textDark; // Use dark text instead of light
    
    // Determine color based on label if not provided
    if (color == null) {
      chipColor = AppStyles.primarySage;
    } else if (color == Colors.red.shade100) {
      chipColor = AppStyles.errorRed; // Use errorRed for protein (consistent with client view)
    } else if (color == Colors.green.shade100) {
      chipColor = AppStyles.successGreen; // Use successGreen for carbs
    } else if (color == Colors.blue.shade100) {
      chipColor = AppStyles.mutedBlue; // Use mutedBlue for fat
    } else if (color == Colors.purple.shade100) {
      chipColor = AppStyles.taupeBrown; // Use taupeBrown for micronutrients
    } else {
      chipColor = color;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2), // Use 0.2 opacity for pastel look
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: chipColor.withOpacity(0.5), // Use 0.5 opacity for border
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label, 
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 8),
            Text(
              valueText,
              style: TextStyle(
                color: isOverLimit ? AppStyles.errorRed : null,
                fontWeight: isOverLimit ? FontWeight.bold : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Stack(
                children: [
                  Container(
                    height: 12,
                    width: constraints.maxWidth * cappedProgress,
                    decoration: BoxDecoration(
                      color: isOverLimit 
                          ? AppStyles.errorRed.withOpacity(0.8)
                          : (progress > 0.9 ? AppStyles.successGreen.withOpacity(0.8) : AppStyles.primarySage.withOpacity(0.8)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            );
          }
        ),
      ],
    );
  }
} 