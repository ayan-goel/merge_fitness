import 'package:flutter/material.dart';
import '../../models/workout_template_model.dart';
import '../../models/nutrition_plan_template_model.dart';
import '../../services/workout_template_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_styles.dart';
import 'create_template_screen.dart';
import 'video_gallery_screen.dart';
import 'create_nutrition_template_screen.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> with SingleTickerProviderStateMixin {
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final NutritionService _nutritionService = NutritionService();
  final AuthService _authService = AuthService();

  late TabController _tabController;
  String? _trainerId;
  bool _isLoading = true;
  
  // Search controllers and focus nodes
  final TextEditingController _workoutSearchController = TextEditingController();
  final TextEditingController _nutritionSearchController = TextEditingController();
  final FocusNode _workoutSearchFocusNode = FocusNode();
  final FocusNode _nutritionSearchFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrainerId();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _workoutSearchController.dispose();
    _nutritionSearchController.dispose();
    _workoutSearchFocusNode.dispose();
    _nutritionSearchFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _loadTrainerId() async {
    try {
      final user = await _authService.getUserModel();
      setState(() {
        _trainerId = user.uid;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e')),
        );
      }
    }
  }
  
  // Workout Template Methods
  void _createWorkoutTemplate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateTemplateScreen(),
      ),
    );
  }
  
  void _editWorkoutTemplate(WorkoutTemplate template) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTemplateScreen(template: template),
      ),
    );
  }
  
  void _deleteWorkoutTemplate(WorkoutTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _workoutService.deleteTemplate(template.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout template deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting template: $e')),
          );
        }
      }
    }
  }
  
  void _openVideoGallery() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VideoGalleryScreen(),
      ),
    );
  }
  
  // Filter methods
  String _normalize(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r"\s+"), ' ');
  }

  List<WorkoutTemplate> _filterWorkoutTemplates(List<WorkoutTemplate> templates) {
    final raw = _workoutSearchController.text;
    final normalizedQuery = _normalize(raw);
    if (normalizedQuery.isEmpty) return templates;

    final tokens = normalizedQuery.split(' ');
    return templates.where((template) {
      final name = _normalize(template.name);
      // Match ALL tokens against the name for stable results
      return tokens.every((t) => name.contains(t));
    }).toList();
  }
  
  List<NutritionPlanTemplate> _filterNutritionTemplates(List<NutritionPlanTemplate> templates) {
    final raw = _nutritionSearchController.text;
    final normalizedQuery = _normalize(raw);
    if (normalizedQuery.isEmpty) return templates;

    final tokens = normalizedQuery.split(' ');
    return templates.where((template) {
      final name = _normalize(template.name);
      return tokens.every((t) => name.contains(t));
    }).toList();
  }
  
  // Nutrition Template Methods
  void _createNutritionTemplate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateNutritionTemplateScreen(),
      ),
    );
  }
  
  void _editNutritionTemplate(NutritionPlanTemplate template) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateNutritionTemplateScreen(template: template),
      ),
    );
  }
  
  void _deleteNutritionTemplate(NutritionPlanTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meal Plan Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        if (template.id == null) {
          throw Exception('Template ID is null');
        }
        await _nutritionService.deleteNutritionTemplate(template.id!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal plan template deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting template: $e')),
          );
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppStyles.primarySage,
          labelColor: AppStyles.primarySage,
          unselectedLabelColor: AppStyles.slateGray,
          tabs: const [
            Tab(
              icon: Icon(Icons.fitness_center),
              text: 'Workouts',
            ),
            Tab(
              icon: Icon(Icons.restaurant_menu),
              text: 'Meal Plans',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWorkoutTemplatesTab(),
          _buildNutritionTemplatesTab(),
        ],
      ),
    );
  }
  
  Widget _buildWorkoutTemplatesTab() {
    return StreamBuilder<List<WorkoutTemplate>>(
      stream: _workoutService.getTrainerTemplates(_trainerId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final allTemplates = snapshot.data ?? [];
        
        if (allTemplates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No workout templates found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first template to get started',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _createWorkoutTemplate,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Workout Template'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyles.primarySage,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _openVideoGallery,
                  icon: const Icon(Icons.video_library),
                  label: const Text('Video Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppStyles.primarySage,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }
        
        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _workoutSearchController,
                builder: (context, value, _) {
                  final query = value.text;
                  return TextField(
                    controller: _workoutSearchController,
                    focusNode: _workoutSearchFocusNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _workoutSearchFocusNode.unfocus(),
                    decoration: InputDecoration(
                      hintText: 'Search workout templates...',
                      prefixIcon: const Icon(Icons.search, color: AppStyles.primarySage),
                      suffixIcon: value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _workoutSearchController.clear();
                                _workoutSearchFocusNode.requestFocus();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppStyles.primarySage, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  );
                },
              ),
            ),
            // Results or empty state (rebuild only when query changes)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _workoutSearchController,
              builder: (context, value, _) {
                final filtered = _filterWorkoutTemplates(allTemplates);
                if (filtered.isEmpty && value.text.isNotEmpty) {
                  return Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No templates match your search',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final template = filtered[index];
                        return WorkoutTemplateCard(
                          template: template,
                          onEdit: () => _editWorkoutTemplate(template),
                          onDelete: () => _deleteWorkoutTemplate(template),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            _buildBottomActions(
              onCreateTemplate: _createWorkoutTemplate,
              onSecondaryAction: _openVideoGallery,
              createLabel: 'Create Template',
              secondaryLabel: 'Video Gallery',
              secondaryIcon: Icons.video_library,
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildNutritionTemplatesTab() {
    return StreamBuilder<List<NutritionPlanTemplate>>(
      stream: _nutritionService.getTrainerNutritionTemplates(_trainerId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final allTemplates = snapshot.data ?? [];
        
        if (allTemplates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No meal plan templates found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first template to get started',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _createNutritionTemplate,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Meal Plan Template'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyles.primarySage,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }
        
        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nutritionSearchController,
                builder: (context, value, _) {
                  final query = value.text;
                  return TextField(
                    controller: _nutritionSearchController,
                    focusNode: _nutritionSearchFocusNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _nutritionSearchFocusNode.unfocus(),
                    decoration: InputDecoration(
                      hintText: 'Search meal plan templates...',
                      prefixIcon: const Icon(Icons.search, color: AppStyles.primarySage),
                      suffixIcon: value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _nutritionSearchController.clear();
                                _nutritionSearchFocusNode.requestFocus();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppStyles.primarySage, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  );
                },
              ),
            ),
            // Results or empty state (rebuild only when query changes)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _nutritionSearchController,
              builder: (context, value, _) {
                final filtered = _filterNutritionTemplates(allTemplates);
                if (filtered.isEmpty && value.text.isNotEmpty) {
                  return Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No templates match your search',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final template = filtered[index];
                        return NutritionTemplateCard(
                          template: template,
                          onEdit: () => _editNutritionTemplate(template),
                          onDelete: () => _deleteNutritionTemplate(template),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            _buildBottomActions(
              onCreateTemplate: _createNutritionTemplate,
              createLabel: 'Create Template',
              createIcon: Icons.add,
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildBottomActions({
    required VoidCallback onCreateTemplate,
    VoidCallback? onSecondaryAction,
    required String createLabel,
    String? secondaryLabel,
    IconData createIcon = Icons.add,
    IconData? secondaryIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: onSecondaryAction != null
          ? Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onCreateTemplate,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15.0),
                      backgroundColor: AppStyles.primarySage,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(createIcon, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          createLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSecondaryAction,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15.0),
                      backgroundColor: AppStyles.mutedBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(secondaryIcon, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          secondaryLabel!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onCreateTemplate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  backgroundColor: AppStyles.primarySage,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(createIcon, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      createLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Workout Template Card Widget
class WorkoutTemplateCard extends StatelessWidget {
  final WorkoutTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  
  const WorkoutTemplateCard({
    super.key,
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });
  
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    template.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  color: AppStyles.primarySage,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  color: Colors.red,
                ),
              ],
            ),
            if (template.description != null && template.description!.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              Text(
                template.description!,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 12.0),
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 16,
                  color: AppStyles.primarySage,
                ),
                const SizedBox(width: 4.0),
                Text(
                  '${template.exercises.length} exercise${template.exercises.length != 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppStyles.primarySage,
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Updated: ${_formatDate(template.updatedAt)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            if (template.exercises.isNotEmpty) ...[
              const SizedBox(height: 12.0),
              const Divider(),
              const SizedBox(height: 8.0),
              ...template.exercises.take(3).map((exercise) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: AppStyles.primarySage),
                      const SizedBox(width: 8.0),
                      Expanded(child: Text(exercise.name)),
                      Text(
                        '${exercise.sets} × ${exercise.reps}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppStyles.slateGray,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (template.exercises.length > 3) ...[
                const SizedBox(height: 4.0),
                Text(
                  '... and ${template.exercises.length - 3} more',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppStyles.slateGray,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// Nutrition Template Card Widget
class NutritionTemplateCard extends StatelessWidget {
  final NutritionPlanTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  
  const NutritionTemplateCard({
    super.key,
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });
  
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
  
  @override
  Widget build(BuildContext context) {
    final protein = template.macronutrients['protein']?.round() ?? 0;
    final carbs = template.macronutrients['carbs']?.round() ?? 0;
    final fat = template.macronutrients['fat']?.round() ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    template.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  color: AppStyles.primarySage,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  color: Colors.red,
                ),
              ],
            ),
            if (template.description != null && template.description!.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              Text(
                template.description!,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 12.0),
            // Calories
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppStyles.primarySage.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department, color: AppStyles.primarySage, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${template.dailyCalories} calories/day',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12.0),
            // Macros
            Row(
              children: [
                Expanded(
                  child: _buildMacroChip('Protein', '${protein}g', Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroChip('Carbs', '${carbs}g', Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroChip('Fat', '${fat}g', Colors.purple),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Icon(
                  Icons.restaurant,
                  size: 16,
                  color: AppStyles.primarySage,
                ),
                const SizedBox(width: 4.0),
                Text(
                  '${template.sampleMeals.length} sample meal${template.sampleMeals.length != 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppStyles.primarySage,
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Updated: ${_formatDate(template.updatedAt)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
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
