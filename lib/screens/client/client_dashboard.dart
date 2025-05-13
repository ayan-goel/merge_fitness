import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'select_trainer_screen.dart';
import 'all_sessions_screen.dart';
import '../../models/nutrition_plan_model.dart';
import '../../services/nutrition_service.dart';
import '../../screens/home_screen.dart';
import 'trainer_location_screen.dart';
import '../../services/location_service.dart';

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
  final NutritionService _nutritionService = NutritionService();
  final LocationService _locationService = LocationService();
  
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
  
  // Load upcoming sessions - doesn't require trainer assignment
  Future<void> _loadUpcomingSessions() async {
    try {
      if (_client == null) return;
      
      final sessions = await _calendlyService.getClientUpcomingSessions(_client!.uid);
      
      if (mounted) {
        setState(() {
          _upcomingSessions = sessions;
        });
      }
    } catch (e) {
      print("Error loading upcoming sessions: $e");
    }
  }
  
  // Navigate to view all sessions
  void _viewAllSessions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllSessionsScreen(
          sessions: _upcomingSessions,
          clientId: _client!.uid,
          onSessionCancelled: () => _loadUpcomingSessions(),
        ),
      ),
    );
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
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
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
              
              // Today's Workout Section with section header
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Today's Workout",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              
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
              
              const SizedBox(height: 24),
              
              // Upcoming Sessions Section
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Training Sessions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              
              // Show upcoming sessions if available
              if (_upcomingSessions.isNotEmpty) ...[
                // Group sessions by date
                Builder(
                  builder: (context) {
                    // Group sessions by date (yyyy-MM-dd)
                    final Map<String, List<TrainingSession>> sessionsByDate = {};
                    
                    for (final session in _upcomingSessions) {
                      final dateKey = '${session.startTime.year}-${session.startTime.month.toString().padLeft(2, '0')}-${session.startTime.day.toString().padLeft(2, '0')}';
                      if (!sessionsByDate.containsKey(dateKey)) {
                        sessionsByDate[dateKey] = [];
                      }
                      sessionsByDate[dateKey]!.add(session);
                    }
                    
                    // Sort date keys
                    final sortedDates = sessionsByDate.keys.toList()..sort();
                    
                    // On dashboard, limit to first 2 days for cleaner display
                    final limitedDates = sortedDates.take(2).toList();
                    final hasMoreDates = sortedDates.length > 2;
                    
                    // Calculate total sessions
                    int totalSessionsOnDisplay = 0;
                    for (final dateKey in limitedDates) {
                      totalSessionsOnDisplay += sessionsByDate[dateKey]!.length;
                    }
                    
                    // Calculate hidden sessions
                    int hiddenSessionsCount = _upcomingSessions.length - totalSessionsOnDisplay;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: limitedDates.length,
                          itemBuilder: (context, dateIndex) {
                            final dateKey = limitedDates[dateIndex];
                            final sessions = sessionsByDate[dateKey]!;
                            final firstSession = sessions.first;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date header
                                if (dateIndex > 0) const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                                  child: Text(
                                    _formatDateHeader(firstSession.startTime),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                // Sessions for this date
                                ...sessions.map((session) => _buildUpcomingSessionCard(session)).toList(),
                              ],
                            );
                          },
                        ),
                        
                        // "View All" button if there are more sessions
                        if (hasMoreDates || hiddenSessionsCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Center(
                              child: OutlinedButton.icon(
                                onPressed: _viewAllSessions,
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                  hiddenSessionsCount > 0
                                      ? 'View All Sessions (+$hiddenSessionsCount more)'
                                      : 'View All Sessions',
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ] else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No upcoming sessions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Schedule a session with a trainer below',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              // Schedule button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to trainer selection screen instead of directly to scheduling
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectTrainerScreen(
                          clientId: _client!.uid,
                        ),
                      ),
                    ).then((_) {
                      // Refresh sessions on return
                      _loadUpcomingSessions();
                    });
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(_upcomingSessions.isEmpty 
                    ? 'Schedule a training session'
                    : 'Schedule another session'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
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
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Your Progress',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              
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
              
              const SizedBox(height: 16),
              
              // Nutrition Plan Card
              _buildNutritionPlanCard(),
              
              const SizedBox(height: 16),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.event,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.formattedTimeRange,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.location,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey[700]),
                          const SizedBox(width: 4),
                          Text(
                            'With ${session.trainerName}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (session.canBeCancelled)
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Session Options',
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            const Icon(Icons.cancel, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            const Text('Cancel Session'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'track',
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            const Text('Track Trainer'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'cancel') {
                        _showCancelSessionDialog(session);
                      } else if (value == 'track') {
                        _showTrainerLocationDialog(session);
                      }
                    },
                  ),
              ],
            ),
            
            if (session.notes != null && session.notes!.isNotEmpty) ...[
              const Divider(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
  
  // New method to show trainer location dialog
  void _showTrainerLocationDialog(TrainingSession session) async {
    // Check if the session is in the future or happening now
    final now = DateTime.now();
    final sessionStartTime = session.startTime;
    
    if (sessionStartTime.isBefore(now.subtract(const Duration(hours: 2)))) {
      // Session is in the past (more than 2 hours ago)
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Track ${session.trainerName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'This session has already ended',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Trainer location tracking is only available for upcoming or current sessions.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      // Session is upcoming or happening now
      // First check if the trainer is sharing their location
      final LocationService locationService = LocationService();
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        final isSharing = await locationService.isTrainerSharingLocation(session.trainerId);
        
        if (!isSharing) {
          setState(() {
            _isLoading = false;
          });
          
          // Show not sharing dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Track ${session.trainerName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${session.trainerName} is not sharing their location yet',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ask your trainer to enable location sharing before the session.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrainerLocationScreen(session: session),
                      ),
                    );
                  },
                  child: const Text('Try Anyway'),
                ),
              ],
            ),
          );
          return;
        }
        
        // Check if we have location permission
        final hasPermission = await locationService.checkLocationPermission();
        
        setState(() {
          _isLoading = false;
        });
        
        if (!hasPermission) {
          // Show permission required dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Permission Required'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 64,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Location permission is needed to show distance and travel time to your trainer.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please grant location permission when prompted.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    
                    // Request permission again
                    final permissionGranted = await locationService.checkLocationPermission();
                    
                    if (permissionGranted) {
                      // Navigate to tracking screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrainerLocationScreen(session: session),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Location permission is required for distance tracking'),
                        ),
                      );
                    }
                  },
                  child: const Text('Grant Permission'),
                ),
              ],
            ),
          );
        } else {
          // We have permission, navigate to tracking screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TrainerLocationScreen(session: session),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking trainer location: $e')),
        );
      }
    }
  }
  
  // Show cancel confirmation dialog
  Future<void> _showCancelSessionDialog(TrainingSession session) async {
    final TextEditingController reasonController = TextEditingController();
    
    try {
      bool? result = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Cancel Training Session'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to cancel this session?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Date: ${session.formattedDate}'),
                Text('Time: ${session.formattedTimeRange}'),
                const SizedBox(height: 16),
                const Text('Reason for cancellation (optional):'),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    hintText: 'Enter reason here',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No, Keep It'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );
      
      if (result == true) {
        try {
          setState(() {
            _isLoading = true;
          });
          
          final reason = reasonController.text;
          
          await _calendlyService.cancelSession(
            session.id,
            cancellationReason: reason.isEmpty ? null : reason,
          );
          
          // Reload sessions
          await _loadUpcomingSessions();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session cancelled successfully')),
            );
          }
        } catch (e) {
          print('Error cancelling session: $e');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error cancelling session: $e')),
            );
          }
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } finally {
      // Ensure controller is always disposed, even if the dialog is dismissed
      reasonController.dispose();
    }
  }

  // Format a date header
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final sessionDate = DateTime(date.year, date.month, date.day);
    
    if (sessionDate == today) {
      return 'Today, ${DateFormat('MMMM d').format(date)}';
    } else if (sessionDate == tomorrow) {
      return 'Tomorrow, ${DateFormat('MMMM d').format(date)}';
    } else {
      return DateFormat('EEEE, MMMM d').format(date);
    }
  }

  Widget _buildNutritionPlanCard() {
    return FutureBuilder<NutritionPlan?>(
      future: _nutritionService.getCurrentNutritionPlan(_client!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        
        final currentPlan = snapshot.data;
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nutrition Plan',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        HomeScreen.navigateToTab(context, 3); // Navigate to Food tab
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const Divider(),
                if (currentPlan != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            currentPlan.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, size: 16),
                      const SizedBox(width: 8),
                      Text('${currentPlan.dailyCalories} calories daily'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${currentPlan.macronutrients['protein']?.toInt() ?? 0}g',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('Protein'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${currentPlan.macronutrients['carbs']?.toInt() ?? 0}g',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('Carbs'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${currentPlan.macronutrients['fat']?.toInt() ?? 0}g',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('Fat'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        'No active nutrition plan',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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