import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/calendly_service.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import 'location_sharing_screen.dart';

class TrainerSchedulingScreen extends StatefulWidget {
  const TrainerSchedulingScreen({super.key});

  @override
  State<TrainerSchedulingScreen> createState() => _TrainerSchedulingScreenState();
}

class _TrainerSchedulingScreenState extends State<TrainerSchedulingScreen> {
  final AuthService _authService = AuthService();
  final CalendlyService _calendlyService = CalendlyService();
  
  bool _isLoading = true;
  UserModel? _trainer;
  List<TrainingSession> _allSessions = [];
  List<TrainingSession> _upcomingSessions = [];
  List<TrainingSession> _cancelledSessions = [];
  bool _isCalendlyConnected = false;
  
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
      
      // Separate sessions into upcoming (not cancelled) and cancelled
      final now = DateTime.now();
      final upcomingSessions = allSessions
          .where((session) => 
              session.startTime.isAfter(now) && 
              session.status != 'cancelled')
          .toList();
      
      // Get cancelled future sessions
      final cancelledSessions = allSessions
          .where((session) => 
              session.startTime.isAfter(now) && 
              session.status == 'cancelled')
          .toList();
      
      // Sort by date
      upcomingSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
      cancelledSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      setState(() {
        _trainer = trainer;
        _allSessions = allSessions;
        _upcomingSessions = upcomingSessions;
        _cancelledSessions = cancelledSessions;
        _isCalendlyConnected = isConnected;
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
      length: 2,
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
              Tab(text: 'Upcoming'),
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
                  // Upcoming Sessions Tab
                  _upcomingSessions.isEmpty
                      ? _buildNoSessionsMessage('No upcoming sessions')
                      : _buildSessionsList(_upcomingSessions),
                  
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
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              const Text(
                'Calendly Not Connected',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'You need to connect your Calendly account to manage training sessions. Go to your profile to set it up.',
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // Navigate to Profile page
              Navigator.pushNamed(context, '/trainer/profile');
            },
            child: const Text('Go to Profile'),
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
            ...sessions.map((session) => _buildSessionRow(session)).toList(),
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
  
  Widget _buildSessionRow(TrainingSession session) {
    final bool isCancelled = session.status == 'cancelled';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          color: isCancelled ? Colors.grey.shade100 : null,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: isCancelled
                      ? Colors.grey.withOpacity(0.2)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.fitness_center,
                    color: isCancelled ? Colors.grey : Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  session.clientName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                    color: isCancelled ? Colors.grey : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${DateFormat('h:mm a').format(session.startTime)} - ${DateFormat('h:mm a').format(session.endTime)}',
                            style: TextStyle(
                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                              color: isCancelled ? Colors.grey : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (session.sessionType != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.category, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              session.sessionType!,
                              style: TextStyle(
                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                                color: isCancelled ? Colors.grey : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.email, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session.clientEmail,
                            style: TextStyle(
                              fontSize: 12,
                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                              color: isCancelled ? Colors.grey : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    if (isCancelled) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CANCELLED',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    if (session.calendlyUrl != null)
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 20),
                        tooltip: 'View in Calendly',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          final url = Uri.parse(session.calendlyUrl!);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    if (!isCancelled)
                      IconButton(
                        icon: const Icon(Icons.location_on, color: Colors.blue, size: 20),
                        tooltip: 'Share Location',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: () => _navigateToLocationSharing(session),
                      ),
                    if (session.canBeCancelled)
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                        tooltip: 'Cancel Session',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: () => _showCancelSessionDialog(session),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to cancel this session?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Client: ${session.clientName}'),
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
          await _loadTrainerData();
          
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
} 