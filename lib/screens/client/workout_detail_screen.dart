import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/assigned_workout_model.dart';
import '../../services/workout_template_service.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final AssignedWorkout workout;
  
  const WorkoutDetailScreen({
    super.key,
    required this.workout,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  bool _isUpdating = false;
  WorkoutStatus _currentStatus = WorkoutStatus.assigned;
  final TextEditingController _feedbackController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _currentStatus = widget.workout.status;
    _feedbackController.text = widget.workout.feedback ?? '';
  }
  
  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
  
  Future<void> _updateWorkoutStatus(WorkoutStatus status) async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });
    
    try {
      await _workoutService.updateWorkoutStatus(
        widget.workout.id, 
        status,
        feedback: status == WorkoutStatus.completed ? _feedbackController.text : null,
      );
      
      setState(() {
        _currentStatus = status;
        _isUpdating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workout marked as ${_formatStatus(status)}')),
        );
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating workout: $e')),
        );
      }
    }
  }
  
  String _formatStatus(WorkoutStatus status) {
    switch (status) {
      case WorkoutStatus.assigned:
        return 'Assigned';
      case WorkoutStatus.inProgress:
        return 'In Progress';
      case WorkoutStatus.completed:
        return 'Completed';
      case WorkoutStatus.skipped:
        return 'Skipped';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.workoutName),
      ),
      body: Column(
        children: [
          // Workout info section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header card with general info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.workout.workoutName,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _buildStatusChip(context, _currentStatus),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          if (widget.workout.workoutDescription != null) ...[
                            Text(
                              'Description',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4.0),
                            Text(widget.workout.workoutDescription!),
                            const SizedBox(height: 16.0),
                          ],
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                'Scheduled: ${DateFormat('EEEE, MMMM d, yyyy').format(widget.workout.scheduledDate)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          if (widget.workout.notes != null && widget.workout.notes!.isNotEmpty) ...[
                            const SizedBox(height: 16.0),
                            Text(
                              'Trainer Notes',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4.0),
                            Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.notes, size: 16),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Text(widget.workout.notes!),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24.0),
                  
                  // Exercises section
                  Text(
                    'Exercises',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16.0),
                  
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.workout.exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = widget.workout.exercises[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    child: Text('${index + 1}'),
                                  ),
                                  const SizedBox(width: 16.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exercise.name,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4.0),
                                        Text(
                                          '${exercise.sets} sets × ${exercise.reps} reps',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (exercise.description != null && exercise.description!.isNotEmpty) ...[
                                const SizedBox(height: 12.0),
                                Text(
                                  exercise.description!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                              if (exercise.restSeconds != null) ...[
                                const SizedBox(height: 8.0),
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 16),
                                    const SizedBox(width: 4.0),
                                    Text('Rest: ${exercise.restSeconds} seconds'),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24.0),
                  
                  // Feedback section (show if completed or allow to add)
                  if (_currentStatus == WorkoutStatus.completed) ...[
                    Text(
                      'Feedback',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    TextField(
                      controller: _feedbackController,
                      decoration: InputDecoration(
                        hintText: 'How did this workout feel?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        // Auto-save feedback
                        _workoutService.updateWorkoutStatus(
                          widget.workout.id,
                          WorkoutStatus.completed,
                          feedback: value,
                        );
                      },
                    ),
                  ],
                  
                  const SizedBox(height: 40.0),
                ],
              ),
            ),
          ),
          
          // Bottom status control buttons
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_currentStatus != WorkoutStatus.inProgress && 
                    _currentStatus != WorkoutStatus.completed) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Workout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isUpdating 
                          ? null 
                          : () => _updateWorkoutStatus(WorkoutStatus.inProgress),
                    ),
                  ),
                ],
                
                if (_currentStatus == WorkoutStatus.inProgress) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isUpdating 
                          ? null 
                          : () => _updateWorkoutStatus(WorkoutStatus.completed),
                    ),
                  ),
                ],
                
                if (_currentStatus != WorkoutStatus.skipped && 
                    _currentStatus != WorkoutStatus.completed) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Skip Workout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: _isUpdating 
                          ? null 
                          : () => _updateWorkoutStatus(WorkoutStatus.skipped),
                    ),
                  ),
                ],
                
                if (_currentStatus == WorkoutStatus.completed || 
                    _currentStatus == WorkoutStatus.skipped) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Status'),
                      onPressed: _isUpdating 
                          ? null 
                          : () => _updateWorkoutStatus(WorkoutStatus.assigned),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusChip(BuildContext context, WorkoutStatus status) {
    Color chipColor;
    String statusText;
    
    switch (status) {
      case WorkoutStatus.assigned:
        chipColor = Colors.blue;
        statusText = 'To Do';
        break;
      case WorkoutStatus.inProgress:
        chipColor = Colors.orange;
        statusText = 'In Progress';
        break;
      case WorkoutStatus.completed:
        chipColor = Colors.green;
        statusText = 'Completed';
        break;
      case WorkoutStatus.skipped:
        chipColor = Colors.red;
        statusText = 'Skipped';
        break;
    }
    
    return Chip(
      label: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      backgroundColor: chipColor,
    );
  }
} 