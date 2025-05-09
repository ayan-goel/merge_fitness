import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/workout_template_model.dart';
import '../../models/assigned_workout_model.dart';
import '../../services/workout_template_service.dart';
import 'create_template_screen.dart';

class AssignWorkoutScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  const AssignWorkoutScreen({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<AssignWorkoutScreen> createState() => _AssignWorkoutScreenState();
}

class _AssignWorkoutScreenState extends State<AssignWorkoutScreen> {
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final TextEditingController _notesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  WorkoutTemplate? _selectedTemplate;
  bool _isAssigning = false;
  
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  Future<void> _assignWorkout() async {
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a workout template')),
      );
      return;
    }
    
    setState(() {
      _isAssigning = true;
    });
    
    try {
      final workout = AssignedWorkout.fromTemplate(
        clientId: widget.clientId,
        workoutTemplateId: _selectedTemplate!.id,
        template: _selectedTemplate!,
        scheduledDate: _selectedDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );
      
      await _workoutService.assignWorkout(workout);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout assigned successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning workout: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Workout to ${widget.clientName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date selection
            Text(
              'Schedule Date',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8.0),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MM/dd/yyyy').format(_selectedDate),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24.0),
            
            // Template selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Workout Template',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                  onPressed: () async {
                    final newTemplate = await Navigator.push<WorkoutTemplate>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateTemplateScreen(),
                      ),
                    );
                    
                    if (newTemplate != null) {
                      setState(() {
                        _selectedTemplate = newTemplate;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            
            StreamBuilder<List<WorkoutTemplate>>(
              stream: _workoutService.getTrainerTemplates(_workoutService.currentUserId ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final templates = snapshot.data ?? [];
                
                if (templates.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No workout templates found. Create one to get started.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<WorkoutTemplate>(
                      value: _selectedTemplate,
                      isExpanded: true,
                      hint: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('Select a workout template'),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      items: templates.map((template) {
                        return DropdownMenuItem<WorkoutTemplate>(
                          value: template,
                          child: Text(template.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTemplate = value;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24.0),
            
            // Notes
            Text(
              'Notes (Optional)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8.0),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                hintText: 'Add notes for the client',
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 32.0),
            
            // Selected template preview
            if (_selectedTemplate != null) ...[
              Text(
                'Selected Template Preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8.0),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedTemplate!.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedTemplate!.description != null) ...[
                        const SizedBox(height: 8.0),
                        Text(_selectedTemplate!.description!),
                      ],
                      const SizedBox(height: 16.0),
                      Text(
                        '${_selectedTemplate!.exercises.length} exercise${_selectedTemplate!.exercises.length != 1 ? 's' : ''}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8.0),
                      ...List.generate(_selectedTemplate!.exercises.length, (index) {
                        final exercise = _selectedTemplate!.exercises[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Text('${index + 1}. ${exercise.name}'),
                              const Spacer(),
                              Text('${exercise.sets} × ${exercise.reps}'),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 32.0),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAssigning ? null : _assignWorkout,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: _isAssigning
                    ? const CircularProgressIndicator()
                    : const Text('Assign Workout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 