import 'package:flutter/material.dart';
import '../../models/workout_template_model.dart';
import '../../services/workout_template_service.dart';
import '../../services/auth_service.dart';
import 'create_template_screen.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final AuthService _authService = AuthService();

  String? _trainerId;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadTrainerId();
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
  
  void _createTemplate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateTemplateScreen(),
      ),
    );
  }
  
  void _editTemplate(WorkoutTemplate template) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTemplateScreen(template: template),
      ),
    );
  }
  
  void _deleteTemplate(WorkoutTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
            const SnackBar(content: Text('Template deleted successfully')),
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
      body: StreamBuilder<List<WorkoutTemplate>>(
        stream: _workoutService.getTrainerTemplates(_trainerId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final templates = snapshot.data ?? [];
          
          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No workout templates found',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _createTemplate,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Template'),
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: () async {
              // The stream will automatically refresh the data
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return TemplateCard(
                  template: template,
                  onEdit: () => _editTemplate(template),
                  onDelete: () => _deleteTemplate(template),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTemplate,
        tooltip: 'Create Template',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TemplateCard extends StatelessWidget {
  final WorkoutTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  
  const TemplateCard({
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
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
            if (template.description != null && template.description!.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              Text(template.description!),
            ],
            const SizedBox(height: 8.0),
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4.0),
                Text(
                  '${template.exercises.length} exercise${template.exercises.length != 1 ? 's' : ''}',
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Updated: ${_formatDate(template.updatedAt)}',
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            if (template.exercises.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8.0),
              ...template.exercises.take(3).map((exercise) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8),
                      const SizedBox(width: 8.0),
                      Expanded(child: Text(exercise.name)),
                      Text('${exercise.sets} × ${exercise.reps}'),
                    ],
                  ),
                );
              }),
              if (template.exercises.length > 3) ...[
                const SizedBox(height: 4.0),
                Text(
                  '... and ${template.exercises.length - 3} more',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
} 