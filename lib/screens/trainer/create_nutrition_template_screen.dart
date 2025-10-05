import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/nutrition_plan_template_model.dart';
import '../../models/nutrition_plan_model.dart';
import '../../services/nutrition_service.dart';
import '../../services/auth_service.dart';
import '../../services/food_recognition_service.dart';
import '../../theme/app_styles.dart';

class CreateNutritionTemplateScreen extends StatefulWidget {
  final NutritionPlanTemplate? template;

  const CreateNutritionTemplateScreen({
    super.key,
    this.template,
  });

  @override
  State<CreateNutritionTemplateScreen> createState() => _CreateNutritionTemplateScreenState();
}

class _CreateNutritionTemplateScreenState extends State<CreateNutritionTemplateScreen> {
  final NutritionService _nutritionService = NutritionService();
  final AuthService _authService = AuthService();
  final FoodRecognitionService _foodRecognitionService = FoodRecognitionService();
  
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
  
  // Sample meal controllers
  final _mealNameController = TextEditingController();
  final _mealCaloriesController = TextEditingController();
  final _mealProteinController = TextEditingController();
  final _mealCarbsController = TextEditingController();
  final _mealFatController = TextEditingController();
  
  bool _isLoading = false;
  bool _isGeneratingMacros = false;
  List<SampleMeal> _sampleMeals = [];
  
