import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/assigned_workout_model.dart';
import '../../services/auth_service.dart';
import '../../services/workout_template_service.dart';
import '../../services/enhanced_workout_service.dart';
import '../../theme/app_styles.dart';
import 'workout_detail_screen.dart';

class ClientWorkoutsScreen extends StatefulWidget {
  const ClientWorkoutsScreen({super.key});

  @override
  State<ClientWorkoutsScreen> createState() => _ClientWorkoutsScreenState();
  
  // Static method to navigate to a specific workout
  static void navigateToWorkoutById(BuildContext context, String workoutId) {
    // Find the closest ClientWorkoutsScreen state
    final state = context.findAncestorStateOfType<_ClientWorkoutsScreenState>();
    if (state != null) {
      state.navigateToWorkout(workoutId);
    } else {
      // If we can't find it directly, we're not in the widgets tree
      // Create a new instance of WorkoutTemplateService to fetch the workout
      final workoutService = WorkoutTemplateService();
      
      _navigateToWorkoutWithNewService(context, workoutId, workoutService);
    }
  }
  
  // Helper method to navigate when no state is found
  static void _navigateToWorkoutWithNewService(
    BuildContext context, 
    String workoutId, 
    WorkoutTemplateService workoutService
  ) async {
    try {
      // Get current user
      final authService = AuthService();
      final user = await authService.getUserModel();
      
      // Fetch workouts
      final workouts = await workoutService.getClientWorkouts(user.uid).first;
      final workout = workouts.firstWhere(
        (w) => w.id == workoutId,
        orElse: () => throw Exception('Workout not found'),
      );
      
      // Navigate
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkoutDetailScreen(
            workout: workout,
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to workout: $e');
    }
  }
}

class _ClientWorkoutsScreenState extends State<ClientWorkoutsScreen> {
  final AuthService _authService = AuthService();
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final EnhancedWorkoutService _enhancedWorkoutService = EnhancedWorkoutService();
  
  String? _clientId;
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Upcoming', 'Completed', 'Missed'];
  
  @override
  void initState() {
    super.initState();
    _loadClientId();
  }
  
  Future<void> _loadClientId() async {
    try {
      final user = await _authService.getUserModel();
      setState(() {
        _clientId = user.uid;
      });
    } catch (e) {
      print("Error loading client ID: $e");
    }
  }
  
