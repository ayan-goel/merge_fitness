import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/auth_service.dart';
import '../../services/calendly_service.dart';
import '../../services/video_call_service.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import 'location_sharing_screen.dart';
import '../shared/video_call_screen.dart';
import '../../theme/app_styles.dart';
import '../../theme/app_widgets.dart';
import '../../theme/app_animations.dart';

class TrainerSchedulingScreen extends StatefulWidget {
  const TrainerSchedulingScreen({super.key});

  @override
  State<TrainerSchedulingScreen> createState() => _TrainerSchedulingScreenState();
}

class _TrainerSchedulingScreenState extends State<TrainerSchedulingScreen> {
  final AuthService _authService = AuthService();
  final CalendlyService _calendlyService = CalendlyService();
  final VideoCallService _videoCallService = VideoCallService();
  
  bool _isLoading = true;
  UserModel? _trainer;
  List<TrainingSession> _allSessions = [];
  List<TrainingSession> _upcomingSessions = [];
  List<TrainingSession> _cancelledSessions = [];
  List<TrainingSession> _completedSessions = [];
  bool _isCalendlyConnected = false;
  
  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<TrainingSession>> _sessionsByDate = {};
  
  @override
  void initState() {
    super.initState();
    _loadTrainerData();
  }
  
  Future<void> _loadTrainerData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load trainer profile
      final trainer = await _authService.getUserModel();
      
      // Check if Calendly is connected
      final calendlyUrl = await _calendlyService.getTrainerCalendlyUrl(trainer.uid);
      bool isConnected = calendlyUrl != null;
      
      // Load all sessions
      final allSessions = await _calendlyService.getTrainerSessions(trainer.uid);
      
      // Separate sessions into upcoming, cancelled, and completed
      final now = DateTime.now();
      final upcomingSessions = allSessions
          .where((session) => 
              session.startTime.isAfter(now) && 
              session.status != 'cancelled')
          .toList();
      
      // Get all cancelled sessions (both past and future)
      final cancelledSessions = allSessions
          .where((session) => session.status == 'cancelled')
          .toList();
      
      // Get completed sessions (past sessions that are NOT cancelled, or sessions marked as completed)
      final completedSessions = allSessions
          .where((session) => 
              session.status != 'cancelled' && 
              (session.startTime.isBefore(now) || session.status == 'completed'))
          .toList();
      
      // Sort by date
      upcomingSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
      cancelledSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
      completedSessions.sort((a, b) => b.startTime.compareTo(a.startTime)); // Most recent first
      
      // Group sessions by date for calendar
      final sessionsByDate = <DateTime, List<TrainingSession>>{};
      for (final session in allSessions) {
        final dateKey = DateTime(
          session.startTime.year,
          session.startTime.month,
          session.startTime.day,
        );
        if (!sessionsByDate.containsKey(dateKey)) {
          sessionsByDate[dateKey] = [];
        }
        sessionsByDate[dateKey]!.add(session);
      }
      
