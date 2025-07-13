import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../theme/app_styles.dart';
import '../../services/auth_service.dart';
import '../../services/calendly_service.dart';
import '../../models/user_model.dart';

class TrainerScheduleViewScreen extends StatefulWidget {
  const TrainerScheduleViewScreen({super.key});

  @override
  State<TrainerScheduleViewScreen> createState() => _TrainerScheduleViewScreenState();
}

class _TrainerScheduleViewScreenState extends State<TrainerScheduleViewScreen> {
  final AuthService _authService = AuthService();
  List<UserModel> _trainers = [];
  UserModel? _selectedTrainer;
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _sessions = {};

  @override
  void initState() {
    super.initState();
    _loadTrainers();
  }

  Future<void> _loadTrainers() async {
    try {
      final trainers = await _authService.getAllTrainers();
      setState(() {
        _trainers = trainers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading trainers: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _loadTrainerSessions(String trainerId) async {
    try {
      // Load real sessions from Firestore using CalendlyService
      final calendlyService = CalendlyService();
      final allSessions = await calendlyService.getTrainerSessions(trainerId);
      
      // Group sessions by date
      final sessions = <DateTime, List<Map<String, dynamic>>>{};
      
      for (final session in allSessions) {
        final normalizedDate = DateTime(
          session.startTime.year, 
          session.startTime.month, 
          session.startTime.day
        );
        
        if (!sessions.containsKey(normalizedDate)) {
          sessions[normalizedDate] = [];
        }
        
        // Convert TrainingSession to Map for display
        // Handle family sessions by showing all family member names
        String displayName = session.clientName;
        if (session.isBookingForFamily && session.familyMembers != null && session.familyMembers!.isNotEmpty) {
          // Show all family member names
          final familyNames = session.familyMembers!
              .map((member) => member['name'] ?? 'Unknown')
              .toList();
          displayName = familyNames.join(', ');
        }
        
        sessions[normalizedDate]!.add({
          'id': session.id,
          'clientName': displayName,
          'originalClientName': session.clientName,
          'isBookingForFamily': session.isBookingForFamily,
          'familyMembers': session.familyMembers,
          'time': DateFormat('h:mm a').format(session.startTime),
          'endTime': DateFormat('h:mm a').format(session.endTime),
          'location': session.location,
          'type': session.sessionType ?? 'Training Session',
          'status': session.status,
          'duration': '${session.endTime.difference(session.startTime).inMinutes} minutes',
          'notes': session.notes,
          'calendlyUrl': session.calendlyUrl,
        });
      }
      
      setState(() {
        _sessions = sessions;
      });
    } catch (e) {
      print('Error loading trainer sessions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sessions: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
    }
  }

  void _showTrainerSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Trainer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _trainers.length,
              itemBuilder: (context, index) {
                final trainer = _trainers[index];
                final displayName = trainer.displayName ?? 
                    '${trainer.firstName ?? ''} ${trainer.lastName ?? ''}'.trim();
                final name = displayName.isNotEmpty ? displayName : trainer.email;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppStyles.primarySage.withOpacity(0.2),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'T',
                      style: TextStyle(
                        color: AppStyles.primarySage,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(name),
                  subtitle: Text(trainer.email),
                  onTap: () {
                    setState(() {
                      _selectedTrainer = trainer;
                    });
                    _loadTrainerSessions(trainer.uid);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _getSessionsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _sessions[normalizedDay] ?? [];
  }

  int _getTotalSessionsThisMonth() {
    final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    
    int total = 0;
    for (final entry in _sessions.entries) {
      if (entry.key.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
          entry.key.isBefore(endOfMonth.add(const Duration(days: 1)))) {
        total += entry.value.length;
      }
    }
    return total;
  }

  Map<String, double> _getAverageSessionsByDayOfWeek() {
    final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    
    final dayOfWeekCount = <String, int>{
      'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0
    };
    final dayOfWeekSessions = <String, int>{
      'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0
    };
    
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    // Only count sessions from the focused month
    for (final entry in _sessions.entries) {
      if (entry.key.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
          entry.key.isBefore(endOfMonth.add(const Duration(days: 1)))) {
        final dayOfWeek = entry.key.weekday; // 1 = Monday, 7 = Sunday
        final dayName = dayNames[dayOfWeek - 1];
        
        dayOfWeekCount[dayName] = dayOfWeekCount[dayName]! + 1;
        dayOfWeekSessions[dayName] = dayOfWeekSessions[dayName]! + entry.value.length;
      }
    }
    
    final averages = <String, double>{};
    for (final day in dayNames) {
      if (dayOfWeekCount[day]! > 0) {
        averages[day] = dayOfWeekSessions[day]! / dayOfWeekCount[day]!;
      } else {
        averages[day] = 0.0;
      }
    }
    
    return averages;
  }

  Widget _buildSessionsBarChart() {
    final averages = _getAverageSessionsByDayOfWeek();
    final maxAverage = averages.values.isNotEmpty 
        ? averages.values.reduce((a, b) => a > b ? a : b) 
        : 1.0;
    
    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: averages.entries.map((entry) {
          final dayName = entry.key;
          final average = entry.value;
          final barHeight = maxAverage > 0 ? (average / maxAverage) * 60 : 0.0; // Reduced from 80 to 60
          
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min, // Added to prevent overflow
              children: [
                // Average value text
                Text(
                  average.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppStyles.slateGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2), // Reduced from 4 to 2
                // Bar
                Container(
                  width: 20,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: AppStyles.primarySage,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 4), // Reduced from 8 to 4
                // Day name
                Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showSessionDetails(DateTime selectedDay) {
    final sessions = _getSessionsForDay(selectedDay);
    
    if (sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No sessions found for this day'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Header
                Text(
                  'Sessions for ${_formatDate(selectedDay)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Sessions list
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: sessions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _buildSessionCard(session);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final status = session['status'] ?? 'scheduled';
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (isCancelled) {
      statusColor = AppStyles.errorRed;
      statusText = 'CANCELLED';
      statusIcon = Icons.cancel;
    } else if (isCompleted) {
      statusColor = AppStyles.successGreen;
      statusText = 'COMPLETED';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = AppStyles.warningAmber;
      statusText = 'SCHEDULED';
      statusIcon = Icons.schedule;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppStyles.primarySage.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                session['isBookingForFamily'] == true ? Icons.family_restroom : Icons.person,
                color: AppStyles.primarySage,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session['clientName'] ?? 'Unknown Client',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                        color: isCancelled ? AppStyles.slateGray : AppStyles.textDark,
                      ),
                    ),
                    if (session['isBookingForFamily'] == true) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppStyles.primarySage.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Family Session',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppStyles.primarySage,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: AppStyles.slateGray,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${session['time'] ?? 'Unknown time'} - ${session['endTime'] ?? ''}',
                style: TextStyle(
                  color: AppStyles.slateGray,
                  fontSize: 14,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.schedule,
                color: AppStyles.slateGray,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                session['duration'] ?? 'Unknown duration',
                style: TextStyle(
                  color: AppStyles.slateGray,
                  fontSize: 14,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: AppStyles.slateGray,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session['location'] ?? 'Unknown location',
                  style: TextStyle(
                    color: AppStyles.slateGray,
                    fontSize: 14,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.fitness_center,
                color: AppStyles.slateGray,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session['type'] ?? 'Training',
                  style: TextStyle(
                    color: AppStyles.slateGray,
                    fontSize: 14,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          
          // Show notes if available
          if (session['notes'] != null && session['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppStyles.offWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppStyles.primarySage.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.note,
                        color: AppStyles.primarySage,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.primarySage,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    session['notes'].toString(),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppStyles.slateGray,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Show Calendly link if available
          if (session['calendlyUrl'] != null && session['calendlyUrl'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.link,
                  color: AppStyles.primarySage,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Calendly Event Available',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.primarySage,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainer Schedule'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Trainer selection
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppStyles.primarySage.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: AppStyles.primarySage,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Trainer',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.slateGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedTrainer?.displayName?.isNotEmpty == true
                            ? _selectedTrainer!.displayName!
                            : ('${_selectedTrainer?.firstName ?? ''} ${_selectedTrainer?.lastName ?? ''}'.trim().isNotEmpty
                                ? '${_selectedTrainer?.firstName ?? ''} ${_selectedTrainer?.lastName ?? ''}'.trim()
                                : _selectedTrainer?.email ?? 'No trainer selected'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _showTrainerSelectionDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyles.primarySage,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(_selectedTrainer == null ? 'Select' : 'Change'),
                ),
              ],
            ),
          ),
          
          // Calendar
          if (_selectedTrainer != null)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppStyles.primarySage.withOpacity(0.2)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                    // Calendar widget
                    TableCalendar<Map<String, dynamic>>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      eventLoader: _getSessionsForDay,
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        weekendTextStyle: TextStyle(color: AppStyles.slateGray),
                        holidayTextStyle: TextStyle(color: AppStyles.slateGray),
                        selectedDecoration: BoxDecoration(
                          color: AppStyles.primarySage,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: AppStyles.primarySage.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: AppStyles.successGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        _showSessionDetails(selectedDay);
                      },
                                        onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                    ),
                    
                    // Session statistics
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppStyles.offWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppStyles.primarySage.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Total sessions this month
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Sessions - ${DateFormat('MMMM yyyy').format(_focusedDay)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppStyles.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_getTotalSessionsThisMonth()}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppStyles.primarySage,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.calendar_month,
                                color: AppStyles.primarySage,
                                size: 32,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Average sessions by day of week
                          Text(
                            'Average Sessions by Day',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppStyles.textDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildSessionsBarChart(),
                        ],
                      ),
                    ),
                  ],
                  ),
                ),
              ),
            ),
          
          // Add bottom spacing after calendar card
          if (_selectedTrainer != null)
            const SizedBox(height: 24),
          
          if (_selectedTrainer == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 64,
                      color: AppStyles.slateGray.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select a trainer to view their schedule',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppStyles.slateGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
} 