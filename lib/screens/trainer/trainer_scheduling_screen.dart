import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/calendly_service.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';

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
  List<TrainingSession> _sessions = [];
  bool _isCalendlyConnected = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;
  String? _calendlyUrl;
  List<Map<String, dynamic>> _eventTypes = [];
  String? _selectedEventType;
  String? _selectedEventTypeName;
  
  @override
  void initState() {
    super.initState();
    _loadTrainerData();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  Future<void> _loadTrainerData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load trainer profile
      final trainer = await _authService.getUserModel();
      
      // Load Calendly URL and connection status
      final calendlyUrl = await _calendlyService.getTrainerCalendlyUrl(trainer.uid);
      
      bool isConnected = false;
      if (calendlyUrl != null) {
        _calendlyUrl = calendlyUrl;
        isConnected = true;
        
        // Load event types if connected
        if (isConnected) {
          try {
            final eventTypes = await _calendlyService.getTrainerEventTypes(trainer.uid);
            _eventTypes = eventTypes;
            
            // Get selected event type
            final doc = await FirebaseFirestore.instance.collection('users').doc(trainer.uid).get();
            final data = doc.data();
            _selectedEventType = data?['selectedCalendlyEventType'] as String?;
            
            // Find the matching event type name
            if (_selectedEventType != null) {
              final selectedEvent = _eventTypes.firstWhere(
                (event) => event['uri'] == _selectedEventType,
                orElse: () => {'name': 'Unknown Event Type'},
              );
              _selectedEventTypeName = selectedEvent['name'];
            }
          } catch (e) {
            print('Error loading event types: $e');
          }
        }
      }
      
      // Load sessions
      final sessions = await _calendlyService.getTrainerSessions(trainer.uid);
      
      setState(() {
        _trainer = trainer;
        _sessions = sessions;
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
  
  Future<void> _connectCalendly() async {
    setState(() {
      _isConnecting = true;
    });
    
    try {
      final token = await _calendlyService.connectCalendlyAccount();
      
      // After connecting, load event types to let the user select one
      await _loadTrainerData();
      
      if (mounted && _eventTypes.isNotEmpty) {
        // Show dialog to select event type
        await _showEventTypeSelectionDialog();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calendly connected successfully')),
        );
      }
    } catch (e) {
      print('Error connecting Calendly: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting Calendly: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }
  
  Future<void> _disconnectCalendly() async {
    // Show confirmation dialog
    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Calendly'),
        content: const Text('Are you sure you want to disconnect your Calendly account? Clients will no longer be able to schedule sessions with you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!shouldDisconnect) return;
    
    setState(() {
      _isDisconnecting = true;
    });
    
    try {
      await _calendlyService.disconnectCalendlyAccount();
      
      // Reload trainer data to update UI
      await _loadTrainerData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calendly disconnected successfully')),
        );
      }
    } catch (e) {
      print('Error disconnecting Calendly: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error disconnecting Calendly: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDisconnecting = false;
        });
      }
    }
  }
  
  Future<void> _showEventTypeSelectionDialog() async {
    // Filter to only show active event types
    final activeEventTypes = _eventTypes.where((type) => type['active'] == true).toList();
    
    if (activeEventTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active event types found. Please activate at least one event type in your Calendly account.')),
      );
      return;
    }
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Calendar for Scheduling'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: activeEventTypes.length,
            itemBuilder: (context, index) {
              final eventType = activeEventTypes[index];
              final name = eventType['name'] ?? 'Unknown';
              final duration = eventType['duration'] != null 
                  ? '${eventType['duration']} min' 
                  : '';
              
              return ListTile(
                title: Text(name),
                subtitle: duration.isNotEmpty ? Text(duration) : null,
                onTap: () async {
                  Navigator.of(context).pop();
                  await _selectEventType(eventType['uri'], name);
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
      ),
    );
  }
  
  Future<void> _selectEventType(String eventTypeUri, String eventTypeName) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _calendlyService.selectCalendlyEventType(eventTypeUri);
      
      setState(() {
        _selectedEventType = eventTypeUri;
        _selectedEventTypeName = eventTypeName;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected calendar: $eventTypeName')),
      );
    } catch (e) {
      print('Error selecting event type: $e');
      
      String errorMessage = 'Error selecting calendar';
      if (e.toString().contains('Cannot select inactive event type')) {
        errorMessage = 'This calendar is inactive. Please activate it in Calendly first.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _openCalendlySettings() async {
    final url = Uri.parse('https://calendly.com/event_types/user/me');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Calendly settings')),
        );
      }
    }
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
        title: const Text('Scheduling'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendly Connection Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Calendly Connection',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (_isCalendlyConnected) ...[
                      // Show connected status and URL
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Calendly Connected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your scheduling link:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _calendlyUrl ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.content_copy, size: 18),
                                  onPressed: () {
                                    // Copy URL to clipboard
                                    if (_calendlyUrl != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('URL copied to clipboard')),
                                      );
                                    }
                                  },
                                  tooltip: 'Copy to clipboard',
                                ),
                              ],
                            ),
                            if (_selectedEventTypeName != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Selected calendar:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.event, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _selectedEventTypeName!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _showEventTypeSelectionDialog(),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: const Size(40, 36),
                                    ),
                                    child: const Text('Change'),
                                  ),
                                ],
                              ),
                            ] else if (_eventTypes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showEventTypeSelectionDialog(),
                                icon: const Icon(Icons.calendar_month, size: 18),
                                label: const Text('Select Calendar'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: const Size(40, 36),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      // Show connect button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Connect your Calendly account to enable client scheduling',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isConnecting ? null : _connectCalendly,
                                icon: _isConnecting 
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.link),
                                label: Text(_isConnecting ? 'Connecting...' : 'Connect Calendly'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    if (_isCalendlyConnected) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openCalendlySettings,
                              icon: const Icon(Icons.settings),
                              label: const Text('Manage Calendly Settings'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _isDisconnecting ? null : _disconnectCalendly,
                            icon: _isDisconnecting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.link_off, color: Colors.red),
                            label: Text(
                              _isDisconnecting ? 'Disconnecting...' : 'Disconnect',
                              style: TextStyle(
                                color: _isDisconnecting ? Colors.grey : Colors.red,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Note: You must have a Calendly account to use this feature.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Upcoming Sessions
            Text(
              'Upcoming Sessions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            if (_sessions.isEmpty) ...[
              // Empty state
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No upcoming sessions',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When clients schedule sessions with you, they will appear here',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Sessions list
              ..._buildSessionsList(),
            ],
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildSessionsList() {
    // Group sessions by date
    final Map<String, List<TrainingSession>> sessionsByDate = {};
    
    for (final session in _sessions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(session.startTime);
      
      if (!sessionsByDate.containsKey(dateKey)) {
        sessionsByDate[dateKey] = [];
      }
      
      sessionsByDate[dateKey]!.add(session);
    }
    
    // Sort dates
    final sortedDates = sessionsByDate.keys.toList()..sort();
    
    // Build list
    final List<Widget> widgets = [];
    
    for (final dateKey in sortedDates) {
      final date = DateTime.parse(dateKey);
      
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            DateFormat('EEEE, MMMM d').format(date),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );
      
      for (final session in sessionsByDate[dateKey]!) {
        widgets.add(
          _buildSessionCard(session),
        );
      }
    }
    
    return widgets;
  }
  
  Widget _buildSessionCard(TrainingSession session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time
                      Text(
                        session.formattedTimeRange,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Client name - would need to fetch in a real app
                      FutureBuilder<String>(
                        future: _getClientName(session.clientId),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? 'Client',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      
                      // Location
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                              session.location,
                              style: TextStyle(
                                color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    session.status.toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            // Display notes if any
            if (session.notes != null && session.notes!.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Notes:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                session.notes!,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Helper to get client name from ID
  Future<String> _getClientName(String clientId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(clientId).get();
      if (doc.exists) {
        return doc.data()?['displayName'] ?? 'Client';
      }
      return 'Client';
    } catch (e) {
      print('Error getting client name: $e');
      return 'Client';
    }
  }
} 