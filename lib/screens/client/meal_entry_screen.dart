import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/meal_entry_model.dart';
import '../../models/nutrition_plan_model.dart';
import '../../services/meal_service.dart';

class MealEntryScreen extends StatefulWidget {
  final MealEntry meal;
  final NutritionPlan? nutritionPlan;

  const MealEntryScreen({
    super.key,
    required this.meal,
    this.nutritionPlan,
  });

  @override
  State<MealEntryScreen> createState() => _MealEntryScreenState();
}

class _MealEntryScreenState extends State<MealEntryScreen> {
  final MealService _mealService = MealService();
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _caloriesController = TextEditingController();
  
  // Macronutrients controllers
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  
  // Micronutrients controllers
  final _sodiumController = TextEditingController();
  final _cholesterolController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarController = TextEditingController();
  
  DateTime _timeConsumed = DateTime.now();
  bool _isLoading = false;
  bool _isNewMeal = false;
  
  @override
  void initState() {
    super.initState();
    _isNewMeal = widget.meal.id.isEmpty;
    _initializeControllers();
  }
  
  void _initializeControllers() {
    _nameController.text = widget.meal.name;
    _descriptionController.text = widget.meal.description ?? '';
    _caloriesController.text = widget.meal.calories.toString();
    
    // Set macronutrients
    _proteinController.text = (widget.meal.macronutrients['protein'] ?? 0.0).toString();
    _carbsController.text = (widget.meal.macronutrients['carbs'] ?? 0.0).toString();
    _fatController.text = (widget.meal.macronutrients['fat'] ?? 0.0).toString();
    
    // Set micronutrients
    _sodiumController.text = (widget.meal.micronutrients['sodium'] ?? 0.0).toString();
    _cholesterolController.text = (widget.meal.micronutrients['cholesterol'] ?? 0.0).toString();
    _fiberController.text = (widget.meal.micronutrients['fiber'] ?? 0.0).toString();
    _sugarController.text = (widget.meal.micronutrients['sugar'] ?? 0.0).toString();
    
    // Set time consumed
    _timeConsumed = widget.meal.timeConsumed;
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _sodiumController.dispose();
    _cholesterolController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    super.dispose();
  }
  
  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timeConsumed),
    );
    
    if (pickedTime != null) {
      setState(() {
        // Keep the date, just update the time
        final now = DateTime.now();
        _timeConsumed = DateTime(
          widget.meal.date.year,
          widget.meal.date.month,
          widget.meal.date.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }
  
  Future<void> _saveMeal() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Create macronutrients map
      final macronutrients = <String, double>{
        'protein': double.tryParse(_proteinController.text) ?? 0.0,
        'carbs': double.tryParse(_carbsController.text) ?? 0.0,
        'fat': double.tryParse(_fatController.text) ?? 0.0,
      };
      
      // Create micronutrients map
      final micronutrients = <String, double>{
        'sodium': double.tryParse(_sodiumController.text) ?? 0.0,
        'cholesterol': double.tryParse(_cholesterolController.text) ?? 0.0,
        'fiber': double.tryParse(_fiberController.text) ?? 0.0,
        'sugar': double.tryParse(_sugarController.text) ?? 0.0,
      };
      
      // Create meal object
      final updatedMeal = widget.meal.copyWith(
        name: _nameController.text,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        calories: int.tryParse(_caloriesController.text) ?? 0,
        macronutrients: macronutrients,
        micronutrients: micronutrients,
        timeConsumed: _timeConsumed,
      );
      
      if (_isNewMeal) {
        await _mealService.addMealEntry(updatedMeal);
        if (mounted) {
          Navigator.pop(context, 'added');
        }
      } else {
        await _mealService.updateMealEntry(updatedMeal);
        if (mounted) {
          Navigator.pop(context, 'updated');
        }
      }
    } catch (e) {
      print('Error saving meal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving meal: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _deleteMeal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Meal'),
          content: Text('Are you sure you want to delete "${widget.meal.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                try {
                  setState(() {
                    _isLoading = true;
                  });
                  
                  await _mealService.deleteMealEntry(widget.meal.id);
                  if (mounted) {
                    Navigator.pop(context, 'deleted');
                  }
                } catch (e) {
                  print('Error deleting meal: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting meal: $e')),
                    );
                    setState(() {
                      _isLoading = false;
                    });
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
  
  void _calculateCalories() {
    // Simple calculation based on macronutrients
    // Protein: 4 calories per gram
    // Carbs: 4 calories per gram
    // Fat: 9 calories per gram
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final fat = double.tryParse(_fatController.text) ?? 0.0;
    
    final totalCalories = (protein * 4) + (carbs * 4) + (fat * 9);
    _caloriesController.text = totalCalories.round().toString();
  }
  
  // Sign out method
  Widget _buildNutrientProgressBar(String label, double value, double maxValue, String valueText) {
    // Calculate progress as a ratio (capped at 1.0 for visual display)
    final progress = maxValue > 0 ? (value / maxValue) : 0.0;
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
              width: MediaQuery.of(context).size.width * cappedProgress * 0.6, // Account for padding
              decoration: BoxDecoration(
                color: isOverLimit 
                    ? Colors.red 
                    : (progress > 0.9 ? Colors.green : Theme.of(context).colorScheme.primary),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isEditing = !_isNewMeal;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Meal' : 'Add New Meal'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete meal',
              onPressed: _deleteMeal,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Meal Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Meal Name*',
                hintText: 'e.g., Breakfast, Chicken Salad',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a meal name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Time Consumed
            Row(
              children: [
                const Text('Time Consumed:'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _selectTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(DateFormat.jm().format(_timeConsumed)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'e.g., Homemade meal with fresh ingredients',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            // Nutritional Information card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nutritional Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Calories
                    TextFormField(
                      controller: _caloriesController,
                      decoration: const InputDecoration(
                        labelText: 'Calories*',
                        hintText: 'e.g., 500',
                        border: OutlineInputBorder(),
                        suffixText: 'kcal',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter calories';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Macronutrients
                    const Text(
                      'Macronutrients (g)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Protein, Carbs, Fat inputs
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _proteinController,
                            decoration: const InputDecoration(
                              labelText: 'Protein',
                              hintText: '20',
                              border: OutlineInputBorder(),
                              suffixText: 'g',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _carbsController,
                            decoration: const InputDecoration(
                              labelText: 'Carbs',
                              hintText: '50',
                              border: OutlineInputBorder(),
                              suffixText: 'g',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _fatController,
                            decoration: const InputDecoration(
                              labelText: 'Fat',
                              hintText: '15',
                              border: OutlineInputBorder(),
                              suffixText: 'g',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Micronutrients
                    const Text(
                      'Micronutrients',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Sodium, Cholesterol
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sodiumController,
                            decoration: const InputDecoration(
                              labelText: 'Sodium',
                              hintText: '500',
                              border: OutlineInputBorder(),
                              suffixText: 'mg',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _cholesterolController,
                            decoration: const InputDecoration(
                              labelText: 'Cholesterol',
                              hintText: '60',
                              border: OutlineInputBorder(),
                              suffixText: 'mg',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Fiber, Sugar
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fiberController,
                            decoration: const InputDecoration(
                              labelText: 'Fiber',
                              hintText: '5',
                              border: OutlineInputBorder(),
                              suffixText: 'g',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _sugarController,
                            decoration: const InputDecoration(
                              labelText: 'Sugar',
                              hintText: '10',
                              border: OutlineInputBorder(),
                              suffixText: 'g',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Show nutritional targets if they exist
            if (widget.nutritionPlan != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Nutrition Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'This meal compared to your daily targets',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildNutrientProgressBar(
                        'Calories', 
                        double.tryParse(_caloriesController.text) ?? 0.0, 
                        widget.nutritionPlan!.dailyCalories.toDouble(), 
                        '${_caloriesController.text.isEmpty ? "0" : _caloriesController.text} / ${widget.nutritionPlan!.dailyCalories} kcal'
                      ),
                      _buildNutrientProgressBar(
                        'Protein', 
                        double.tryParse(_proteinController.text) ?? 0.0, 
                        widget.nutritionPlan!.macronutrients['protein'] ?? 0.0, 
                        '${_proteinController.text.isEmpty ? "0" : _proteinController.text} / ${widget.nutritionPlan!.macronutrients['protein']?.toStringAsFixed(1) ?? "0"} g'
                      ),
                      _buildNutrientProgressBar(
                        'Carbs', 
                        double.tryParse(_carbsController.text) ?? 0.0, 
                        widget.nutritionPlan!.macronutrients['carbs'] ?? 0.0, 
                        '${_carbsController.text.isEmpty ? "0" : _carbsController.text} / ${widget.nutritionPlan!.macronutrients['carbs']?.toStringAsFixed(1) ?? "0"} g'
                      ),
                      _buildNutrientProgressBar(
                        'Fat', 
                        double.tryParse(_fatController.text) ?? 0.0, 
                        widget.nutritionPlan!.macronutrients['fat'] ?? 0.0, 
                        '${_fatController.text.isEmpty ? "0" : _fatController.text} / ${widget.nutritionPlan!.macronutrients['fat']?.toStringAsFixed(1) ?? "0"} g'
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveMeal,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(isEditing ? 'Update Meal' : 'Add Meal'),
              ),
            ),
            
            // Delete button (only when editing)
            if (isEditing) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _deleteMeal,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Delete Meal'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 