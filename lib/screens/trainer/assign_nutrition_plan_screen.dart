import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/nutrition_plan_model.dart';
import '../../services/nutrition_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_styles.dart';

class AssignNutritionPlanScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final NutritionPlan? existingPlan;

  const AssignNutritionPlanScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    this.existingPlan,
  });

  @override
  State<AssignNutritionPlanScreen> createState() => _AssignNutritionPlanScreenState();
}

class _AssignNutritionPlanScreenState extends State<AssignNutritionPlanScreen> {
  final NutritionService _nutritionService = NutritionService();
  final AuthService _authService = AuthService();
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Macronutrients controllers
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  
  // Micronutrients controllers
  final _sodiumController = TextEditingController();
  final _cholesterolController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarController = TextEditingController();
  
  // Sample meal controllers
  final _mealNameController = TextEditingController();
  final _mealCaloriesController = TextEditingController();
  final _mealProteinController = TextEditingController();
  final _mealCarbsController = TextEditingController();
  final _mealFatController = TextEditingController();
  
  // Meal suggestion controller (legacy)
  final _mealSuggestionController = TextEditingController();
  
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  
  bool _isLoading = false;
  List<String> _mealSuggestions = [];
  List<SampleMeal> _sampleMeals = [];
  
  @override
  void initState() {
    super.initState();
    
    // If editing an existing plan, populate fields
    if (widget.existingPlan != null) {
      _nameController.text = widget.existingPlan!.name;
      _descriptionController.text = widget.existingPlan!.description ?? '';
      _caloriesController.text = widget.existingPlan!.dailyCalories.toString();
      _notesController.text = widget.existingPlan!.notes ?? '';
      
      // Populate macronutrients
      _proteinController.text = widget.existingPlan!.macronutrients['protein']?.toString() ?? '0';
      _carbsController.text = widget.existingPlan!.macronutrients['carbs']?.toString() ?? '0';
      _fatController.text = widget.existingPlan!.macronutrients['fat']?.toString() ?? '0';
      
      // Populate micronutrients
      _sodiumController.text = widget.existingPlan!.micronutrients['sodium']?.toString() ?? '0';
      _cholesterolController.text = widget.existingPlan!.micronutrients['cholesterol']?.toString() ?? '0';
      _fiberController.text = widget.existingPlan!.micronutrients['fiber']?.toString() ?? '0';
      _sugarController.text = widget.existingPlan!.micronutrients['sugar']?.toString() ?? '0';
      
      // Set dates
      _startDate = widget.existingPlan!.startDate;
      _endDate = widget.existingPlan!.endDate;
      
      // Populate meal suggestions (legacy)
      _mealSuggestions = List.from(widget.existingPlan!.mealSuggestions);
      
      // Populate sample meals
      _sampleMeals = List.from(widget.existingPlan!.sampleMeals);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _caloriesController.dispose();
    _notesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _sodiumController.dispose();
    _cholesterolController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _mealSuggestionController.dispose();
    _mealNameController.dispose();
    _mealCaloriesController.dispose();
    _mealProteinController.dispose();
    _mealCarbsController.dispose();
    _mealFatController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    // Dismiss keyboard before showing date picker
    FocusScope.of(context).unfocus();
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (pickedDate != null) {
      setState(() {
        _startDate = pickedDate;
        // If end date is before start date, reset it
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
        }
      });
    }
  }
  
  Future<void> _selectEndDate() async {
    // Dismiss keyboard before showing date picker
    FocusScope.of(context).unfocus();
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: _startDate.add(const Duration(days: 365)),
    );
    
