import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' show max;
import '../../services/auth_service.dart';
import '../../models/assigned_workout_model.dart';
import '../../services/workout_template_service.dart';
import '../../services/weight_service.dart';
import '../../models/weight_entry_model.dart';
import '../../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_styles.dart';

// A simple workout data model for progress tracking
class WorkoutProgressData {
  final String id;
  final String userId;
  final String workoutName;
  final DateTime date;
  final DateTime completedDate;

  WorkoutProgressData({
    required this.id,
    required this.userId,
    required this.workoutName,
    required this.date,
    required this.completedDate,
  });
}

class ClientProgressScreen extends StatefulWidget {
  const ClientProgressScreen({super.key});

  @override
  State<ClientProgressScreen> createState() => _ClientProgressScreenState();
}

class _ClientProgressScreenState extends State<ClientProgressScreen> {
  final WorkoutTemplateService _workoutTemplateService = WorkoutTemplateService();
  final AuthService _authService = AuthService();
  final WeightService _weightService = WeightService();
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  Map<DateTime, List<WorkoutProgressData>> _completedWorkouts = {};
  bool _isLoading = true;
  String? _clientId;
  UserModel? _client;
  
  // Stats
  int _totalWorkouts = 0;
  int _completedWorkoutsCount = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  
  // Weight tracking
  List<WeightEntry> _weightEntries = [];
  bool _showBMI = false; // Toggle between weight and BMI
  
  @override
  void initState() {
    super.initState();
    _loadClientData();
  }
  
