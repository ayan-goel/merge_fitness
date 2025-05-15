import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/painting.dart';

// Models
import '../../models/user_model.dart';
import '../../models/assigned_workout_model.dart';
import '../../models/weight_entry_model.dart';
import '../../models/session_model.dart';
import '../../models/nutrition_plan_model.dart';

// Services
import '../../services/auth_service.dart';
import '../../services/workout_template_service.dart';
import '../../services/weight_service.dart';
import '../../services/calendly_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/location_service.dart';

// Themes
import '../../theme/app_styles.dart';
import '../../theme/app_widgets.dart';
import '../../theme/app_animations.dart';

// Screens
import 'workout_detail_screen.dart';
import 'schedule_session_screen.dart';
import 'select_trainer_screen.dart';
import 'all_sessions_screen.dart';
import 'trainer_location_screen.dart';
import '../../screens/home_screen.dart';

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
  
  // List of motivational messages
  final List<String> _motivationalMessages = [
    "Get ready to crush the day!",
    "Small progress is still progress.",
    "Your only competition is yourself yesterday.",
    "Strength doesn't come from what you can do; it comes from overcoming what you thought you couldn't.",
    "The difference between try and triumph is just a little umph!",
    "Don't wish for it, work for it.",
    "Sweat now, shine later.",
    "Your body can stand almost anything. It's your mind you have to convince.",
    "No matter how slow you go, you're still lapping everyone on the couch.",
    "The pain you feel today will be the strength you feel tomorrow.",
    "The only bad workout is the one that didn't happen.",
    "Make your body the sexiest outfit you own.",
    "The hardest lift of all is lifting your butt off the couch.",
    "Strive for progress, not perfection.",
    "Wake up with determination, go to bed with satisfaction.",
    "What seems impossible today will be your warm-up tomorrow.",
    "You don't have to be extreme, just consistent.",
    "The only place where success comes before work is in the dictionary.",
    "Don't stop when you're tired. Stop when you're done.",
    "Good things come to those who sweat.",
    "Your health is an investment, not an expense.",
    "Well done is better than well said.",
    "It's not about having time, it's about making time.",
    "When you feel like quitting, remember why you started.",
    "The body achieves what the mind believes.",
    "Discipline is choosing between what you want now and what you want most.",
    "You're only one workout away from a good mood.",
    "Fitness is not about being better than someone else, it's about being better than you used to be.",
    "Motivation is what gets you started. Habit is what keeps you going.",
    "Push yourself because no one else is going to do it for you.",
    "The greatest wealth is health.",
    "Take care of your body. It's the only place you have to live.",
    "The harder you work for something, the greater you'll feel when you achieve it.",
    "Respect your body. It's the only one you get.",
    "Fall in love with taking care of yourself.",
    "Today I will do what others won't, so tomorrow I can do what others can't.",
    "Results happen over time, not overnight.",
    "Change happens at the edge of your comfort zone.",
    "Your body hears everything your mind says. Stay positive.",
    "Don't count the days, make the days count."
  ];
  
  // Get a random motivational message
  String get _randomMotivationalMessage {
    final random = DateTime.now().millisecondsSinceEpoch;
    return _motivationalMessages[random % _motivationalMessages.length];
  }
  
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
      return Center(
        child: AppWidgets.circularProgressIndicator(
          color: AppStyles.primarySage,
          size: 50,
        ),
      );
    }
    
    if (_client == null) {
      return Center(
        child: Text(
          'Error loading user data',
          style: TextStyle(
            color: AppStyles.textLight,
            fontSize: 16,
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        actions: [], // Empty actions to remove any existing buttons
        automaticallyImplyLeading: false, // Remove back button
      ),
      backgroundColor: AppStyles.offWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppStyles.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card with glass effect
              AppAnimations.fadeSlide(
                beginOffset: const Offset(0, 0.1),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppStyles.offWhite.withOpacity(0.9),
                        AppStyles.primarySage.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppStyles.primarySage.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppStyles.slateGray.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppStyles.primarySage.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: AppStyles.primarySage.withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppStyles.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Welcome, ${_client!.displayName ?? 'Client'}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppStyles.textDark,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppStyles.primarySage.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppStyles.slateGray.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppStyles.taupeBrown.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.format_quote,
                                      color: AppStyles.taupeBrown,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _randomMotivationalMessage,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                        color: AppStyles.textDark,
                                        fontStyle: FontStyle.normal,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Today's Workout Section
              AppWidgets.sectionHeader(
                title: "Today's Workout",
                onActionPressed: null,
                actionLabel: '',
              ),
              
              // Workouts list with fixed height
              StreamBuilder<List<AssignedWorkout>>(
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
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: AppStyles.offWhite,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppStyles.offWhite,
                          boxShadow: AppStyles.cardShadow,
                        ),
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 48,
                                color: AppStyles.slateGray,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No workouts scheduled for today',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppStyles.textDark,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
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
              
              const SizedBox(height: 24),
              
              // Upcoming Sessions Section with glass-morphism header
              AppWidgets.sectionHeader(
                title: 'Training Sessions',
                onActionPressed: _upcomingSessions.isNotEmpty ? _viewAllSessions : null,
                actionLabel: _upcomingSessions.isNotEmpty ? 'View All' : '',
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
                                // Add spacing if there are multiple date groups
                                if (dateIndex > 0) const SizedBox(height: 16),
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _viewAllSessions,
                                  icon: const Icon(Icons.calendar_month),
                                  label: Text(
                                    hiddenSessionsCount > 0
                                        ? 'View All (+$hiddenSessionsCount)'
                                        : 'View All',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: AppStyles.offWhite,
                                    foregroundColor: AppStyles.primarySage,
                                    side: const BorderSide(color: AppStyles.primarySage, width: 1.5),
                                    elevation: 1,
                                    shadowColor: AppStyles.primarySage.withOpacity(0.2),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SelectTrainerScreen(
                                          clientId: _client!.uid,
                                        ),
                                      ),
                                    ).then((_) => _loadUpcomingSessions());
                                  },
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  label: const Text('Schedule New'),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: AppStyles.offWhite,
                                    foregroundColor: AppStyles.primarySage,
                                    side: const BorderSide(color: AppStyles.primarySage, width: 1.5),
                                    elevation: 1,
                                    shadowColor: AppStyles.primarySage.withOpacity(0.2),
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          // When we don't have more dates to show but still have sessions
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Center(
                              child: SizedBox(
                                width: 300,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SelectTrainerScreen(
                                          clientId: _client!.uid,
                                        ),
                                      ),
                                    ).then((_) => _loadUpcomingSessions());
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: const Text('Schedule New Session'),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: AppStyles.offWhite,
                                    foregroundColor: AppStyles.primarySage,
                                    side: const BorderSide(color: AppStyles.primarySage, width: 1.5),
                                    elevation: 1,
                                    shadowColor: AppStyles.primarySage.withOpacity(0.2),
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
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
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: AppStyles.offWhite,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppStyles.offWhite,
                      boxShadow: AppStyles.cardShadow,
                    ),
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 48,
                            color: AppStyles.slateGray,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Schedule a session with a trainer below',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppStyles.textDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          // Schedule session button
                          SizedBox(
                            width: 240,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SelectTrainerScreen(
                                      clientId: _client!.uid,
                                    ),
                                  ),
                                ).then((_) => _loadUpcomingSessions());
                              },
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              label: const Text('Schedule Session'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppStyles.offWhite,
                                foregroundColor: AppStyles.primarySage,
                                side: const BorderSide(color: AppStyles.primarySage, width: 1.5),
                                elevation: 1,
                                shadowColor: AppStyles.primarySage.withOpacity(0.2),
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Weight Entry Section
              AppWidgets.sectionHeader(
                title: 'Track Your Weight',
                onActionPressed: null,
                actionLabel: '',
              ),
              
              _buildWeightEntryCard(),
              
              const SizedBox(height: 32),
              
              // Today's Stats
              AppWidgets.sectionHeader(
                title: 'Your Stats',
                onActionPressed: null,
                actionLabel: '',
              ),
              
              Row(
                children: [
                  _buildStatCard(
                    context, 
                    title: 'Streak', 
                    value: '$_streak ${_streak == 1 ? 'day' : 'days'}',
                    icon: Icons.local_fire_department,
                    color: AppStyles.warningAmber,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    context, 
                    title: 'Completion', 
                    value: '$_completionPercentage%',
                    icon: Icons.check_circle_outline,
                    color: AppStyles.successGreen,
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
      child: Container(
        decoration: BoxDecoration(
          color: AppStyles.offWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppStyles.cardShadow,
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textDark,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: AppStyles.slateGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Build upcoming session card
  Widget _buildUpcomingSessionCard(TrainingSession session) {
    // Determine if the session is happening very soon (within 30 minutes)
    final bool isImminent = session.startTime.difference(DateTime.now()).inMinutes < 30;
    
    // Format time to display
    final String formattedTime = DateFormat('h:mm a').format(session.startTime);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isImminent 
          ? AppStyles.primarySage.withOpacity(0.15) 
          : AppStyles.offWhite,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isImminent 
            ? AppStyles.primarySage.withOpacity(0.15) 
            : AppStyles.offWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppStyles.cardShadow,
        ),
        child: Column(
          children: [
            // Date header inside the card
            Padding(
              padding: const EdgeInsets.only(top: 12.0, left: 16.0, bottom: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatDateHeader(session.startTime),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppStyles.textDark,
                  ),
                ),
              ),
            ),
            Divider(
              color: AppStyles.slateGray.withOpacity(0.2),
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Time column
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isImminent 
                          ? AppStyles.primarySage.withOpacity(0.2)
                          : AppStyles.slateGray.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isImminent 
                                ? AppStyles.primarySage 
                                : AppStyles.textDark,
                          ),
                        ),
                        if (isImminent) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppStyles.primarySage.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Soon',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppStyles.primarySage,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Session details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.sessionType ?? "Training Session",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppStyles.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 16,
                              color: AppStyles.slateGray,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'with ${session.trainerName}',
                              style: const TextStyle(
                                color: AppStyles.slateGray,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        if (session.location != null && session.location!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: AppStyles.slateGray,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  session.location!,
                                  style: const TextStyle(
                                    color: AppStyles.slateGray,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Action menu
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppStyles.slateGray,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      if (session.trainerLocationEnabled)
                        const PopupMenuItem(
                          value: 'track',
                          child: Row(
                            children: [
                              Icon(Icons.location_on, color: AppStyles.primarySage),
                              SizedBox(width: 8),
                              Text(
                                'Track Trainer',
                                style: TextStyle(color: AppStyles.textDark),
                              ),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(Icons.cancel_outlined, color: AppStyles.errorRed),
                            SizedBox(width: 8),
                            Text(
                              'Cancel Session',
                              style: TextStyle(color: AppStyles.textDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'cancel') {
                        _showCancelSessionDialog(session);
                      } else if (value == 'track' && session.trainerLocationEnabled) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrainerLocationScreen(
                              session: session,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
                child: const Text('Yes, Cancel', style: TextStyle(color: AppStyles.errorRed)),
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

  Widget _buildWeightEntryCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.offWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppStyles.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_todayWeightEntry != null) ...[
              // Show today's entry with improved styling
              Container(
                decoration: BoxDecoration(
                  color: AppStyles.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.successGreen.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppStyles.successGreen.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: AppStyles.successGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Weight recorded for today!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppStyles.textDark,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_todayWeightEntry!.weightInPounds.toStringAsFixed(1)} lbs',
                              style: const TextStyle(
                                color: AppStyles.textDark,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_todayWeightEntry!.bmi != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'BMI: ${_todayWeightEntry!.bmi!.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      color: AppStyles.slateGray,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getBmiColor(_todayWeightEntry!.bmi!).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _getBmiColor(_todayWeightEntry!.bmi!).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      WeightEntry.getBMICategory(_todayWeightEntry!.bmi!),
                                      style: TextStyle(
                                        color: _getBmiColor(_todayWeightEntry!.bmi!),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppStyles.offWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppStyles.mutedBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.monitor_weight_outlined,
                            color: AppStyles.mutedBlue,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "What's your weight today?",
                          style: TextStyle(
                            color: AppStyles.textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Tracking regularly helps monitor your progress.",
                      style: TextStyle(
                        color: AppStyles.slateGray,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppStyles.textDark),
                            decoration: InputDecoration(
                              labelText: 'Enter weight',
                              hintText: _client?.weight != null 
                                ? '${WeightEntry.kgToPounds(_client!.weight!).toStringAsFixed(1)} lbs' 
                                : 'Enter weight',
                              suffixText: 'lbs',
                              suffixStyle: const TextStyle(
                                color: AppStyles.slateGray,
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: AppStyles.offWhite,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppStyles.mutedBlue,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 100,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSubmittingWeight ? null : _submitWeightEntry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppStyles.mutedBlue,
                              foregroundColor: AppStyles.textDark,
                              disabledBackgroundColor: AppStyles.mutedBlue.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmittingWeight
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppStyles.textDark),
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
    );
  }
  
  // Helper function to get BMI category color
  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) {
      return AppStyles.mutedBlue; // Underweight
    } else if (bmi < 25) {
      return AppStyles.successGreen; // Normal
    } else if (bmi < 30) {
      return AppStyles.warningAmber; // Overweight
    } else {
      return AppStyles.errorRed; // Obese
    }
  }

  Widget _buildNutritionPlanCard() {
    return FutureBuilder<NutritionPlan?>(
      future: _nutritionService.getCurrentNutritionPlan(_client!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppStyles.offWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppStyles.cardShadow,
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final currentPlan = snapshot.data;
        
        return Container(
          decoration: BoxDecoration(
            color: AppStyles.offWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppStyles.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppStyles.accentGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: AppStyles.textDark,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Nutrition Plan',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppStyles.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        HomeScreen.navigateToTab(context, 3); // Navigate to Food tab
                      },
                      icon: const Icon(
                        Icons.arrow_forward,
                        size: 16,
                      ),
                      label: const Text('View All'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppStyles.softGold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppStyles.dividerGrey, height: 1),
                const SizedBox(height: 16),
                if (currentPlan != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppStyles.softGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppStyles.softGold.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'CURRENT PLAN',
                              style: TextStyle(
                                color: AppStyles.softGold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              currentPlan.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppStyles.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppStyles.offWhite.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  size: 18,
                                  color: AppStyles.softGold,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${currentPlan.dailyCalories} calories daily',
                                  style: const TextStyle(
                                    color: AppStyles.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: AppStyles.dividerGrey, height: 1),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildMacronutrient(
                                  label: 'Protein',
                                  value: '${currentPlan.macronutrients['protein']?.toInt() ?? 0}g',
                                  color: AppStyles.mutedBlue,
                                ),
                                const SizedBox(width: 8),
                                _buildMacronutrient(
                                  label: 'Carbs',
                                  value: '${currentPlan.macronutrients['carbs']?.toInt() ?? 0}g',
                                  color: AppStyles.softGold,
                                ),
                                const SizedBox(width: 8),
                                _buildMacronutrient(
                                  label: 'Fat',
                                  value: '${currentPlan.macronutrients['fat']?.toInt() ?? 0}g',
                                  color: AppStyles.errorRed,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppStyles.offWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.no_food,
                            size: 40,
                            color: AppStyles.slateGray,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No active nutrition plan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppStyles.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Contact your trainer to set up a nutrition plan',
                            style: TextStyle(
                              color: AppStyles.slateGray,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
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
  
  Widget _buildMacronutrient({
    required String label,
    required String value,
    required Color color,
  }) {
    // Create a lighter, less saturated version of the color for backgrounds
    Color lightColor = HSLColor.fromColor(color)
        .withSaturation(0.3)
        .withLightness(0.9)
        .toColor();
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: lightColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppStyles.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppStyles.textDark,
                fontSize: 12,
              ),
            ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: AppStyles.offWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppStyles.cardShadow,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workout.workoutName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.textDark,
                      ),
                    ),
                  ),
                  _buildStatusChip(context, workout.status),
                ],
              ),
              if (workout.workoutDescription != null && workout.workoutDescription!.isNotEmpty) ...[
                const SizedBox(height: 12.0),
                Text(
                  workout.workoutDescription!,
                  style: TextStyle(
                    color: AppStyles.slateGray,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 20.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppStyles.darkCharcoal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fitness_center,
                      size: 16,
                      color: AppStyles.mutedBlue,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      '${workout.exercises.length} exercise${workout.exercises.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppStyles.textDark,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppStyles.mutedBlue,
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
  
  Widget _buildStatusChip(BuildContext context, WorkoutStatus status) {
    Color chipColor;
    String statusText;
    
    switch (status) {
      case WorkoutStatus.assigned:
        chipColor = AppStyles.mutedBlue;
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