  @override
  void initState() {
    super.initState();
    
    // If editing an existing template, populate fields
    if (widget.template != null) {
      _nameController.text = widget.template!.name;
      _descriptionController.text = widget.template!.description ?? '';
      _caloriesController.text = widget.template!.dailyCalories.toString();
      
      // Populate macronutrients
      _proteinController.text = widget.template!.macronutrients['protein']?.toString() ?? '0';
      _carbsController.text = widget.template!.macronutrients['carbs']?.toString() ?? '0';
      _fatController.text = widget.template!.macronutrients['fat']?.toString() ?? '0';
      
      // Populate micronutrients
      _sodiumController.text = widget.template!.micronutrients['sodium']?.toString() ?? '0';
      _cholesterolController.text = widget.template!.micronutrients['cholesterol']?.toString() ?? '0';
      _fiberController.text = widget.template!.micronutrients['fiber']?.toString() ?? '0';
      _sugarController.text = widget.template!.micronutrients['sugar']?.toString() ?? '0';
      
      // Populate sample meals
      _sampleMeals = List.from(widget.template!.sampleMeals);
    }
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
    _mealNameController.dispose();
    _mealCaloriesController.dispose();
    _mealProteinController.dispose();
    _mealCarbsController.dispose();
    _mealFatController.dispose();
    super.dispose();
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
      'potassium': 0.0,
      'calcium': 0.0,
      'iron': 0.0,
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
  
  Future<void> _generateMacrosFromDescription() async {
    final mealDescription = _mealNameController.text.trim();
    if (mealDescription.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a meal description first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isGeneratingMacros = true;
    });
    
    try {
      final result = await _foodRecognitionService.analyzeFoodDescription(mealDescription);
      
      if (result.hasError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Failed to generate macros'),
              backgroundColor: AppStyles.errorRed,
            ),
          );
        }
      } else {
        // Auto-populate the fields with the AI-generated values
        setState(() {
          _mealCaloriesController.text = result.calories.round().toString();
          _mealProteinController.text = result.protein.toStringAsFixed(1);
          _mealCarbsController.text = result.carbs.toStringAsFixed(1);
          _mealFatController.text = result.fat.toStringAsFixed(1);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Macros generated successfully! Review and adjust if needed.'),
              backgroundColor: AppStyles.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingMacros = false;
        });
      }
    }
  }
  
  Future<void> _saveTemplate() async {
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
        'potassium': 0.0,
        'calcium': 0.0,
        'iron': 0.0,
      };
      
      // Create nutrition plan template
      final template = NutritionPlanTemplate(
        id: widget.template?.id,
        trainerId: currentUser.uid,
        name: _nameController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        dailyCalories: int.tryParse(_caloriesController.text) ?? 0,
        macronutrients: macronutrients,
        micronutrients: micronutrients,
        sampleMeals: _sampleMeals,
        createdAt: widget.template?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Create new template or update existing one
      if (widget.template == null) {
        await _nutritionService.createNutritionTemplate(template);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal plan template created successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        await _nutritionService.updateNutritionTemplate(template);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal plan template updated successfully')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error saving nutrition template: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving template: $e')),
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
  
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.template != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Meal Plan Template' : 'Create Meal Plan Template'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Template Details Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.label, color: AppStyles.primarySage, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Template Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Template Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Template Name*',
                        hintText: 'e.g., Weight Loss Meal Plan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppStyles.primarySage, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a template name';
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
                        hintText: 'Brief description of the meal plan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppStyles.primarySage, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Nutritional Values
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_fire_department, color: AppStyles.primarySage, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Nutritional Targets',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Daily Calories
                    TextFormField(
                      controller: _caloriesController,
                      decoration: InputDecoration(
                        labelText: 'Daily Calories*',
                        hintText: 'e.g., 2000',
                        suffixText: 'kcal',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppStyles.primarySage, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
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
                              suffixText: 'g',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _carbsController,
                            decoration: InputDecoration(
                              labelText: 'Carbs',
                              hintText: '200',
                              suffixText: 'g',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.orange, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _fatController,
                            decoration: InputDecoration(
                              labelText: 'Fat',
                              hintText: '65',
                              suffixText: 'g',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.purple, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.next,
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
                    
                    // Sodium, Cholesterol inputs
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sodiumController,
                            decoration: InputDecoration(
                              labelText: 'Sodium',
                              hintText: '2300',
                              suffixText: 'mg',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _cholesterolController,
                            decoration: InputDecoration(
                              labelText: 'Cholesterol',
                              hintText: '300',
                              suffixText: 'mg',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Fiber, Sugar inputs
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fiberController,
                            decoration: InputDecoration(
                              labelText: 'Fiber',
                              hintText: '25',
                              suffixText: 'g',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _sugarController,
                            decoration: InputDecoration(
                              labelText: 'Sugar',
                              hintText: '50',
                              suffixText: 'g',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.restaurant, color: AppStyles.primarySage, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Sample Meals',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                        labelText: 'Meal Description',
                        hintText: 'e.g., 2 eggs and a slice of whole wheat bread',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    
                    // Generate Macros Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isGeneratingMacros ? null : _generateMacrosFromDescription,
                        icon: _isGeneratingMacros
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppStyles.primarySage),
                                ),
                              )
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          _isGeneratingMacros ? 'Generating...' : 'Generate Macros with AI',
                          style: const TextStyle(fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppStyles.primarySage,
                          side: BorderSide(color: AppStyles.primarySage, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
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
                            textInputAction: TextInputAction.next,
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
                            textInputAction: TextInputAction.next,
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
                            textInputAction: TextInputAction.next,
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
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add Sample Meal'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: AppStyles.primarySage,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Sample meals list
                    if (_sampleMeals.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Added Sample Meals:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                        _sampleMeals.length,
                        (index) => Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          color: AppStyles.offWhite,
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
                                          fontSize: 15,
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppStyles.primarySage.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${_sampleMeals[index].calories} cal',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppStyles.primarySage,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('P: ${_sampleMeals[index].macronutrients['protein']?.toInt() ?? 0}g', style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 8),
                                    Text('C: ${_sampleMeals[index].macronutrients['carbs']?.toInt() ?? 0}g', style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 8),
                                    Text('F: ${_sampleMeals[index].macronutrients['fat']?.toInt() ?? 0}g', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    if (_sampleMeals.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            'No sample meals added yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTemplate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyles.primarySage,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isEditing ? 'Update Template' : 'Create Template',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