      setState(() {
        _trainer = trainer;
        _allSessions = allSessions;
        _upcomingSessions = upcomingSessions;
        _cancelledSessions = cancelledSessions;
        _completedSessions = completedSessions;
        _isCalendlyConnected = isConnected;
        _sessionsByDate = sessionsByDate;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading trainer data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Training Sessions'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadTrainerData,
              tooltip: 'Refresh',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isCalendlyConnected)
              _buildCalendlyDisconnectedWarning(),
            
            Expanded(
              child: TabBarView(
                children: [
                  // All Sessions Tab - Calendar View
                  _buildCalendarView(),
                  
                  // Upcoming Sessions Tab
                  _upcomingSessions.isEmpty
                      ? _buildNoSessionsMessage('No upcoming sessions')
                      : _buildSessionsList(_upcomingSessions),
                  
                  // Completed Sessions Tab
                  _completedSessions.isEmpty
                      ? _buildNoSessionsMessage('No completed sessions')
                      : _buildSessionsList(_completedSessions),
                  
                  // Cancelled Sessions Tab
                  _cancelledSessions.isEmpty
                      ? _buildNoSessionsMessage('No cancelled sessions')
                      : _buildSessionsList(_cancelledSessions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCalendlyDisconnectedWarning() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppStyles.offWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppStyles.primarySage.withOpacity(0.5), width: 1.5),
        boxShadow: AppStyles.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber, color: AppStyles.warningAmber, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Calendly Not Connected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppStyles.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'You need to connect your Calendly account to manage training sessions. Go to your profile to set it up.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppStyles.textDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to Profile page
                  Navigator.pushNamed(context, '/trainer/profile');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyles.primarySage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Go to Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoSessionsMessage(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Sessions will appear here when scheduled',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSessionsList(List<TrainingSession> sessions) {
    // Group sessions by date
    final Map<String, List<TrainingSession>> groupedSessions = {};
    
    for (final session in sessions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(session.startTime);
      if (!groupedSessions.containsKey(dateKey)) {
        groupedSessions[dateKey] = [];
      }
      groupedSessions[dateKey]!.add(session);
    }
    
    // Create sorted list of date keys
    final sortedDates = groupedSessions.keys.toList()..sort();
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedDates.length,
      itemBuilder: (context, dateIndex) {
        final dateKey = sortedDates[dateIndex];
        final sessions = groupedSessions[dateKey]!;
        final date = DateTime.parse(dateKey);
        
        // Check if this date is today
        final now = DateTime.now();
        final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                children: [
                  Text(
                    _formatDateHeading(date),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...sessions.map((session) => AppAnimations.fadeSlide(
              beginOffset: const Offset(0, 0.05),
              duration: Duration(milliseconds: 400 + sessions.indexOf(session) * 100),
              child: _buildSessionRow(session),
            )).toList(),
            if (dateIndex < sortedDates.length - 1)
              const Divider(height: 32),
          ],
        );
      },
    );
  }
  
  String _formatDateHeading(DateTime date) {
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
  
  Widget _buildCalendarView() {
    if (_allSessions.isEmpty) {
      return _buildNoSessionsMessage('No sessions scheduled');
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Calendar Card
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppStyles.primarySage.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: AppStyles.primarySage,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Session Calendar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TableCalendar<TrainingSession>(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                eventLoader: (day) {
                  final dateKey = DateTime(day.year, day.month, day.day);
                  return _sessionsByDate[dateKey] ?? [];
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _showDaySessionsDialog(selectedDay);
                  }
                },
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(color: AppStyles.slateGray),
                  selectedTextStyle: const TextStyle(color: Colors.white),
                  selectedDecoration: BoxDecoration(
                    color: AppStyles.primarySage,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppStyles.primarySage.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: AppStyles.successGreen,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 1,
                  markerSize: 6.0,
                  markerMargin: const EdgeInsets.symmetric(horizontal: 1.5),
                ),
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.textDark,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: AppStyles.textDark),
                  weekendStyle: TextStyle(color: AppStyles.textDark),
                ),
                startingDayOfWeek: StartingDayOfWeek.monday,
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
              ),
            ],
          ),
        ),
        
