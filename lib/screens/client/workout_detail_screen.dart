import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/assigned_workout_model.dart';
import '../../models/workout_template_model.dart';
import '../../models/video_call_model.dart';
import '../../services/workout_template_service.dart';
import '../../services/video_call_service.dart';
import '../../theme/app_styles.dart';
import '../shared/video_call_screen.dart';
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
  final VideoCallService _videoCallService = VideoCallService();
  bool _isUpdating = false;
  WorkoutStatus _currentStatus = WorkoutStatus.assigned;
  VideoCall? _currentVideoCall;
  
  @override
  void initState() {
    super.initState();
    _currentStatus = widget.workout.status;
    
    // If this is a session-based workout, listen for video calls
    if (widget.workout.isSessionBased && widget.workout.sessionId != null) {
      _listenForVideoCall();
    }
  }

  void _listenForVideoCall() {
    print('Client: Listening for video calls for session ID: ${widget.workout.sessionId}');
    _videoCallService.streamVideoCallBySessionId(widget.workout.sessionId!).listen((videoCall) {
      print('Client: Video call update received: ${videoCall?.toMap()}');
      if (mounted) {
        setState(() {
          _currentVideoCall = videoCall;
        });
        
        if (videoCall != null) {
          print('Client: Video call status: ${videoCall.status}, trainerJoined: ${videoCall.trainerJoined}, clientJoined: ${videoCall.clientJoined}');
        } else {
          print('Client: No active video call found for this session');
        }
      }
    }, onError: (error) {
      print('Client: Error listening for video calls: $error');
    });
  }

  @override
  void dispose() {
    _videoCallService.dispose();
    super.dispose();
  }
  
  Future<void> _updateWorkoutStatus(WorkoutStatus status) async {
    if (_isUpdating) return;
    
    // Don't allow status updates for session-based workouts
    if (widget.workout.isSessionBased) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Training session status is managed automatically')),
        );
      }
      return;
    }
    
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

  Future<void> _joinVideoCall(VideoCall videoCall) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            callId: videoCall.id,
            isTrainer: false,
            sessionId: videoCall.sessionId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join video call: $e')),
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
                  
                  // Exercises section or Session info
                  if (widget.workout.isSessionBased) ...[
                    Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  color: AppStyles.primarySage,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Personal Training Session',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'This is a one-on-one training session with your trainer. The specific exercises and activities will be determined during the session based on your goals and progress.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppStyles.slateGray,
                                height: 1.5,
                              ),
                            ),
                            
                            // Video call button
                            if (_currentVideoCall != null) ...[
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _currentVideoCall!.trainerJoined && !_currentVideoCall!.isEnded
                                      ? () => _joinVideoCall(_currentVideoCall!)
                                      : null,
                                  icon: Icon(
                                    _currentVideoCall!.trainerJoined && !_currentVideoCall!.isEnded 
                                        ? Icons.videocam 
                                        : Icons.videocam_off,
                                    size: 20,
                                  ),
                                  label: Text(
                                    _currentVideoCall!.isEnded
                                        ? 'Video Call Ended'
                                        : _currentVideoCall!.trainerJoined
                                            ? 'Trainer has joined'
                                            : 'Waiting for trainer to start...',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _currentVideoCall!.trainerJoined && !_currentVideoCall!.isEnded
                                        ? Colors.green
                                        : AppStyles.slateGray,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppStyles.primarySage.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppStyles.primarySage.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppStyles.primarySage,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Session status is automatically managed based on the scheduled time.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppStyles.primarySage,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
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
                  ],
                  
                  const SizedBox(height: 40.0),
                ],
              ),
            ),
          ),
          
          // Bottom status control buttons
          if (!widget.workout.isSessionBased)
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
            )
          else
            // Session-based workout info
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
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: AppStyles.primarySage,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Training Session',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is a training session with your trainer. Status is managed automatically.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppStyles.slateGray,
                    ),
                  ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
    bool hasDescription = exercise.description != null && exercise.description!.isNotEmpty;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section with exercise name and video button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppStyles.primarySage,
                  AppStyles.primarySage.withOpacity(0.9),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (hasVideo)
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                    child: InkWell(
                      onTap: () => _playVideo(context, exercise.videoUrl!, exercise.name),
                      borderRadius: BorderRadius.circular(30),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Watch Demo',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Body section with sets, reps, and description
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sets and reps info card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppStyles.offWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppStyles.primarySage.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Sets info
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppStyles.primarySage.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${exercise.sets}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppStyles.primarySage,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sets',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppStyles.slateGray,
                                  ),
                                ),
                                Text(
                                  exercise.sets == 1 ? 'Set' : 'Sets',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Divider
                      Container(
                        height: 36,
                        width: 1,
                        color: AppStyles.slateGray.withOpacity(0.2),
                      ),
                      
                      // Reps info
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppStyles.mutedBlue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${exercise.reps}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppStyles.mutedBlue,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reps',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppStyles.slateGray,
                                  ),
                                ),
                                Text(
                                  exercise.reps == 1 ? 'Rep' : 'Reps',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Rest info (if available)
                      if (exercise.restSeconds != null) ...[
                        // Divider
                        Container(
                          height: 36,
                          width: 1,
                          color: AppStyles.slateGray.withOpacity(0.2),
                        ),
                        
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppStyles.softGold.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.timer_outlined,
                                  color: AppStyles.softGold,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Rest',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppStyles.slateGray,
                                    ),
                                  ),
                                  Text(
                                    '${exercise.restSeconds}s',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Description (if available)
                if (hasDescription) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppStyles.mutedBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppStyles.mutedBlue.withOpacity(0.1),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: AppStyles.mutedBlue,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Instructions',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppStyles.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          exercise.description!,
                          style: TextStyle(
                            height: 1.5,
                            color: AppStyles.textDark.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
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