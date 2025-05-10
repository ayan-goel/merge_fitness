import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/assigned_workout_model.dart';
import '../../services/auth_service.dart';
import '../../services/workout_template_service.dart';
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
      // Find the workout in the stream
      final workouts = await _workoutService.getClientWorkouts(_clientId!).first;
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
      return const Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
        // Filters
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Workouts',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16.0),
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
                        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        checkmarkColor: Theme.of(context).colorScheme.primary,
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
            stream: _workoutService.getClientWorkouts(_clientId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
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
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No ${_selectedFilter.toLowerCase()} workouts',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
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
    );
  }
  
  List<AssignedWorkout> _filterWorkouts(
    List<AssignedWorkout> workouts, 
    String filter, 
    DateTime today
  ) {
    switch (filter) {
      case 'Upcoming':
        return workouts.where((w) => 
          (w.scheduledDate.isAfter(today) || 
          (w.scheduledDate.year == today.year && 
           w.scheduledDate.month == today.month && 
           w.scheduledDate.day == today.day)) &&
          // Exclude completed and skipped workouts from upcoming
          w.status != WorkoutStatus.completed &&
          w.status != WorkoutStatus.skipped
        ).toList();
      case 'Completed':
        return workouts.where((w) => w.status == WorkoutStatus.completed).toList();
      case 'Missed':
        return workouts.where((w) => 
          // Include workouts from the past that are not completed
          (w.scheduledDate.isBefore(today) && 
           w.status != WorkoutStatus.completed && 
           w.status != WorkoutStatus.inProgress) ||
          // Also include any skipped workouts regardless of date
          w.status == WorkoutStatus.skipped
        ).toList();
      case 'All':
      default:
        return workouts;
    }
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
    final bool isPast = workout.scheduledDate.isBefore(DateTime.now()) && 
                        !_isSameDay(workout.scheduledDate, DateTime.now());
    final bool isToday = _isSameDay(workout.scheduledDate, DateTime.now());
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.workoutName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: isToday 
                                  ? Colors.green 
                                  : (isPast ? Colors.red : Colors.blue),
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              isToday 
                                  ? 'Today' 
                                  : DateFormat('EEEE, MMM d').format(workout.scheduledDate),
                              style: TextStyle(
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                color: isToday 
                                    ? Colors.green 
                                    : (isPast ? Colors.red : null),
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
              Text(
                '${workout.exercises.length} exercise${workout.exercises.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16.0),
              LinearProgressIndicator(
                value: _getWorkoutProgressValue(workout),
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(workout, context)),
              ),
            ],
          ),
        ),
      ),
    );
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
        return Colors.blue;
      case WorkoutStatus.inProgress:
        return Colors.orange;
      case WorkoutStatus.completed:
        return Colors.green;
      case WorkoutStatus.skipped:
        return Colors.red;
    }
  }
  
  // Helper to check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
} 