        // Sessions List (same structure as other tabs)
        ..._buildGroupedSessionsList(_allSessions),
      ],
    );
  }
  
  List<Widget> _buildGroupedSessionsList(List<TrainingSession> sessions) {
    // Group sessions by date
    final Map<String, List<TrainingSession>> groupedSessions = {};
    
    for (final session in sessions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(session.startTime);
      if (!groupedSessions.containsKey(dateKey)) {
        groupedSessions[dateKey] = [];
      }
      groupedSessions[dateKey]!.add(session);
    }
    
    // Create sorted list of date keys
    final sortedDates = groupedSessions.keys.toList()..sort();
    
    List<Widget> widgets = [];
    
    for (int dateIndex = 0; dateIndex < sortedDates.length; dateIndex++) {
      final dateKey = sortedDates[dateIndex];
      final sessionsForDate = groupedSessions[dateKey]!;
      final date = DateTime.parse(dateKey);
      
      // Check if this date is today
      final now = DateTime.now();
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      
      // Date heading
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            children: [
              Text(
                _formatDateHeading(date),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'TODAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
      
      // Sessions for this date
      for (final session in sessionsForDate) {
        widgets.add(
          AppAnimations.fadeSlide(
            beginOffset: const Offset(0, 0.05),
            duration: Duration(milliseconds: 400 + sessionsForDate.indexOf(session) * 100),
            child: _buildSessionRow(session),
          ),
        );
      }
      
      // Add divider between dates (except for last one)
      if (dateIndex < sortedDates.length - 1) {
        widgets.add(const Divider(height: 32));
      }
    }
    
    return widgets;
  }
  
  void _showDaySessionsDialog(DateTime selectedDay) {
    final dateKey = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final sessionsForDay = _sessionsByDate[dateKey] ?? [];
    
    if (sessionsForDay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No sessions scheduled for ${DateFormat('EEEE, MMMM d').format(selectedDay)}'),
          backgroundColor: AppStyles.primarySage,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(selectedDay),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppStyles.primarySage.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${sessionsForDay.length} session${sessionsForDay.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppStyles.primarySage,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Sessions list
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sessionsForDay.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = sessionsForDay[index];
                      return _buildSessionRow(session);
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSessionRow(TrainingSession session) {
    final bool isCancelled = session.status == 'cancelled';
    final bool isCompleted = session.status == 'completed' || session.startTime.isBefore(DateTime.now());
    
          return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppStyles.cardShadow,
          border: isCancelled 
              ? Border.all(color: Colors.grey.withOpacity(0.3), width: 1)
              : isCompleted 
                  ? Border.all(color: AppStyles.primarySage.withOpacity(0.3), width: 1)
                  : null,
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? AppStyles.slateGray.withOpacity(0.2)
                          : isCompleted
                              ? AppStyles.primarySage.withOpacity(0.2)
                              : AppStyles.offWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: isCancelled 
                          ? Border.all(color: Colors.grey.withOpacity(0.5), width: 1)
                          : isCompleted
                              ? Border.all(color: AppStyles.primarySage.withOpacity(0.5), width: 1)
                              : null,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_circle : 
                      session.isBookingForFamily ? Icons.family_restroom : Icons.fitness_center,
                      color: isCancelled 
                          ? Colors.grey 
                          : isCompleted 
                              ? AppStyles.primarySage 
                              : AppStyles.primarySage,
                      size: 24,
                    ),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.isBookingForFamily && session.familyMembers != null && session.familyMembers!.isNotEmpty
                            ? session.familyMembers!.map((member) => member['name'] ?? 'Unknown').join(', ')
                            : session.clientName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                          color: isCancelled ? AppStyles.slateGray : AppStyles.textDark,
                        ),
                      ),
                      if (session.isBookingForFamily) ...[
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                                              Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: isCancelled 
                                  ? Colors.grey 
                                  : isCompleted 
                                      ? AppStyles.primarySage 
                                      : AppStyles.primarySage,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${DateFormat('h:mm a').format(session.startTime)} - ${DateFormat('h:mm a').format(session.endTime)}',
                                style: TextStyle(
                                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                                  color: isCancelled 
                                      ? AppStyles.slateGray 
                                      : isCompleted 
                                          ? AppStyles.slateGray.withOpacity(0.8) 
                                          : AppStyles.slateGray,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: isCancelled ? Colors.grey : AppStyles.primarySage,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              session.location,
                              style: TextStyle(
                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                                color: isCancelled ? AppStyles.slateGray : AppStyles.slateGray,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (isCancelled) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CANCELLED',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (isCompleted && !isCancelled) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppStyles.primarySage.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'COMPLETED',
                            style: TextStyle(
                              color: AppStyles.primarySage,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppStyles.primarySage,
                    ),
                    onSelected: (value) async {
                      switch (value) {
                        case 'calendly':
                          if (session.calendlyUrl != null) {
                            final url = Uri.parse(session.calendlyUrl!);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          }
                          break;
                        case 'video':
                          _startVideoCall(session);
                          break;
                        case 'location':
                          _navigateToLocationSharing(session);
                          break;
                        case 'cancel':
                          _showCancelSessionDialog(session);
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      List<PopupMenuEntry<String>> items = [];
                      
                      if (session.calendlyUrl != null) {
                        items.add(
                          const PopupMenuItem<String>(
                            value: 'calendly',
                            child: Row(
                              children: [
                                Icon(Icons.open_in_new, size: 18, color: AppStyles.primarySage),
                                SizedBox(width: 12),
                                Text('View in Calendly'),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // Allow video calls for any session that's not cancelled and not explicitly marked as completed
                      if (!isCancelled && session.status != 'completed') {
                        items.addAll([
                          const PopupMenuItem<String>(
                            value: 'video',
                            child: Row(
                              children: [
                                Icon(Icons.videocam, size: 18, color: AppStyles.primarySage),
                                SizedBox(width: 12),
                                Text('Start Video Call'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'location',
                            child: Row(
                              children: [
                                Icon(Icons.location_on, size: 18, color: AppStyles.taupeBrown),
                                SizedBox(width: 12),
                                Text('Share Location'),
                              ],
                            ),
                          ),
                        ]);
                      }
                      
                      // Allow cancellation for sessions that haven't started yet
                      if (!isCancelled && session.status != 'completed' && session.startTime.isAfter(DateTime.now())) {
                        items.add(
                          const PopupMenuItem<String>(
                            value: 'cancel',
                            child: Row(
                              children: [
                                Icon(Icons.cancel_outlined, size: 18, color: AppStyles.errorRed),
                                SizedBox(width: 12),
                                Text('Cancel Session'),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      return items;
                    },
                  ),
                ),
              ],
            ),
          ),
          if (session.notes != null && session.notes!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppStyles.offWhite,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NOTES',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.slateGray,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.notes!,
                    style: TextStyle(
                      color: isCancelled ? AppStyles.slateGray.withOpacity(0.7) : AppStyles.slateGray,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // Navigate to location sharing screen
  void _navigateToLocationSharing(TrainingSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSharingScreen(session: session),
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
            backgroundColor: AppStyles.offWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to cancel this session?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppStyles.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.offWhite,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: AppStyles.primarySage,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Date: ${session.formattedDate}',
                            style: const TextStyle(color: AppStyles.textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppStyles.primarySage,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Time: ${session.formattedTimeRange}',
                            style: const TextStyle(color: AppStyles.textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 16,
                            color: AppStyles.primarySage,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Client: ${session.clientName}',
                              style: const TextStyle(color: AppStyles.textDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Reason for cancellation (optional):',
                  style: TextStyle(color: AppStyles.textDark),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Enter reason here',
                    hintStyle: TextStyle(color: AppStyles.slateGray.withOpacity(0.5)),
                    filled: true,
                    fillColor: AppStyles.offWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppStyles.primarySage, width: 2),
                    ),
                  ),
                  style: const TextStyle(color: AppStyles.textDark),
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppStyles.textDark,
                ),
                child: const Text('No, Keep It'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyles.errorRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Yes, Cancel'),
              ),
            ],
          );
        },
      );
      
      if (result == true) {
        setState(() {
          _isLoading = true;
        });
        
        final reason = reasonController.text;
        
        await _calendlyService.cancelSession(
          session.id,
          cancellationReason: reason.isEmpty ? null : reason,
        );
        
        await _loadTrainerData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Session cancelled successfully'),
              backgroundColor: AppStyles.offWhite,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling session: $e'),
            backgroundColor: AppStyles.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }

  // Start video call for session
  Future<void> _startVideoCall(TrainingSession session) async {
    try {
      print('Trainer: Starting video call for session ${session.id}');
      print('Trainer: Session details - trainerId: ${session.trainerId}, clientId: ${session.clientId}');
      
      setState(() {
        _isLoading = true;
      });

      // Create video call with session details first
      final videoCall = await _videoCallService.createVideoCall(
        session.id,
        trainerId: session.trainerId,
        clientId: session.clientId,
      );
      
      print('Trainer: Video call created successfully: ${videoCall.id}');
      print('Trainer: Video call details: ${videoCall.toMap()}');
      
      setState(() {
        _isLoading = false;
      });

      // Navigate to video call screen (let it handle permissions)
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              callId: videoCall.id,
              isTrainer: true,
              sessionId: session.id,
            ),
          ),
        );
      }
    } catch (e) {
      print('Trainer: Error starting video call: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start video call: $e'),
            backgroundColor: AppStyles.errorRed,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
} 