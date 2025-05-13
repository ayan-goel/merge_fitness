import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/meal_entry_model.dart';
import '../../models/nutrition_plan_model.dart';
import '../../services/meal_service.dart';
import '../../services/nutrition_service.dart';

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
      body: Column(
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
                          _macronutrientChip('Protein', '${_activePlan!.macronutrients['protein']?.toInt() ?? 0}g'),
                          const SizedBox(width: 8),
                          _macronutrientChip('Carbs', '${_activePlan!.macronutrients['carbs']?.toInt() ?? 0}g'),
                          const SizedBox(width: 8),
                          _macronutrientChip('Fat', '${_activePlan!.macronutrients['fat']?.toInt() ?? 0}g'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Meals list
          Expanded(
            child: StreamBuilder<List<MealEntry>>(
              stream: _mealService.getClientMealsForDate(widget.clientId, _selectedDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final meals = snapshot.data ?? [];

                if (meals.isEmpty) {
                  return Center(
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
                        Text(
                          'The client has not logged any meals for ${isToday ? 'today' : DateFormat('MMM d, yyyy').format(_selectedDate)}.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: meals.length,
                  itemBuilder: (context, index) {
                    final meal = meals[index];
                    return _buildMealCard(meal);
                  },
                );
              },
            ),
          ),
          
          // Daily nutrition progress
          if (_activePlan != null)
            StreamBuilder<Map<String, double>>(
              stream: _mealService.calculateNutritionProgress(widget.clientId, _selectedDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final progress = snapshot.data ?? {
                  'calories': 0.0,
                  'protein': 0.0,
                  'carbs': 0.0,
                  'fat': 0.0,
                };
                return Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
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
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
  
  Widget _buildMealCard(MealEntry meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
            
            const SizedBox(height: 12),
            
            // Macronutrients section
            Text(
              'Macronutrients:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
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
            
            // Micronutrients section
            const SizedBox(height: 12),
            if (meal.micronutrients.isNotEmpty) ...[
              Text(
                'Micronutrients:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
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
            
            const SizedBox(height: 8),
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