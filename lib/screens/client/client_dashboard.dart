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
import '../../services/enhanced_workout_service.dart';
import '../../services/weight_service.dart';
import '../../services/calendly_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/location_service.dart';
import '../../services/session_monitoring_service.dart';
import '../../services/messaging_service.dart';

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
import '../shared/conversations_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final AuthService _authService = AuthService();
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final EnhancedWorkoutService _enhancedWorkoutService = EnhancedWorkoutService();
  final WeightService _weightService = WeightService();
  final CalendlyService _calendlyService = CalendlyService();
  final NutritionService _nutritionService = NutritionService();
  final LocationService _locationService = LocationService();
  final SessionMonitoringService _sessionMonitoringService = SessionMonitoringService();
  final MessagingService _messagingService = MessagingService();
  
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
    // Start session monitoring
    _sessionMonitoringService.startMonitoring();
  }
  
  @override
  void dispose() {
    _weightController.dispose();
    _sessionMonitoringService.stopMonitoring();
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
      if (_client?.trainerId == null) {
        print("Client has no trainer assigned");
        return;
      }
      
      print("Loading trainer data for trainerId: ${_client!.trainerId}");
      
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
        print("Trainer data loaded successfully: ${_trainer?.displayName}");
      } else {
        print("Trainer document does not exist");
      }
    } catch (e) {
      print("Error loading trainer data: $e");
      // Don't show error to user since trainer info is not critical for dashboard
      // The UI will handle the null trainer gracefully
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
  
  // Navigate to booking screen (handles multiple trainers)
  void _navigateToBooking() {
    if (_client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client data not loaded. Please refresh.')),
      );
      return;
    }

    final assignedTrainerIds = _client!.assignedTrainerIds;

    if (assignedTrainerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trainer assigned. Please contact support.')),
      );
      return;
    }

    if (assignedTrainerIds.length == 1) {
      // Single trainer - navigate directly to booking
      final trainerId = assignedTrainerIds.first;
      final trainerName = _trainer?.displayName ?? 
          '${_trainer?.firstName ?? ''} ${_trainer?.lastName ?? ''}'.trim();
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleSessionScreen(
            clientId: _client!.uid,
            trainerId: trainerId,
            trainerName: trainerName,
          ),
        ),
      ).then((_) => _loadUpcomingSessions());
    } else {
      // Multiple trainers - show selection screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelectTrainerScreen(
            clientId: _client!.uid,
          ),
        ),
      ).then((_) => _loadUpcomingSessions());
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
      // Get all workouts for the client (including sessions)
      final workoutsStream = _enhancedWorkoutService.getClientWorkouts(_client!.uid);
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
              
              // Messages Section
              AppAnimations.fadeSlide(
                beginOffset: const Offset(0, 0.1),
                child: StreamBuilder<int>(
                  stream: _messagingService.getUnreadMessageCount(_client!.uid),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            AppStyles.primarySage.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppStyles.primarySage.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppStyles.slateGray.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ConversationsScreen(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppStyles.primarySage.withOpacity(0.8),
                                        AppStyles.primarySage.withOpacity(0.6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppStyles.primarySage.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Messages',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppStyles.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        unreadCount > 0
                                            ? 'You have $unreadCount unread message${unreadCount != 1 ? 's' : ''}'
                                            : 'Chat with your trainer',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: unreadCount > 0
                                              ? AppStyles.primarySage
                                              : AppStyles.slateGray,
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppStyles.primarySage,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppStyles.primarySage.withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey[400],
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Today's Workout Section with enhanced styling
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppStyles.primarySage.withOpacity(0.8),
                            AppStyles.primarySage.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppStyles.primarySage.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Today's Workout",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Workouts list with fixed height
              StreamBuilder<List<AssignedWorkout>>(
                stream: _enhancedWorkoutService.getCurrentWorkouts(_client!.uid),
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
                    return Container(
                      margin: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppStyles.offWhite,
                            AppStyles.primarySage.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color: AppStyles.primarySage.withOpacity(0.1),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppStyles.slateGray.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppStyles.primarySage.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppStyles.primarySage.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.fitness_center,
                                size: 32,
                                color: AppStyles.primarySage,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No workouts scheduled for today',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppStyles.textDark,
                                letterSpacing: -0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Take a rest day or check back tomorrow',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppStyles.slateGray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
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
              
              // Training Sessions Section with enhanced styling
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppStyles.mutedBlue.withOpacity(0.8),
                            AppStyles.mutedBlue.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppStyles.mutedBlue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.schedule,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Sessions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    if (_upcomingSessions.isNotEmpty)
                      TextButton.icon(
                        onPressed: _viewAllSessions,
                        icon: const Icon(
                          Icons.arrow_forward,
                          size: 16,
                        ),
                        label: const Text('View All'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppStyles.mutedBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
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
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: _navigateToBooking,
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
                                child:                                 OutlinedButton.icon(
                                  onPressed: _navigateToBooking,
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
                Container(
                  margin: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppStyles.offWhite,
                        AppStyles.mutedBlue.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: AppStyles.mutedBlue.withOpacity(0.1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppStyles.slateGray.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppStyles.mutedBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppStyles.mutedBlue.withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.event_available,
                            size: 32,
                            color: AppStyles.mutedBlue,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No upcoming sessions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.textDark,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Schedule a session with a trainer below',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppStyles.slateGray,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        // Schedule session button with enhanced styling
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppStyles.mutedBlue.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _navigateToBooking,
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            label: const Text('Schedule Session'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppStyles.mutedBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppStyles.offWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppStyles.cardShadow,
      ),
      child: Column(
        children: [
          // Date header inside the card
          Container(
            padding: const EdgeInsets.only(top: 16.0, left: 20.0, right: 20.0, bottom: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppStyles.mutedBlue.withOpacity(0.15),
                        AppStyles.mutedBlue.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppStyles.mutedBlue.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _formatDateHeader(session.startTime),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppStyles.mutedBlue,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppStyles.slateGray.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Time column
                Container(
                  width: 85,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isImminent 
                          ? [
                              AppStyles.primarySage.withOpacity(0.2),
                              AppStyles.primarySage.withOpacity(0.15),
                            ]
                          : [
                              AppStyles.mutedBlue.withOpacity(0.1),
                              AppStyles.mutedBlue.withOpacity(0.05),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isImminent 
                          ? AppStyles.primarySage.withOpacity(0.3)
                          : AppStyles.mutedBlue.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isImminent 
                            ? AppStyles.primarySage 
                            : AppStyles.mutedBlue).withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isImminent 
                              ? AppStyles.primarySage 
                              : AppStyles.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (isImminent) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppStyles.primarySage.withOpacity(0.3),
                                AppStyles.primarySage.withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppStyles.primarySage.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Soon',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppStyles.primarySage,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                
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
                      // Check if we're within 30 minutes of the session start time
                      final now = DateTime.now();
                      final thirtyMinutesBeforeStart = session.startTime.subtract(const Duration(minutes: 30));
                      
                      if (now.isAfter(thirtyMinutesBeforeStart)) {
                        //Within 30 minutes of session, allowed to track
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrainerLocationScreen(
                              session: session,
                            ),
                          ),
                        );
                       } else {
                         // Too early, show restriction dialog
                         _showTrackingRestrictionDialog(session);
                       }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Show cancel confirmation dialog
  Future<void> _showCancelSessionDialog(TrainingSession session) async {
    final TextEditingController reasonController = TextEditingController();
    
    // Calculate if session is within 24 hours
    final now = DateTime.now();
    final timeDifference = session.startTime.difference(now);
    final isWithin24Hours = timeDifference.inHours < 24;
    
    try {
      bool? result = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.6),
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 12,
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 400,
                maxHeight: 650, // Add max height constraint
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppStyles.errorRed.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppStyles.errorRed.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cancel_outlined,
                            color: AppStyles.errorRed,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Cancel Training Session',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppStyles.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  // Content - Make scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        // Session details card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppStyles.offWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppStyles.slateGray.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.event,
                                    size: 18,
                                    color: AppStyles.primarySage,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    session.formattedDate,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppStyles.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: AppStyles.primarySage,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    session.formattedTimeRange,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppStyles.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: AppStyles.primarySage,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      session.location,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppStyles.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Refund policy information
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isWithin24Hours 
                                ? AppStyles.errorRed.withOpacity(0.1)
                                : AppStyles.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isWithin24Hours 
                                  ? AppStyles.errorRed.withOpacity(0.3)
                                  : AppStyles.successGreen.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isWithin24Hours ? Icons.warning_amber : Icons.check_circle,
                                    color: isWithin24Hours ? AppStyles.errorRed : AppStyles.successGreen,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Refund Policy',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isWithin24Hours ? AppStyles.errorRed : AppStyles.successGreen,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isWithin24Hours
                                    ? 'This session is within 24 hours. Your session will NOT be refunded unless you have discussed with your trainer beforehand with a valid reason. If you have, your trainer will manually restore your session.'
                                    : 'This session is more than 24 hours away. Your session will be automatically refunded to your account.',
                                style: TextStyle(
                                  color: isWithin24Hours ? AppStyles.errorRed : AppStyles.successGreen,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Reason field
                        const Text(
                          'Reason for cancellation (optional):',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppStyles.textDark,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: reasonController,
                          decoration: AppStyles.inputDecoration(
                            labelText: '',
                            hintText: 'Enter your reason here...',
                          ),
                          style: const TextStyle(color: AppStyles.textDark),
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                        ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Actions
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: AppStyles.slateGray.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Keep Session',
                              style: TextStyle(
                                color: AppStyles.textDark,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppStyles.errorRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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

  // Show tracking restriction dialog
  Future<void> _showTrackingRestrictionDialog(TrainingSession session) async {
    // Calculate and format the time when tracking will be available
    final trackingAvailableTime = session.startTime.subtract(const Duration(minutes: 30));
    final formattedAvailableTime = DateFormat('h:mm a').format(trackingAvailableTime);
    final formattedSessionTime = DateFormat('h:mm a').format(session.startTime);
    
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 12,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header with gradient
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppStyles.primarySage.withOpacity(0.8),
                        AppStyles.primarySage.withOpacity(0.4),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.timer_off_outlined,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tracking Not Available Yet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Content section
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Column(
                    children: [
                      Text(
                        'You can track your trainer\'s location starting 30 minutes before your session.',
                        style: TextStyle(
                          fontSize: 15.5,
                          color: AppStyles.textDark.withOpacity(0.8),
                          height: 1.4,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      // Time remaining countdown
                      Builder(builder: (context) {
                        // Calculate time difference between now and when tracking becomes available
                        final now = DateTime.now();
                        final trackingAvailableTime = session.startTime.subtract(const Duration(minutes: 30));
                        final difference = trackingAvailableTime.difference(now);
                        
                        // Format the remaining time
                        String timeRemaining;
                        if (difference.isNegative) {
                          timeRemaining = "Tracking is now available";
                        } else {
                          final hours = difference.inHours;
                          final minutes = difference.inMinutes % 60;
                          
                          if (hours > 0) {
                            timeRemaining = "$hours hour${hours > 1 ? 's' : ''} and $minutes minute${minutes > 1 ? 's' : ''}";
                          } else {
                            timeRemaining = "$minutes minute${minutes > 1 ? 's' : ''}";
                          }
                        }
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: AppStyles.primarySage.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppStyles.primarySage.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                color: AppStyles.primarySage,
                                size: 28,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Time until tracking is available:",
                                      style: TextStyle(
                                        color: AppStyles.slateGray,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timeRemaining,
                                      style: const TextStyle(
                                        color: AppStyles.primarySage,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      
                      const SizedBox(height: 30),
                      
                      // Info section with more elegant styling
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppStyles.offWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppStyles.slateGray.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildElegantInfoRow(
                              icon: Icons.person_outline,
                              iconColor: AppStyles.mutedBlue,
                              label: 'Trainer',
                              value: session.trainerName,
                            ),
                            const SizedBox(height: 14),
                            _buildElegantInfoRow(
                              icon: Icons.event_available_outlined,
                              iconColor: AppStyles.softGold, 
                              label: 'Session Time',
                              value: formattedSessionTime,
                            ),
                            const SizedBox(height: 14),
                            _buildElegantInfoRow(
                              icon: Icons.location_on_outlined,
                              iconColor: AppStyles.primarySage,
                              label: 'Tracking Available',
                              value: formattedAvailableTime,
                              valueColor: AppStyles.primarySage,
                              valueBold: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bottom button area
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStyles.primarySage,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      shadowColor: AppStyles.primarySage.withOpacity(0.3),
                    ),
                    child: const Text(
                      'OK, I\'ll come back later',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildElegantInfoRow({
    required IconData icon, 
    required Color iconColor, 
    required String label, 
    required String value,
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppStyles.slateGray.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: valueColor ?? AppStyles.textDark,
                  fontWeight: valueBold ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimelinePoint({
    required String label, 
    required IconData icon, 
    required bool isActive,
    bool isHighlighted = false,
  }) {
    final color = isHighlighted 
        ? AppStyles.primarySage 
        : isActive 
            ? AppStyles.slateGray 
            : AppStyles.slateGray.withOpacity(0.3);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isHighlighted 
                ? color.withOpacity(0.2) 
                : Colors.transparent,
            border: Border.all(
              color: color,
              width: isHighlighted ? 2 : 1,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon, 
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimelineConnector({required bool isActive}) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 40,
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: isActive 
            ? AppStyles.slateGray.withOpacity(0.6) 
            : AppStyles.slateGray.withOpacity(0.2),
      ),
    );
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppStyles.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        workout.workoutName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppStyles.textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    _buildStatusChip(context, workout.status),
                  ],
                ),
                if (workout.workoutDescription != null && workout.workoutDescription!.isNotEmpty && !workout.isSessionBased) ...[
                  const SizedBox(height: 16.0),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppStyles.slateGray.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppStyles.slateGray.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      workout.workoutDescription!,
                      style: TextStyle(
                        color: AppStyles.slateGray,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: workout.isSessionBased 
                          ? [
                              AppStyles.mutedBlue.withOpacity(0.1),
                              AppStyles.mutedBlue.withOpacity(0.05),
                            ]
                          : [
                              AppStyles.primarySage.withOpacity(0.1),
                              AppStyles.primarySage.withOpacity(0.05),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: workout.isSessionBased 
                          ? AppStyles.mutedBlue.withOpacity(0.2)
                          : AppStyles.primarySage.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: workout.isSessionBased 
                              ? AppStyles.mutedBlue.withOpacity(0.15)
                              : AppStyles.primarySage.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          workout.isSessionBased ? Icons.schedule : Icons.fitness_center,
                          size: 16,
                          color: workout.isSessionBased 
                              ? AppStyles.mutedBlue
                              : AppStyles.primarySage,
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          workout.isSessionBased 
                              ? 'Personal Training Session'
                              : '${workout.exercises.length} exercise${workout.exercises.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: AppStyles.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: workout.isSessionBased 
                              ? AppStyles.mutedBlue.withOpacity(0.15)
                              : AppStyles.primarySage.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: workout.isSessionBased 
                              ? AppStyles.mutedBlue
                              : AppStyles.primarySage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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