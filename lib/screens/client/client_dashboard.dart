import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/assigned_workout_model.dart';
import '../../services/auth_service.dart';
import '../../services/workout_template_service.dart';
import 'workout_detail_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final AuthService _authService = AuthService();
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  
  UserModel? _client;
  bool _isLoading = true;
  int _streak = 0;
  int _completionPercentage = 0;
  
  @override
  void initState() {
    super.initState();
    _loadClientData();
  }
  
  Future<void> _loadClientData() async {
    try {
      final user = await _authService.getUserModel();
      
      setState(() {
        _client = user;
        _isLoading = false;
      });
      
      // Calculate stats after we have the client ID
      if (_client != null) {
        _calculateStats();
      }
    } catch (e) {
      print("Error loading client data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _calculateStats() async {
    if (_client == null) return;
    
    try {
      // Get all workouts for the client
      final workoutsStream = _workoutService.getClientWorkouts(_client!.uid);
      final workouts = await workoutsStream.first;
      
      // Calculate streak
      final streak = _calculateStreak(workouts);
      
      // Calculate completion percentage
      final percentage = _calculateCompletionPercentage(workouts);
      
      if (mounted) {
        setState(() {
          _streak = streak;
          _completionPercentage = percentage;
        });
      }
    } catch (e) {
      print("Error calculating stats: $e");
    }
  }
  
  int _calculateStreak(List<AssignedWorkout> workouts) {
    // Sort workouts by scheduled date descending
    final sortedWorkouts = List<AssignedWorkout>.from(workouts);
    sortedWorkouts.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    
    int streak = 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    // Check if there's a workout completed today
    bool hasCompletedTodayWorkout = sortedWorkouts.any((w) => 
      _isSameDay(w.scheduledDate, todayDate) && 
      w.status == WorkoutStatus.completed
    );
    
    // Start checking from yesterday
    var currentDate = todayDate.subtract(const Duration(days: 1));
    
    // If no workout today, start streak calculation from today
    if (!hasCompletedTodayWorkout) {
      currentDate = todayDate;
    } else {
      // Today is already part of the streak
      streak = 1;
    }
    
    // Count consecutive days with completed workouts
    while (true) {
      final workoutsOnDate = sortedWorkouts.where((w) => _isSameDay(w.scheduledDate, currentDate)).toList();
      
      // If no workouts scheduled for this date, or any workout not completed, break the streak
      if (workoutsOnDate.isEmpty || !workoutsOnDate.any((w) => w.status == WorkoutStatus.completed)) {
        break;
      }
      
      // Increment streak and move to previous day
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }
  
  int _calculateCompletionPercentage(List<AssignedWorkout> workouts) {
    if (workouts.isEmpty) return 0;
    
    // Only consider workouts that are in the past or today
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    final pastWorkouts = workouts.where((w) => 
      w.scheduledDate.isBefore(todayDate.add(const Duration(days: 1)))
    ).toList();
    
    if (pastWorkouts.isEmpty) return 0;
    
    // Count completed workouts
    final completedWorkouts = pastWorkouts.where((w) => 
      w.status == WorkoutStatus.completed
    ).length;
    
    // Calculate percentage
    return ((completedWorkouts / pastWorkouts.length) * 100).round();
  }
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_client == null) {
      return const Center(child: Text('Error loading user data'));
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${_client!.displayName ?? 'Client'}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Today is ${DateFormat('EEEE, MMMM d').format(DateTime.now())}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Today's Workout
          Text(
            "Today's Workout",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          // Stream builder for today's workouts
          Expanded(
            child: StreamBuilder<List<AssignedWorkout>>(
              stream: _workoutService.getCurrentWorkouts(_client!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                
                final workouts = snapshot.data ?? [];
                
                if (workouts.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No workouts scheduled for today',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: workouts.length,
                  itemBuilder: (context, index) {
                    final workout = workouts[index];
                    return TodayWorkoutCard(
                      workout: workout,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkoutDetailScreen(
                              workout: workout,
                            ),
                          ),
                        ).then((_) {
                          // Recalculate stats when returning from workout detail
                          _calculateStats();
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Today's Stats
          Text(
            'Your Progress',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              _buildStatCard(
                context, 
                title: 'Streak', 
                value: '$_streak ${_streak == 1 ? 'day' : 'days'}',
                icon: Icons.local_fire_department,
                color: Colors.orange,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                context, 
                title: 'Completion', 
                value: '$_completionPercentage%',
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TodayWorkoutCard extends StatelessWidget {
  final AssignedWorkout workout;
  final VoidCallback onTap;
  
  const TodayWorkoutCard({
    super.key,
    required this.workout,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
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
                    child: Text(
                      workout.workoutName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(context, workout.status),
                ],
              ),
              if (workout.workoutDescription != null && workout.workoutDescription!.isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Text(workout.workoutDescription!),
              ],
              const SizedBox(height: 16.0),
              Row(
                children: [
                  const Icon(Icons.fitness_center, size: 16),
                  const SizedBox(width: 4.0),
                  Text('${workout.exercises.length} exercise${workout.exercises.length > 1 ? 's' : ''}'),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ],
          ),
        ),
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
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
} 