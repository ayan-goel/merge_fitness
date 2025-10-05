import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/nutrition_plan_model.dart';
import '../../models/nutrition_plan_template_model.dart';
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
  final _notesController = TextEditingController();
  
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  
  bool _isLoading = false;
  bool _isLoadingTemplates = true;
  List<NutritionPlanTemplate> _templates = [];
  NutritionPlanTemplate? _selectedTemplate;
  String? _trainerId;
  
  @override
  void initState() {
    super.initState();
    _loadTrainerData();
    
    // If editing an existing plan, populate fields
    if (widget.existingPlan != null) {
      _notesController.text = widget.existingPlan!.notes ?? '';
      _startDate = widget.existingPlan!.startDate;
      _endDate = widget.existingPlan!.endDate;
    }
  }
  
  Future<void> _loadTrainerData() async {
    try {
      final user = await _authService.getUserModel();
      final templates = await _nutritionService.getTrainerNutritionTemplates(user.uid).first;
      
      setState(() {
        _trainerId = user.uid;
        _templates = templates;
        _isLoadingTemplates = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTemplates = false;
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
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
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
        }
      });
    }
  }
  
  Future<void> _selectEndDate() async {
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
  
  Future<void> _assignNutritionPlan() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a meal plan template'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.existingPlan == null) {
        // Create new nutrition plan from template
        await _nutritionService.createNutritionPlanFromTemplate(
          template: _selectedTemplate!,
          clientId: widget.clientId,
          startDate: _startDate,
          endDate: _endDate,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nutrition plan assigned successfully')),
          );
          Navigator.pop(context, 'created');
        }
      } else {
        // Update existing plan
        final updatedPlan = NutritionPlan(
          id: widget.existingPlan!.id,
          clientId: widget.clientId,
          trainerId: _trainerId!,
          name: _selectedTemplate!.name,
          description: _selectedTemplate!.description,
          dailyCalories: _selectedTemplate!.dailyCalories,
          macronutrients: Map.from(_selectedTemplate!.macronutrients),
          micronutrients: Map.from(_selectedTemplate!.micronutrients),
          assignedDate: widget.existingPlan!.assignedDate,
          startDate: _startDate,
          endDate: _endDate,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          sampleMeals: List.from(_selectedTemplate!.sampleMeals),
          mealSuggestions: List.from(_selectedTemplate!.mealSuggestions),
        );
        
        await _nutritionService.updateNutritionPlan(updatedPlan);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nutrition plan updated successfully')),
          );
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
    final isEditing = widget.existingPlan != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing 
            ? 'Edit Nutrition Plan for ${widget.clientName}'
            : 'Assign Nutrition Plan to ${widget.clientName}'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
      ),
      body: _isLoadingTemplates
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Template Selector Card
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
                              Icon(Icons.restaurant_menu, color: AppStyles.primarySage, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Select Meal Plan Template',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Choose from your saved meal plan templates',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          if (_templates.isNotEmpty)
                            DropdownButtonFormField<NutritionPlanTemplate>(
                              value: _selectedTemplate,
                              decoration: InputDecoration(
                                labelText: 'Meal Plan Template*',
                                hintText: 'Select a template',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppStyles.primarySage, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              isExpanded: true,
                              items: _templates.map((template) {
                                return DropdownMenuItem<NutritionPlanTemplate>(
                                  value: template,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          template.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${template.dailyCalories} cal',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (template) {
                                setState(() {
                                  _selectedTemplate = template;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a template';
                                }
                                return null;
                              },
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'No meal plan templates available',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange[900],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Create templates in the Templates tab first',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // Show template preview if selected
                          if (_selectedTemplate != null) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            const Text(
                              'Template Preview',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Calories banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppStyles.primarySage.withOpacity(0.1),
                                    AppStyles.primarySage.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppStyles.primarySage.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.local_fire_department, color: AppStyles.primarySage, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_selectedTemplate!.dailyCalories} calories per day',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppStyles.primarySage,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Macros preview
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMacroChip(
                                    'Protein',
                                    '${_selectedTemplate!.macronutrients['protein']?.round() ?? 0}g',
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMacroChip(
                                    'Carbs',
                                    '${_selectedTemplate!.macronutrients['carbs']?.round() ?? 0}g',
                                    Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMacroChip(
                                    'Fat',
                                    '${_selectedTemplate!.macronutrients['fat']?.round() ?? 0}g',
                                    Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Sample meals preview
                            if (_selectedTemplate!.sampleMeals.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppStyles.offWhite,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.restaurant, size: 16, color: AppStyles.slateGray),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_selectedTemplate!.sampleMeals.length} Sample Meal${_selectedTemplate!.sampleMeals.length != 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ..._selectedTemplate!.sampleMeals.take(3).map((meal) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: AppStyles.primarySage,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                meal.name,
                                                style: const TextStyle(fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${meal.calories} cal',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    if (_selectedTemplate!.sampleMeals.length > 3)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '+ ${_selectedTemplate!.sampleMeals.length - 3} more',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            
                            // Description if available
                            if (_selectedTemplate!.description != null && _selectedTemplate!.description!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedTemplate!.description!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[900],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Plan Duration Card
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
                              Icon(Icons.calendar_today, color: AppStyles.primarySage, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Plan Duration',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                                icon: const Icon(Icons.calendar_today, size: 18),
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
                                icon: const Icon(Icons.calendar_today, size: 18),
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
                  
                  // Additional Notes Card
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
                              Icon(Icons.note, color: AppStyles.primarySage, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Additional Notes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Notes field
                          TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              labelText: 'Notes (Optional)',
                              hintText: 'Any specific instructions for the client',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppStyles.primarySage, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                              isEditing ? 'Update Nutrition Plan' : 'Assign Nutrition Plan',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
    );
  }
  
  Widget _buildMacroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