  Future<void> _loadClientData() async {
    try {
      final user = await _authService.getUserModel();
      if (mounted) {
        setState(() {
          _clientId = user.uid;
          _client = user;
        });
      }
      
      await _loadCompletedWorkouts();
      await _loadWeightEntries();
      _calculateStats();
    } catch (e) {
      print("Error loading client data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadWeightEntries() async {
    try {
      final entries = await _weightService.getWeightEntries();
      print("Loaded ${entries.length} weight entries");
      
      if (entries.isNotEmpty) {
        // Debug information about weight entries
        entries.take(5).forEach((entry) {
          print("Weight entry: ${entry.weightInPounds.toStringAsFixed(1)} lbs, date: ${DateFormat('yyyy-MM-dd').format(entry.date)}");
        });
      } else {
        print("No weight entries found");
      }
      
      if (mounted) {
        setState(() {
          _weightEntries = entries;
        });
      }
    } catch (e) {
      print("Error loading weight entries: $e");
    }
  }
  
  Future<void> _loadCompletedWorkouts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      // Group workouts by date
      Map<DateTime, List<WorkoutProgressData>> workoutsByDate = {};
      
      // Only load completed assigned workouts - skip the old WorkoutService approach
      await _loadCompletedAssignedWorkouts(workoutsByDate);
      
      print("Grouped workouts by date: ${workoutsByDate.keys.length} days with workouts");
      // Print each date with workouts for debugging
      workoutsByDate.forEach((date, workouts) {
        print("${DateFormat('yyyy-MM-dd').format(date)}: ${workouts.length} workouts");
      });
      
      if (mounted) {
        setState(() {
          _completedWorkouts = workoutsByDate;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading completed workouts: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Load completed assigned workouts and convert them to WorkoutProgressData objects
  Future<void> _loadCompletedAssignedWorkouts(Map<DateTime, List<WorkoutProgressData>> workoutsByDate) async {
    if (_clientId == null) return;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('assignedWorkouts')
          .where('clientId', isEqualTo: _clientId)
          .where('status', isEqualTo: 'completed')
          .get();
      
      print("Found ${snapshot.docs.length} completed assigned workouts");
      
      for (var doc in snapshot.docs) {
        final assignedWorkout = AssignedWorkout.fromFirestore(doc);
        
        if (assignedWorkout.completedDate != null) {
          // Create a WorkoutProgressData from the AssignedWorkout
          final workoutProgressData = WorkoutProgressData(
            id: assignedWorkout.id,
            userId: assignedWorkout.clientId,
            workoutName: assignedWorkout.workoutName,
            date: assignedWorkout.scheduledDate,
            completedDate: assignedWorkout.completedDate!,
          );
          
          // Add to the workouts map by date
          final workoutDate = DateTime(
            assignedWorkout.completedDate!.year,
            assignedWorkout.completedDate!.month,
            assignedWorkout.completedDate!.day,
          );
          
          if (workoutsByDate[workoutDate] == null) {
            workoutsByDate[workoutDate] = [];
          }
          
          workoutsByDate[workoutDate]!.add(workoutProgressData);
          print("Added assigned workout to date ${DateFormat('yyyy-MM-dd').format(workoutDate)}");
        }
      }
    } catch (e) {
      print("Error loading completed assigned workouts: $e");
    }
  }
  
  void _calculateStats() {
    if (_completedWorkouts.isEmpty) {
      if (mounted) {
        setState(() {
          _totalWorkouts = 0;
          _completedWorkoutsCount = 0;
          _currentStreak = 0;
          _longestStreak = 0;
        });
      }
      return;
    }
    
    // Print all dates for debugging
    print("All workout dates:");
    _completedWorkouts.keys.forEach((date) {
      print("  ${DateFormat('yyyy-MM-dd').format(date)}: ${_completedWorkouts[date]!.length} workouts");
    });
    
    // Calculate total completed workouts
    int completedCount = 0;
    for (var workouts in _completedWorkouts.values) {
      completedCount += workouts.length;
    }
    
    // Get all dates with completed workouts
    final dates = _completedWorkouts.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Sort descending
    
    // Calculate current streak
    int currentStreak = 0;
    DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    
    print("Today's date (normalized): ${DateFormat('yyyy-MM-dd').format(today)}");
    
    // Check if user has completed a workout today
    bool hasWorkoutToday = false;
    
    // Check all completed workout dates to find today's
    for (var date in _completedWorkouts.keys) {
      if (date.year == today.year && date.month == today.month && date.day == today.day) {
        hasWorkoutToday = true;
        print("FOUND TODAY'S WORKOUT: ${DateFormat('yyyy-MM-dd').format(date)}");
        break;
      }
    }
    
    // If they have a workout today, start streak from today
    // Otherwise start checking from yesterday
    DateTime checkDate = hasWorkoutToday ? today : today.subtract(const Duration(days: 1));
    
    if (hasWorkoutToday) {
      currentStreak = 1;
    }
    
    // Check consecutive days backwards
    while (true) {
      // Find if this date has a workout
      bool hasWorkout = false;
      for (var date in _completedWorkouts.keys) {
        if (date.year == checkDate.year && date.month == checkDate.month && date.day == checkDate.day) {
          hasWorkout = true;
          break;
        }
      }
      
      if (!hasWorkout) {
        break; // Streak is broken
      }
      
      if (!hasWorkoutToday || checkDate != today) {
        currentStreak++;
      }
      
      // Move to previous day
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    // Calculate longest streak
    int longestStreak = 0;
    int tempStreak = 0;
    
    // Sort dates ascending for streak calculation
    dates.sort((a, b) => a.compareTo(b));
    
    DateTime? previousDate;
    for (DateTime date in dates) {
      if (previousDate == null) {
        tempStreak = 1;
      } else {
        // Check if this date is consecutive with previous date
        final difference = date.difference(previousDate).inDays;
        
        if (difference == 1) {
          tempStreak++;
        } else {
          // Streak broken, restart
          tempStreak = 1;
        }
      }
      
      longestStreak = longestStreak < tempStreak ? tempStreak : longestStreak;
      previousDate = date;
    }
    
    if (mounted) {
      setState(() {
        _totalWorkouts = completedCount;
        _completedWorkoutsCount = completedCount; 
        _currentStreak = currentStreak;
        _longestStreak = longestStreak;
      });
    }
  }
  
  List<WorkoutProgressData> _getWorkoutsForDay(DateTime day) {
    // Normalize the date to avoid time issues
    final normalizedDay = DateTime(day.year, day.month, day.day);
    
    List<WorkoutProgressData> result = [];
    
    // Find workouts using year/month/day comparison instead of exact matching
    for (var date in _completedWorkouts.keys) {
      if (date.year == normalizedDay.year && 
          date.month == normalizedDay.month && 
          date.day == normalizedDay.day) {
        result.addAll(_completedWorkouts[date] ?? []);
      }
    }
    
    // Log for debugging
    if (result.isNotEmpty) {
      print("Found ${result.length} workouts for ${DateFormat('yyyy-MM-dd').format(normalizedDay)}");
    }
    
    return result;
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppStyles.primarySage,
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Tracking'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weight and BMI Chart Section - Always show to debug
              Card(
                color: AppStyles.offWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _showBMI ? 'BMI Progress' : 'Weight Progress',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppStyles.textDark,
                            ),
                          ),
                          Switch(
                            value: _showBMI,
                            onChanged: (value) {
                              setState(() {
                                _showBMI = value;
                                print("Toggled to ${_showBMI ? 'BMI' : 'Weight'} display");
                              });
                            },
                            activeColor: AppStyles.primarySage,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 250,
                        child: _weightEntries.isEmpty 
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.scale,
                                      size: 64,
                                      color: AppStyles.slateGray.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No weight data available yet\nRecord your weight on the dashboard',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppStyles.slateGray,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                          : _buildProgressChart(),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _showBMI ? 'BMI Over Time' : 'Weight (lbs) Over Time',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppStyles.slateGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            
              // Stats cards
              Row(
                children: [
                  _buildStatCard(
                    context,
                    title: 'Current Streak',
                    value: '$_currentStreak ${_currentStreak == 1 ? 'day' : 'days'}',
                    icon: Icons.local_fire_department,
                    color: AppStyles.warningAmber,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    context,
                    title: 'Longest Streak',
                    value: '$_longestStreak ${_longestStreak == 1 ? 'day' : 'days'}',
                    icon: Icons.emoji_events,
                    color: AppStyles.softGold,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatCard(
                    context,
                    title: 'Days Completed',
                    value: '$_completedWorkoutsCount',
                    icon: Icons.fitness_center,
                    color: AppStyles.successGreen,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    context,
                    title: 'This Month',
                    value: '${_getWorkoutsThisMonth()}',
                    icon: Icons.calendar_month,
                    color: AppStyles.mutedBlue,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            
              // Calendar
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    eventLoader: _getWorkoutsForDay,
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDay, day);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    calendarStyle: CalendarStyle(
                      // Customize the calendar appearance
                      markersMaxCount: 3,
                      markerSize: 8,
                      markerDecoration: const BoxDecoration(
                        color: AppStyles.successGreen,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: AppStyles.primarySage.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: AppStyles.primarySage,
                        shape: BoxShape.circle,
                      ),
                      // Make sure markers are visible
                      markersAnchor: 1.7,
                      markersAutoAligned: true,
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonTextStyle: const TextStyle(
                        color: AppStyles.primarySage,
                      ),
                      formatButtonDecoration: BoxDecoration(
                        border: Border.all(color: AppStyles.primarySage),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      // Add a custom marker builder to make the markers more visible
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return const SizedBox.shrink();
                        
                        return Positioned(
                          bottom: 1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            
              // Workouts for selected day
              if (_selectedDay != null)
                Container(
                  height: 300, // Fixed height for the workout list
                  child: _buildSelectedDayWorkouts(),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  int _getWorkoutsThisMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    int count = 0;
    for (var entry in _completedWorkouts.entries) {
      if (entry.key.isAfter(startOfMonth.subtract(const Duration(days: 1))) && 
          entry.key.isBefore(endOfMonth.add(const Duration(days: 1)))) {
        count += entry.value.length;
      }
    }
    
    return count;
  }
  
  Widget _buildSelectedDayWorkouts() {
    final workouts = _getWorkoutsForDay(_selectedDay!);
    
    if (workouts.isEmpty) {
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
              'No workouts completed on this day',
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
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        final workout = workouts[index];
        return Card(
          color: AppStyles.offWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12.0),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppStyles.successGreen,
              child: Icon(Icons.check, color: AppStyles.textDark),
            ),
            title: const Text(
              'Workout Completed',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppStyles.textDark,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Program: ${workout.workoutName}',
                  style: const TextStyle(color: AppStyles.slateGray),
                ),
                Text(
                  'Completed at: ${DateFormat.jm().format(workout.completedDate)}',
                  style: const TextStyle(color: AppStyles.slateGray),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildWorkoutList(List<WorkoutProgressData> workouts) {
    if (workouts.isEmpty) {
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
              'No workouts completed on this day',
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
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        final workout = workouts[index];
        return Card(
          color: AppStyles.offWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12.0),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppStyles.successGreen,
              child: Icon(Icons.check, color: AppStyles.textDark),
            ),
            title: const Text(
              'Workout Completed',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppStyles.textDark,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Program: ${workout.workoutName}',
                  style: const TextStyle(color: AppStyles.slateGray),
                ),
                Text(
                  'Completed at: ${DateFormat.jm().format(workout.completedDate)}',
                  style: const TextStyle(color: AppStyles.slateGray),
                ),
              ],
            ),
          ),
        );
      },
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
        color: AppStyles.offWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
                style: const TextStyle(
                  fontSize: 20,
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
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Build the weight or BMI chart
  Widget _buildProgressChart() {
    if (_weightEntries.isEmpty) {
      return const Center(
        child: Text(
          'No weight data available',
          style: TextStyle(color: AppStyles.textDark),
        ),
      );
    }

    print("Building progress chart with ${_weightEntries.length} weight entries");

    // Group weight entries by day to ensure only one data point per day
    Map<String, WeightEntry> entriesByDate = {};
    for (var entry in _weightEntries) {
      String dateKey = DateFormat('yyyy-MM-dd').format(entry.date);
      entriesByDate[dateKey] = entry;
    }

    // Convert to list and sort by date
    List<WeightEntry> uniqueDailyEntries = entriesByDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Only show last 30 entries if there are more
    final entriesToShow = uniqueDailyEntries.length > 30 
        ? uniqueDailyEntries.sublist(uniqueDailyEntries.length - 30) 
        : uniqueDailyEntries;

    print("Showing ${entriesToShow.length} unique daily entries");

    // Find min and max values for scaling
    double minY = double.infinity;
    double maxY = 0;
    
    for (var entry in entriesToShow) {
      double value = _showBMI 
          ? (entry.bmi ?? WeightEntry.calculateBMI(entry.weight, _client?.height ?? 175)) 
          : entry.weightInPounds;
          
      if (value < minY) minY = value;
      if (value > maxY) maxY = value;
    }
    
    // Add padding to min/max
    minY = (minY == double.infinity) ? 0 : (minY * 0.9);
    maxY = maxY * 1.1;
    
    print("Chart range: $minY to $maxY");

    // Generate line chart data
    LineChartBarData lineData = LineChartBarData(
      spots: entriesToShow.asMap().entries.map((entry) {
        final index = entry.key.toDouble();
        final weightEntry = entry.value;
        final value = _showBMI 
            ? (weightEntry.bmi ?? WeightEntry.calculateBMI(weightEntry.weight, _client?.height ?? 175)) 
            : weightEntry.weightInPounds;
        return FlSpot(index, value);
      }).toList(),
      isCurved: true,
      color: AppStyles.primarySage,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: AppStyles.primarySage,
            strokeWidth: 1,
            strokeColor: AppStyles.offWhite,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: AppStyles.primarySage.withOpacity(0.2),
      ),
    );

    // Build the chart
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _showBMI ? 5 : 10, // Interval based on data type
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppStyles.slateGray.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            axisNameWidget: const SizedBox.shrink(),
            // For bottom titles, only show a few dates evenly spaced
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: max(1, (entriesToShow.length / 4).ceil().toDouble()), // Ensure interval is at least 1
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                // Only show 5 dates: first, 1/4, half, 3/4, and last
                if (entriesToShow.isNotEmpty && index < entriesToShow.length) {
                  int entryCount = entriesToShow.length;
                  if (index == 0 || 
                      index == entryCount - 1 || 
                      index == (entryCount ~/ 2) ||
                      index == (entryCount ~/ 4) ||
                      index == (entryCount * 3 ~/ 4)) {
                    final date = entriesToShow[index].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('MM/dd').format(date),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppStyles.slateGray,
                        ),
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value % (_showBMI ? 5 : 20) == 0) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppStyles.slateGray,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: AppStyles.slateGray.withOpacity(0.3),
            width: 1,
          ),
        ),
        minX: 0,
        maxX: entriesToShow.length.toDouble() - 1,
        minY: minY,
        maxY: maxY,
        lineBarsData: [lineData],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppStyles.offWhite,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final index = touchedSpot.x.toInt();
                if (index >= 0 && index < entriesToShow.length) {
                  final entry = entriesToShow[index];
                  final prefix = _showBMI ? 'BMI: ' : 'Weight: ';
                  final suffix = _showBMI ? '' : ' lbs';
                  final value = _showBMI 
                      ? (entry.bmi ?? WeightEntry.calculateBMI(entry.weight, _client?.height ?? 175)).toStringAsFixed(1) 
                      : entry.weightInPounds.toStringAsFixed(1);
                  final date = DateFormat('MMM dd, yyyy').format(entry.date);
                  
                  return LineTooltipItem(
                    '$date\n$prefix$value$suffix',
                    const TextStyle(
                      color: AppStyles.textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
      ),
    );
  }
} 