  // Navigate to a specific workout by ID
  void navigateToWorkout(String workoutId) async {
    if (_clientId == null) return;
    
    try {
      // Find the workout in the stream using enhanced service
      final workouts = await _enhancedWorkoutService.getClientWorkouts(_clientId!).first;
      final workout = workouts.firstWhere(
        (w) => w.id == workoutId,
        orElse: () => throw Exception('Workout not found'),
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutDetailScreen(
              workout: workout,
            ),
          ),
        ).then((_) {
          // Refresh the state when returning from workout detail
          setState(() {
            // This triggers UI refresh with latest data from stream
          });
        });
      }
    } catch (e) {
      print('Error navigating to workout: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_clientId == null) {
      return Center(
        child: CircularProgressIndicator(
          color: AppStyles.primarySage,
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Workouts'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Filters
          Container(
            color: AppStyles.offWhite,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filterOptions.map((filter) => 
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(filter),
                          selected: _selectedFilter == filter,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            }
                          },
                          selectedColor: AppStyles.primarySage.withOpacity(0.2),
                          checkmarkColor: AppStyles.primarySage,
                        ),
                      )
                    ).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Workout list
          Expanded(
            child: StreamBuilder<List<AssignedWorkout>>(
              stream: _enhancedWorkoutService.getClientWorkouts(_clientId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppStyles.primarySage,
                    ),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: AppStyles.textDark),
                    ),
                  );
                }
                
                final allWorkouts = snapshot.data ?? [];
                
                // Filter workouts based on selected filter
                final DateTime now = DateTime.now();
                final DateTime today = DateTime(now.year, now.month, now.day);
                
                final filteredWorkouts = _filterWorkouts(allWorkouts, _selectedFilter, today);
                
                if (filteredWorkouts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 64,
                          color: AppStyles.slateGray.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedFilter.toLowerCase()} workouts',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppStyles.slateGray,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filteredWorkouts.length,
                  itemBuilder: (context, index) {
                    final workout = filteredWorkouts[index];
                    return WorkoutCard(
                      workout: workout,
                      onTap: () {
                        navigateToWorkout(workout.id);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  List<AssignedWorkout> _filterWorkouts(
    List<AssignedWorkout> workouts, 
    String filter, 
    DateTime today
  ) {
    List<AssignedWorkout> filtered;
    
    switch (filter) {
      case 'Upcoming':
        filtered = workouts.where((w) => 
          (w.scheduledDate.isAfter(today) || 
          (w.scheduledDate.year == today.year && 
           w.scheduledDate.month == today.month && 
           w.scheduledDate.day == today.day)) &&
          // Exclude completed and skipped workouts from upcoming
          w.status != WorkoutStatus.completed &&
          w.status != WorkoutStatus.skipped
        ).toList();
        // Sort upcoming workouts chronologically (earliest first)
        filtered.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
        break;
      case 'Completed':
        filtered = workouts.where((w) => w.status == WorkoutStatus.completed).toList();
        // Sort completed workouts by completion date (most recent first)
        filtered.sort((a, b) {
          if (a.completedDate != null && b.completedDate != null) {
            return b.completedDate!.compareTo(a.completedDate!);
          } else if (a.completedDate != null) {
            return -1;
          } else if (b.completedDate != null) {
            return 1;
          } else {
            return b.scheduledDate.compareTo(a.scheduledDate);
          }
        });
        break;
      case 'Missed':
        filtered = workouts.where((w) => 
          // Include workouts from the past that are not completed
          (w.scheduledDate.isBefore(today) && 
           w.status != WorkoutStatus.completed && 
           w.status != WorkoutStatus.inProgress) ||
          // Also include any skipped workouts regardless of date
          w.status == WorkoutStatus.skipped
        ).toList();
        // Sort missed workouts chronologically (most recent first)
        filtered.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
        break;
      case 'All':
      default:
        filtered = workouts;
        // Sort all workouts chronologically (most recent first)
        filtered.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
        break;
    }
    
    return filtered;
  }
}

class WorkoutCard extends StatelessWidget {
  final AssignedWorkout workout;
  final VoidCallback onTap;
  
  const WorkoutCard({
    super.key,
    required this.workout,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workoutDate = DateTime(
      workout.scheduledDate.year,
      workout.scheduledDate.month,
      workout.scheduledDate.day,
    );
    
    final isPast = workoutDate.isBefore(today);
    final isToday = workoutDate.isAtSameMomentAs(today);
    
    // Different styling for training sessions vs regular workouts
    final isTrainingSession = workout.isSessionBased;
    
    return Card(
      color: AppStyles.offWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isTrainingSession 
            ? BorderSide(color: AppStyles.primarySage.withOpacity(0.2), width: 1.5)
            : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Session type icon
                  if (isTrainingSession)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppStyles.primarySage.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: AppStyles.primarySage,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppStyles.mutedBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.fitness_center,
                        size: 20,
                        color: AppStyles.mutedBlue,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.workoutName,
                          style: TextStyle(
                            fontSize: isTrainingSession ? 15 : 16,
                            fontWeight: FontWeight.bold,
                            color: AppStyles.textDark,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Row(
                          children: [
                            Icon(
                              isTrainingSession ? Icons.access_time : Icons.calendar_today,
                              size: 16,
                              color: isToday 
                                  ? AppStyles.successGreen 
                                  : (isPast ? AppStyles.errorRed : AppStyles.mutedBlue),
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              isTrainingSession
                                  ? _formatSessionTime(workout.scheduledDate)
                                  : (isToday 
                                      ? 'Today' 
                                      : DateFormat('EEEE, MMM d').format(workout.scheduledDate)),
                              style: TextStyle(
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                color: isToday 
                                    ? AppStyles.successGreen 
                                    : (isPast ? AppStyles.errorRed : AppStyles.textDark),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(context, workout.status),
                ],
              ),
              const SizedBox(height: 12.0),
              
              // Different content for sessions vs workouts
              if (!isTrainingSession)
                _buildWorkoutInfo(),
                              if (workout.notes != null && workout.notes!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isTrainingSession 
                        ? AppStyles.primarySage.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isTrainingSession ? Icons.location_on : Icons.notes,
                        color: AppStyles.slateGray,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          workout.notes!,
                          style: TextStyle(
                            color: AppStyles.textDark.withOpacity(0.8),
                            fontSize: 14,
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
    );
  }
  
  Widget _buildSessionInfo() {
    return Row(
      children: [
        Icon(
          Icons.schedule,
          size: 16,
          color: AppStyles.primarySage,
        ),
        const SizedBox(width: 4),
        Text(
          'Personal Training Session',
          style: TextStyle(
            fontSize: 14,
            color: AppStyles.primarySage,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildWorkoutInfo() {
    return Text(
      '${workout.exercises.length} exercise${workout.exercises.length > 1 ? 's' : ''}',
      style: const TextStyle(
        fontSize: 14,
        color: AppStyles.slateGray,
      ),
    );
  }
  
  String _formatSessionTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateStr;
    if (sessionDate.isAtSameMomentAs(today)) {
      dateStr = 'Today';
    } else if (sessionDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = DateFormat('MMM d').format(dateTime);
    }
    
    final timeStr = DateFormat('h:mm a').format(dateTime);
    return '$dateStr at $timeStr';
  }
  
  // Helper function to calculate progress value
  double _getWorkoutProgressValue(AssignedWorkout workout) {
    switch (workout.status) {
      case WorkoutStatus.assigned:
        return 0.0;
      case WorkoutStatus.inProgress:
        return 0.5;
      case WorkoutStatus.completed:
        return 1.0;
      case WorkoutStatus.skipped:
        return 1.0;
    }
  }
  
  // Helper function to get progress color
  Color _getProgressColor(AssignedWorkout workout, BuildContext context) {
    switch (workout.status) {
      case WorkoutStatus.assigned:
        return AppStyles.mutedBlue;
      case WorkoutStatus.inProgress:
        return AppStyles.warningAmber;
      case WorkoutStatus.completed:
        return AppStyles.successGreen;
      case WorkoutStatus.skipped:
        return AppStyles.errorRed;
    }
  }
  
  Widget _buildStatusChip(BuildContext context, WorkoutStatus status) {
    Color chipColor;
    String statusText;
    
    // Check if workout is in the past and not completed
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workoutDate = DateTime(
      workout.scheduledDate.year,
      workout.scheduledDate.month,
      workout.scheduledDate.day,
    );
    final isPast = workoutDate.isBefore(today);
    
    switch (status) {
      case WorkoutStatus.assigned:
        if (isPast) {
          // Past workouts with "assigned" status should show as "Missed"
          chipColor = AppStyles.errorRed;
          statusText = 'Missed';
        } else {
          chipColor = AppStyles.mutedBlue;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: AppStyles.textDark,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
} 