import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/assigned_workout_model.dart';
import '../../services/auth_service.dart';
import '../../services/workout_template_service.dart';
import '../../services/weight_service.dart';
import '../../services/calendly_service.dart';
import '../../models/weight_entry_model.dart';
import '../../models/session_model.dart';
import 'workout_detail_screen.dart';
import 'schedule_session_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final AuthService _authService = AuthService();
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final WeightService _weightService = WeightService();
  final CalendlyService _calendlyService = CalendlyService();
  
  UserModel? _client;
  UserModel? _trainer; // Client's assigned trainer
  bool _isLoading = true;
  int _streak = 0;
  int _completionPercentage = 0;
  
  // Weight tracking
  WeightEntry? _todayWeightEntry;
  WeightEntry? _latestWeightEntry;
  final TextEditingController _weightController = TextEditingController();
  bool _isSubmittingWeight = false;
  
  // Session tracking
  List<TrainingSession> _upcomingSessions = [];
  
  @override
  void initState() {
    super.initState();
    _loadClientData();
  }
  
  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
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
        _loadWeightData();
        _loadTrainerData();
        _loadUpcomingSessions();
      }
    } catch (e) {
      print("Error loading client data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Load trainer data
  Future<void> _loadTrainerData() async {
    try {
      if (_client?.trainerId == null) return;
      
      final trainerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_client!.trainerId)
          .get();
      
      if (trainerDoc.exists) {
        setState(() {
          _trainer = UserModel.fromMap(
            trainerDoc.data() as Map<String, dynamic>,
            uid: trainerDoc.id,
            email: trainerDoc.data()?['email'] ?? '',
          );
        });
      }
    } catch (e) {
      print("Error loading trainer data: $e");
    }
  }
  
  // Load upcoming sessions
  Future<void> _loadUpcomingSessions() async {
    try {
      if (_client == null) return;
      
      final sessions = await _calendlyService.getClientUpcomingSessions(_client!.uid);
      setState(() {
        _upcomingSessions = sessions;
      });
    } catch (e) {
      print("Error loading upcoming sessions: $e");
    }
  }
  
  // Load weight data for the client
  Future<void> _loadWeightData() async {
    try {
      final todayEntry = await _weightService.getTodayWeightEntry();
      final latestEntry = await _weightService.getLatestWeightEntry();
      
      setState(() {
        _todayWeightEntry = todayEntry;
        _latestWeightEntry = latestEntry;
        
        // Pre-fill with latest weight if available and no entry today
        if (todayEntry == null && latestEntry != null) {
          // Show weight in pounds
          _weightController.text = latestEntry.weightInPounds.toStringAsFixed(1);
        }
      });
    } catch (e) {
      print("Error loading weight data: $e");
    }
  }
  
  // Submit weight entry
  Future<void> _submitWeightEntry() async {
    if (_weightController.text.isEmpty) return;
    
    try {
      final weightInPounds = double.parse(_weightController.text);
      if (weightInPounds <= 0) return;
      
      setState(() {
        _isSubmittingWeight = true;
      });
      
      // Add weight entry in pounds
      final entry = await _weightService.addWeightEntryInPounds(weightInPounds, user: _client);
      
      setState(() {
        _todayWeightEntry = entry;
        _isSubmittingWeight = false;
        _weightController.clear();
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weight entry saved!')),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmittingWeight = false;
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving weight: $e')),
        );
      }
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
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
              
              // Upcoming Sessions Section
              if (_trainer != null) ... [
                Text(
                  'Training Sessions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                
                // Show upcoming session if available
                if (_upcomingSessions.isNotEmpty) ...[
                  _buildUpcomingSessionCard(_upcomingSessions.first),
                ],
                
                // Schedule button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScheduleSessionScreen(
                            clientId: _client!.uid,
                            trainerId: _trainer!.uid,
                            trainerName: _trainer!.displayName ?? 'Your Trainer',
                          ),
                        ),
                      ).then((_) {
                        // Refresh sessions on return
                        _loadUpcomingSessions();
                      });
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(_upcomingSessions.isEmpty 
                      ? 'Schedule a session with ${_trainer!.displayName}'
                      : 'Schedule another session'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
              ],
              
              // Weight Entry Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.monitor_weight_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Track Your Weight',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (_todayWeightEntry != null) ...[
                        // Show today's entry with improved styling
                        Card(
                          color: Colors.green.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.green.shade300, width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Weight recorded for today!',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_todayWeightEntry!.weightInPounds.toStringAsFixed(1)} lbs',
                                        style: Theme.of(context).textTheme.bodyLarge,
                                      ),
                                      if (_todayWeightEntry!.bmi != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'BMI: ${_todayWeightEntry!.bmi!.toStringAsFixed(1)} (${WeightEntry.getBMICategory(_todayWeightEntry!.bmi!)})',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Allow weight entry
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _weightController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Enter Today\'s Weight (lbs)',
                                  hintText: _client?.weight != null 
                                    ? '${WeightEntry.kgToPounds(_client!.weight!).toStringAsFixed(1)} lbs' 
                                    : 'Enter weight',
                                  suffixText: 'lbs',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 100,
                              child: ElevatedButton(
                                onPressed: _isSubmittingWeight ? null : _submitWeightEntry,
                                child: _isSubmittingWeight
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.0),
                                    )
                                  : const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
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
              
              const SizedBox(height: 24),
              
              // Today's Workout Section
              Text(
                "Today's Workout",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              // Workouts list with fixed height
              SizedBox(
                height: 300, // Fixed height for workout list
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
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fitness_center,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
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
                      // Disable scrolling on this ListView since it's inside a SingleChildScrollView
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
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
            ],
          ),
        ),
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
  
  // Build upcoming session card
  Widget _buildUpcomingSessionCard(TrainingSession session) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Next Session',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Date and time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.formattedDate,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.formattedTimeRange,
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(height: 32),
            
            // Location
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.location,
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (session.notes != null && session.notes!.isNotEmpty) ...[
              const Divider(height: 32),
              
              // Notes
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.notes,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.notes!,
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
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