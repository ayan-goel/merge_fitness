import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/assigned_workout_model.dart';
import '../../models/workout_template_model.dart';
import '../../services/workout_template_service.dart';
import '../../theme/app_styles.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

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
  
  @override
  void initState() {
    super.initState();
    _currentStatus = widget.workout.status;
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
      backgroundColor: AppStyles.offWhite,
      appBar: AppBar(
        title: Text(
          widget.workout.workoutName,
          style: const TextStyle(color: AppStyles.textDark),
        ),
        backgroundColor: AppStyles.offWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppStyles.textDark),
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
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 1,
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
                                    color: AppStyles.textDark,
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
                                color: AppStyles.textDark,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              widget.workout.workoutDescription!,
                              style: const TextStyle(
                                color: AppStyles.slateGray,
                              ),
                            ),
                            const SizedBox(height: 16.0),
                          ],
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: AppStyles.primarySage,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                'Scheduled: ${DateFormat('EEEE, MMMM d, yyyy').format(widget.workout.scheduledDate)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppStyles.slateGray,
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
                                color: AppStyles.textDark,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: AppStyles.offWhite,
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
                                        color: AppStyles.slateGray,
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
                      color: AppStyles.textDark,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.workout.exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = widget.workout.exercises[index];
                      return ExerciseCard(exercise: exercise);
                    },
                  ),
                  
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
                  offset: const Offset(0, -1),
                ),
              ],
              border: Border(
                top: BorderSide(
                  color: AppStyles.dividerGrey,
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 30.0),
            margin: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                if (_currentStatus != WorkoutStatus.inProgress && 
                    _currentStatus != WorkoutStatus.completed)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Workout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyles.primarySage,
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
                        foregroundColor: AppStyles.primarySage,
                        side: BorderSide(color: AppStyles.primarySage, width: 1.5),
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
    
    // Check if workout is in the past and not completed
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workoutDate = DateTime(
      widget.workout.scheduledDate.year,
      widget.workout.scheduledDate.month,
      widget.workout.scheduledDate.day,
    );
    final isPast = workoutDate.isBefore(today);
    
    switch (status) {
      case WorkoutStatus.assigned:
        if (isPast) {
          // Past workouts with "assigned" status should show as "Missed"
          chipColor = AppStyles.errorRed;
          statusText = 'Missed';
        } else {
          chipColor = AppStyles.primarySage;
          statusText = 'To Do';
        }
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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12.0,
        ),
      ),
    );
  }
}

// Add this new widget for display exercise with video support
class ExerciseCard extends StatelessWidget {
  final ExerciseTemplate exercise;
  
  const ExerciseCard({
    super.key,
    required this.exercise,
  });
  
  void _playVideo(BuildContext context, String videoUrl, String exerciseName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      exerciseName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            VideoPlayerWidget(videoUrl: videoUrl),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    bool hasVideo = exercise.videoUrl != null && exercise.videoUrl!.isNotEmpty;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppStyles.primarySage,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (hasVideo)
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                      tooltip: 'View Demo Video',
                      onPressed: () => _playVideo(context, exercise.videoUrl!, exercise.name),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${exercise.sets} sets × ${exercise.reps} reps',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppStyles.textDark.withOpacity(0.8),
                          ),
                        ),
                      ),
                      if (exercise.restSeconds != null)
                        Text(
                          'Rest: ${exercise.restSeconds}s',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppStyles.textDark.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                  if (exercise.description != null && exercise.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      exercise.description!,
                      style: TextStyle(
                        color: AppStyles.textDark.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  
  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }
  
  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    
    try {
      await _videoPlayerController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing video: $e')),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    return AspectRatio(
      aspectRatio: _videoPlayerController.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }
}

// Replace the existing _buildExerciseCard method with this to use our new ExerciseCard widget
Widget _buildExerciseCard(BuildContext context, ExerciseTemplate exercise) {
  return ExerciseCard(exercise: exercise);
} 