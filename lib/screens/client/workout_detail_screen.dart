import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/assigned_workout_model.dart';
import '../../services/workout_template_service.dart';
import '../../theme/app_styles.dart';

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
      backgroundColor: AppStyles.backgroundCharcoal,
      appBar: AppBar(
        title: Text(
          widget.workout.workoutName,
          style: const TextStyle(color: AppStyles.textWhite),
        ),
        backgroundColor: AppStyles.backgroundCharcoal,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppStyles.textWhite),
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
                    color: AppStyles.surfaceCharcoal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
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
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppStyles.textWhite,
                                  ),
                                ),
                              ),
                              _buildStatusChip(context, _currentStatus),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          if (widget.workout.workoutDescription != null) ...[
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.w600,
                                color: AppStyles.textWhite,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              widget.workout.workoutDescription!,
                              style: const TextStyle(
                                color: AppStyles.textGrey,
                              ),
                            ),
                            const SizedBox(height: 16.0),
                          ],
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: AppStyles.primaryBlue,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                'Scheduled: ${DateFormat('EEEE, MMMM d, yyyy').format(widget.workout.scheduledDate)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppStyles.textGrey,
                                ),
                              ),
                            ],
                          ),
                          if (widget.workout.notes != null && widget.workout.notes!.isNotEmpty) ...[
                            const SizedBox(height: 16.0),
                            const Text(
                              'Trainer Notes',
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.w600,
                                color: AppStyles.textWhite,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: AppStyles.backgroundCharcoal,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: AppStyles.dividerGrey,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.notes, 
                                    size: 16,
                                    color: AppStyles.softGold,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Text(
                                      widget.workout.notes!,
                                      style: const TextStyle(
                                        color: AppStyles.textGrey,
                                      ),
                                    ),
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.textWhite,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.workout.exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = widget.workout.exercises[index];
                      return Card(
                        color: AppStyles.surfaceCharcoal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 12.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppStyles.primaryBlue,
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
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppStyles.textWhite,
                                          ),
                                        ),
                                        const SizedBox(height: 4.0),
                                        Text(
                                          '${exercise.sets} sets × ${exercise.reps} reps',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppStyles.textGrey,
                                          ),
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
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppStyles.textGrey,
                                  ),
                                ),
                              ],
                              if (exercise.restSeconds != null) ...[
                                const SizedBox(height: 8.0),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined, 
                                      size: 16,
                                      color: AppStyles.softGold,
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      'Rest: ${exercise.restSeconds} seconds',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppStyles.softGold,
                                      ),
                                    ),
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
                    const SizedBox(height: 24.0),
                    Text(
                      'Feedback',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.textWhite,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    TextField(
                      controller: _feedbackController,
                      decoration: InputDecoration(
                        hintText: 'How did this workout feel?',
                        hintStyle: const TextStyle(color: AppStyles.textGrey),
                        filled: true,
                        fillColor: AppStyles.inputFieldCharcoal,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: AppStyles.primaryBlue, width: 2),
                        ),
                      ),
                      style: const TextStyle(color: AppStyles.textWhite),
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
              color: AppStyles.backgroundCharcoal,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
              border: Border(
                top: BorderSide(
                  color: AppStyles.dividerGrey,
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Row(
              children: [
                if (_currentStatus != WorkoutStatus.inProgress && 
                    _currentStatus != WorkoutStatus.completed)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Workout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyles.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isUpdating ? null : () => _updateWorkoutStatus(WorkoutStatus.inProgress),
                    ),
                  ),
                
                if (_currentStatus == WorkoutStatus.inProgress)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyles.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isUpdating ? null : () => _updateWorkoutStatus(WorkoutStatus.completed),
                    ),
                  ),
                
                if (_currentStatus != WorkoutStatus.skipped && 
                    _currentStatus != WorkoutStatus.completed)
                  const SizedBox(width: 16),
                
                if (_currentStatus != WorkoutStatus.skipped && 
                    _currentStatus != WorkoutStatus.completed)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Skip Workout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppStyles.errorRed,
                        side: BorderSide(color: AppStyles.errorRed, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isUpdating ? null : () => _updateWorkoutStatus(WorkoutStatus.skipped),
                    ),
                  ),
                
                if (_currentStatus == WorkoutStatus.completed || 
                    _currentStatus == WorkoutStatus.skipped) ...[
                  if (_currentStatus == WorkoutStatus.skipped)
                    const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Status'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppStyles.primaryBlue,
                        side: BorderSide(color: AppStyles.primaryBlue, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isUpdating ? null : () => _updateWorkoutStatus(WorkoutStatus.assigned),
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
        chipColor = AppStyles.primaryBlue;
        statusText = 'To Do';
        break;
      case WorkoutStatus.inProgress:
        chipColor = AppStyles.warningAmber;
        statusText = 'In Progress';
        break;
      case WorkoutStatus.completed:
        chipColor = AppStyles.successGreen;
        statusText = 'Completed';
        break;
      case WorkoutStatus.skipped:
        chipColor = AppStyles.errorRed;
        statusText = 'Skipped';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: chipColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
} 