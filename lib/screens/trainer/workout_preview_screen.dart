import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/assigned_workout_model.dart';
import '../../models/workout_template_model.dart';
import '../../theme/app_styles.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

/// Preview screen for trainers to see what clients see for an assigned workout
/// This is a read-only view - no status updates or interactive features
class WorkoutPreviewScreen extends StatefulWidget {
  final AssignedWorkout workout;
  final String clientName;
  
  const WorkoutPreviewScreen({
    super.key,
    required this.workout,
    required this.clientName,
  });
  
  @override
  State<WorkoutPreviewScreen> createState() => _WorkoutPreviewScreenState();
}

class _WorkoutPreviewScreenState extends State<WorkoutPreviewScreen> {
  PageController? _pageController;
  int _currentExerciseIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Only initialize page controller if there are exercises
    if (widget.workout.exercises.isNotEmpty) {
      _pageController = PageController();
    }
  }
  
  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
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
  
  Widget _buildPaginationDots() {
    final exerciseCount = widget.workout.exercises.length;
    
    // Dynamic dot size based on number of exercises
    double dotSize;
    double spacing;
    
    if (exerciseCount <= 5) {
      dotSize = 10.0;
      spacing = 8.0;
    } else if (exerciseCount <= 10) {
      dotSize = 8.0;
      spacing = 6.0;
    } else if (exerciseCount <= 15) {
      dotSize = 6.0;
      spacing = 5.0;
    } else if (exerciseCount <= 20) {
      dotSize = 5.0;
      spacing = 4.0;
    } else {
      // For very large workouts, use even smaller dots
      dotSize = 4.0;
      spacing = 3.0;
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          exerciseCount,
          (index) {
            final isActive = index == _currentExerciseIndex;
            return GestureDetector(
              onTap: () {
                _pageController?.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: spacing / 2),
                width: isActive ? dotSize * 1.5 : dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: isActive 
                      ? AppStyles.primarySage 
                      : AppStyles.slateGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(dotSize / 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.offWhite,
      appBar: AppBar(
        title: const Text(
          'Workout Preview',
          style: TextStyle(
            color: AppStyles.textDark,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppStyles.offWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppStyles.textDark),
      ),
      body: Column(
        children: [
          // Preview banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(
                  color: Colors.blue.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.visibility,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preview Mode - This is what your client sees',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
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
                              _buildStatusChip(context, widget.workout.status),
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
                  
                  // Full Workout Video Section
                  if (widget.workout.fullWorkoutVideoUrl != null && widget.workout.fullWorkoutVideoUrl!.isNotEmpty) ...[
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
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppStyles.primarySage.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.play_circle_filled,
                                    color: AppStyles.primarySage,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Full Workout Video',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppStyles.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRounded(
                              radius: 12,
                              child: VideoPlayerWidget(
                                videoUrl: widget.workout.fullWorkoutVideoUrl!,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Watch the complete workout demonstration',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppStyles.slateGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                  ],
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Exercises',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.textDark,
                        ),
                      ),
                      Text(
                        '${_currentExerciseIndex + 1} of ${widget.workout.exercises.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppStyles.slateGray,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  
                  // Swipeable exercise cards with PageView
                  if (_pageController != null)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SizedBox(
                          height: MediaQuery.of(context).size.height * 0.65,
                          child: PageView.builder(
                            controller: _pageController!,
                            itemCount: widget.workout.exercises.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentExerciseIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final exercise = widget.workout.exercises[index];
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ExerciseCard(exercise: exercise),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  
                  // Pagination dots
                  if (_pageController != null) ...[
                    const SizedBox(height: 16.0),
                    Center(
                      child: _buildPaginationDots(),
                    ),
                  ],
                  
                  const SizedBox(height: 40.0),
                ],
              ),
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

// Exercise card widget for displaying exercise details
class ExerciseCard extends StatelessWidget {
  final ExerciseTemplate exercise;

  const ExerciseCard({
    super.key,
    required this.exercise,
  });

  Color _getDifficultyColor(int difficulty) {
    switch (difficulty) {
      case 1:
        return Colors.green.shade600;
      case 2:
        return Colors.lightGreen.shade600;
      case 3:
        return Colors.amber.shade600;
      case 4:
        return Colors.orange.shade600;
      case 5:
        return Colors.red.shade600;
      default:
        return AppStyles.slateGray;
    }
  }
  
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
                      maxLines: 2,
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
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: VideoPlayerWidget(videoUrl: videoUrl),
            ),
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
      child: IntrinsicHeight(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

                // Difficulty rating (if available)
                if (exercise.difficulty != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(exercise.difficulty!).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getDifficultyColor(exercise.difficulty!).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 16,
                          color: _getDifficultyColor(exercise.difficulty!),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Difficulty: ${exercise.difficulty}/5',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _getDifficultyColor(exercise.difficulty!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppStyles.slateGray.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppStyles.slateGray.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 16,
                          color: AppStyles.slateGray,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Difficulty: N/A',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppStyles.slateGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

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
                
                // Video preview (if available)
                if (hasVideo) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _playVideo(context, exercise.videoUrl!, exercise.name),
                    child: Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Video first frame
                            VideoFirstFrame(videoUrl: exercise.videoUrl!),
                            
                            // Play button overlay - minimalistic style
                            Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppStyles.primarySage,
                                  size: 48,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

// Video player widget
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
    
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: AspectRatio(
        aspectRatio: _videoPlayerController.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}

// ClipRounded widget for rounded corners
class ClipRounded extends StatelessWidget {
  final Widget child;
  final double radius;
  
  const ClipRounded({
    super.key,
    required this.child,
    required this.radius,
  });
  
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }
}

class VideoFirstFrame extends StatefulWidget {
  final String videoUrl;

  const VideoFirstFrame({super.key, required this.videoUrl});

  @override
  State<VideoFirstFrame> createState() => _VideoFirstFrameState();
}

class _VideoFirstFrameState extends State<VideoFirstFrame> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller.initialize();
      await _controller.pause();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _initialized = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(child: Icon(Icons.videocam, color: Colors.grey, size: 24)),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

