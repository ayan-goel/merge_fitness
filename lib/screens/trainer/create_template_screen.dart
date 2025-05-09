import 'package:flutter/material.dart';
import '../../models/workout_template_model.dart';
import '../../services/workout_template_service.dart';
import '../../services/auth_service.dart';

class CreateTemplateScreen extends StatefulWidget {
  final WorkoutTemplate? template;

  const CreateTemplateScreen({
    super.key,
    this.template,
  });

  @override
  State<CreateTemplateScreen> createState() => _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends State<CreateTemplateScreen> {
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final AuthService _authService = AuthService();
  
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  List<ExerciseTemplate> _exercises = [];
  bool _isLoading = false;
  bool _isEditing = false;
  late String _trainerId;
  
  @override
  void initState() {
    super.initState();
    _isEditing = widget.template != null;
    _loadUserData();
    
    if (_isEditing) {
      _nameController.text = widget.template!.name;
      _descriptionController.text = widget.template?.description ?? '';
      _exercises = List.from(widget.template!.exercises);
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getUserModel();
      setState(() {
        _trainerId = user.uid;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e')),
        );
      }
    }
  }
  
  void _addExercise() async {
    final exercise = await showDialog<ExerciseTemplate>(
      context: context,
      builder: (context) => const ExerciseDialog(),
    );
    
    if (exercise != null) {
      setState(() {
        _exercises.add(exercise);
      });
    }
  }
  
  void _editExercise(int index) async {
    final exercise = await showDialog<ExerciseTemplate>(
      context: context,
      builder: (context) => ExerciseDialog(exercise: _exercises[index]),
    );
    
    if (exercise != null) {
      setState(() {
        _exercises[index] = exercise;
      });
    }
  }
  
  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }
  
  void _reorderExercises(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
    });
  }
  
  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      WorkoutTemplate template;
      
      if (_isEditing) {
        template = widget.template!.copyWith(
          name: _nameController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          exercises: _exercises,
          updatedAt: DateTime.now(),
        );
        await _workoutService.updateTemplate(template);
      } else {
        template = WorkoutTemplate.create(
          trainerId: _trainerId,
          name: _nameController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        );
        template = template.copyWith(exercises: _exercises);
        template = await _workoutService.createTemplate(template);
      }
      
      if (mounted) {
        Navigator.pop(context, template);
      }
    } catch (e) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Workout Template' : 'Create Workout Template'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Form fields
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Template Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            
            // Exercises list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Exercises',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Exercise'),
                    onPressed: _addExercise,
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _exercises.isEmpty
                  ? const Center(
                      child: Text('No exercises added yet'),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _exercises.length,
                      onReorder: _reorderExercises,
                      itemBuilder: (context, index) {
                        final exercise = _exercises[index];
                        return ExerciseListItem(
                          key: ValueKey(exercise.id),
                          exercise: exercise,
                          onEdit: () => _editExercise(index),
                          onDelete: () => _removeExercise(index),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: SizedBox(
          height: 64.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveTemplate,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(_isEditing ? 'Update Template' : 'Save Template'),
            ),
          ),
        ),
      ),
    );
  }
}

class ExerciseListItem extends StatelessWidget {
  final ExerciseTemplate exercise;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  
  const ExerciseListItem({
    super.key,
    required this.exercise,
    required this.onEdit,
    required this.onDelete,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.drag_handle),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    exercise.name,
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
            const Divider(),
            Row(
              children: [
                const Icon(Icons.fitness_center, size: 16.0),
                const SizedBox(width: 8.0),
                Text('${exercise.sets} sets × ${exercise.reps} reps'),
              ],
            ),
            if (exercise.restSeconds != null) ...[
              const SizedBox(height: 4.0),
              Row(
                children: [
                  const Icon(Icons.timer, size: 16.0),
                  const SizedBox(width: 8.0),
                  Text('Rest: ${exercise.restSeconds} seconds'),
                ],
              ),
            ],
            if (exercise.description != null && exercise.description!.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              const Divider(height: 8.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16.0, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      exercise.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ExerciseDialog extends StatefulWidget {
  final ExerciseTemplate? exercise;
  
  const ExerciseDialog({
    super.key,
    this.exercise,
  });
  
  @override
  State<ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<ExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _restController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    
    if (widget.exercise != null) {
      final e = widget.exercise!;
      _nameController.text = e.name;
      _descriptionController.text = e.description ?? '';
      _setsController.text = e.sets.toString();
      _repsController.text = e.reps.toString();
      _restController.text = e.restSeconds?.toString() ?? '';
      // Merge any existing notes into the description if both exist
      if (e.notes != null && e.notes!.isNotEmpty) {
        if (_descriptionController.text.isNotEmpty) {
          _descriptionController.text += '\n\n' + e.notes!;
        } else {
          _descriptionController.text = e.notes!;
        }
      }
    } else {
      // Default values
      _setsController.text = '3';
      _repsController.text = '10';
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _restController.dispose();
    super.dispose();
  }
  
  ExerciseTemplate _createExercise() {
    final id = widget.exercise?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    return ExerciseTemplate(
      id: id,
      name: _nameController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      sets: int.parse(_setsController.text),
      reps: int.parse(_repsController.text),
      restSeconds: _restController.text.isEmpty ? null : int.parse(_restController.text),
      notes: null, // No longer using separate notes field
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise == null ? 'Add Exercise' : 'Edit Exercise'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description/Instructions (Optional)',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _setsController,
                      decoration: const InputDecoration(
                        labelText: 'Sets',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: TextFormField(
                      controller: _repsController,
                      decoration: const InputDecoration(
                        labelText: 'Reps',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _restController,
                decoration: const InputDecoration(
                  labelText: 'Rest Seconds (Optional)',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (int.tryParse(value) == null || int.parse(value) < 0) {
                      return 'Invalid';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _createExercise());
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
} 