    if (pickedDate != null) {
      setState(() {
        _endDate = pickedDate;
      });
    }
  }
  
  void _addSampleMeal() {
    final name = _mealNameController.text.trim();
    if (name.isEmpty) return;
    
    // Dismiss keyboard before processing
    FocusScope.of(context).unfocus();
    
    // Create macronutrients map
    final macronutrients = <String, double>{
      'protein': double.tryParse(_mealProteinController.text) ?? 0.0,
      'carbs': double.tryParse(_mealCarbsController.text) ?? 0.0,
      'fat': double.tryParse(_mealFatController.text) ?? 0.0,
    };
    
    // Create micronutrients map (using zeros as defaults)
    final micronutrients = <String, double>{
      'sodium': 0.0,
      'cholesterol': 0.0,
      'fiber': 0.0,
      'sugar': 0.0,
    };
    
    // Create the sample meal
    final sampleMeal = SampleMeal(
      name: name,
      calories: int.tryParse(_mealCaloriesController.text) ?? 0,
      macronutrients: macronutrients,
      micronutrients: micronutrients,
    );
    
    setState(() {
      _sampleMeals.add(sampleMeal);
      _mealNameController.clear();
      _mealCaloriesController.clear();
      _mealProteinController.clear();
      _mealCarbsController.clear();
      _mealFatController.clear();
    });
  }

  void _removeSampleMeal(int index) {
    setState(() {
      _sampleMeals.removeAt(index);
    });
  }

  // Legacy method - keep for backward compatibility
  void _addMealSuggestion() {
    final suggestion = _mealSuggestionController.text.trim();
    if (suggestion.isEmpty) return;
    
    setState(() {
      _mealSuggestions.add(suggestion);
      _mealSuggestionController.clear();
    });
  }
  
  void _removeMealSuggestion(int index) {
    setState(() {
      _mealSuggestions.removeAt(index);
    });
  }
  
    Future<void> _assignNutritionPlan() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Dismiss keyboard before processing
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = await _authService.getUserModel();
      
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
      
      // Create nutrition plan
      final nutritionPlan = NutritionPlan(
        id: widget.existingPlan?.id ?? '', // Use existing ID if editing
        clientId: widget.clientId,
        trainerId: currentUser.uid,
        name: _nameController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        dailyCalories: int.tryParse(_caloriesController.text) ?? 0,
        macronutrients: macronutrients,
        micronutrients: micronutrients,
        assignedDate: widget.existingPlan?.assignedDate ?? DateTime.now(),
        startDate: _startDate,
        endDate: _endDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        mealSuggestions: _mealSuggestions,
        sampleMeals: _sampleMeals,
      );
      
      // Create new plan or update existing one
      if (widget.existingPlan == null) {
        await _nutritionService.createNutritionPlan(nutritionPlan);
        if (mounted) {
          Navigator.pop(context, 'created');
        }
      } else {
        await _nutritionService.updateNutritionPlan(nutritionPlan);
        if (mounted) {
          Navigator.pop(context, 'updated');
        }
      }
    } catch (e) {
      print('Error saving nutrition plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving nutrition plan: $e')),
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
  
  void _confirmDeletePlan() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Nutrition Plan'),
          content: Text('Are you sure you want to delete "${widget.existingPlan!.name}"? This cannot be undone.'),
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
                setState(() {
                  _isLoading = true;
                });
                
                try {
                  await _nutritionService.deleteNutritionPlan(widget.existingPlan!.id);
                  if (mounted) {
                    // Show SnackBar on the previous screen after navigation
                    Navigator.pop(context, 'deleted');
                  }
                } catch (e) {
                  print('Error deleting nutrition plan: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting nutrition plan: $e')),
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
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingPlan != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing 
            ? 'Edit Nutrition Plan for ${widget.clientName}'
            : 'Assign Nutrition Plan to ${widget.clientName}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Plan Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Plan Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Plan Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Plan Name*',
                        hintText: 'e.g., Weight Loss Meal Plan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a plan name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Brief description of the nutrition plan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Plan Duration
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Plan Duration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Start Date
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Start Date:'),
                        ),
                        TextButton.icon(
                          onPressed: _selectStartDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(DateFormat('MM/dd/yyyy').format(_startDate)),
                        ),
                      ],
                    ),
                    
                    // End Date (Optional)
                    Row(
                      children: [
                        const Expanded(
                          child: Text('End Date (Optional):'),
                        ),
                        TextButton.icon(
                          onPressed: _selectEndDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _endDate != null
                                ? DateFormat('MM/dd/yyyy').format(_endDate!)
                                : 'No End Date',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Nutritional Values
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nutritional Targets',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Daily Calories
                    TextFormField(
                      controller: _caloriesController,
                      decoration: InputDecoration(
                        labelText: 'Daily Calories*',
                        hintText: 'e.g., 2000',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        suffixText: 'kcal',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter daily calories';
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
                            decoration: InputDecoration(
                              labelText: 'Protein',
                              hintText: '120',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _carbsController,
                            decoration: InputDecoration(
                              labelText: 'Carbs',
                              hintText: '200',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _fatController,
                            decoration: InputDecoration(
                              labelText: 'Fat',
                              hintText: '65',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Micronutrients
                    const Text(
                      'Micronutrients (mg)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Sodium, Cholesterol, Fiber, Sugar inputs
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sodiumController,
                            decoration: InputDecoration(
                              labelText: 'Sodium',
                              hintText: '2300',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                              suffixText: 'mg',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _cholesterolController,
                            decoration: InputDecoration(
                              labelText: 'Cholesterol',
                              hintText: '300',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                              suffixText: 'mg',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fiberController,
                            decoration: InputDecoration(
                              labelText: 'Fiber',
                              hintText: '25',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _sugarController,
                            decoration: InputDecoration(
                              labelText: 'Sugar',
                              hintText: '50',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Sample Meals Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sample Meals',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Add example meals with nutritional information',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Add meal name
                    TextFormField(
                      controller: _mealNameController,
                      decoration: InputDecoration(
                        labelText: 'Meal Name',
                        hintText: 'e.g., Greek Yogurt with Berries',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 12),
                    
                    // Meal nutrition details
                    Row(
                      children: [
                        // Calories
                        Expanded(
                          child: TextFormField(
                            controller: _mealCaloriesController,
                            decoration: const InputDecoration(
                              labelText: 'Calories',
                              hintText: '250',
                              suffixText: 'kcal',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Protein
                        Expanded(
                          child: TextFormField(
                            controller: _mealProteinController,
                            decoration: const InputDecoration(
                              labelText: 'Protein',
                              hintText: '20',
                              suffixText: 'g',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        // Carbs
                        Expanded(
                          child: TextFormField(
                            controller: _mealCarbsController,
                            decoration: const InputDecoration(
                              labelText: 'Carbs',
                              hintText: '30',
                              suffixText: 'g',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Fat
                        Expanded(
                          child: TextFormField(
                            controller: _mealFatController,
                            decoration: const InputDecoration(
                              labelText: 'Fat',
                              hintText: '8',
                              suffixText: 'g',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Add button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addSampleMeal,
                        icon: const Icon(Icons.restaurant),
                        label: const Text('Add Sample Meal'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: AppStyles.primarySage,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Sample meals list
                    if (_sampleMeals.isNotEmpty) ...[
                      const Text(
                        'Added Sample Meals:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                        _sampleMeals.length,
                        (index) => Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          color: Theme.of(context).colorScheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _sampleMeals[index].name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () => _removeSampleMeal(index),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('${_sampleMeals[index].calories} cal'),
                                    const SizedBox(width: 16),
                                    Text('P: ${_sampleMeals[index].macronutrients['protein']?.toInt() ?? 0}g'),
                                    const SizedBox(width: 8),
                                    Text('C: ${_sampleMeals[index].macronutrients['carbs']?.toInt() ?? 0}g'),
                                    const SizedBox(width: 8),
                                    Text('F: ${_sampleMeals[index].macronutrients['fat']?.toInt() ?? 0}g'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    if (_sampleMeals.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            'No sample meals added yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Additional Notes Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Additional Notes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Notes field
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Additional Notes (Optional)',
                        hintText: 'Any other instructions or notes for the client',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Assign Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _assignNutritionPlan,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(isEditing ? 'Update Nutrition Plan' : 'Assign Nutrition Plan'),
              ),
            ),
            
            // Delete button (only show when editing)
            if (isEditing) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _confirmDeletePlan,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Delete Nutrition Plan'),
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