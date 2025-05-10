import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final TextEditingController _calendlyUrlController = TextEditingController();
  
  bool _isLoading = true;
  UserModel? _trainer;
  List<TrainingSession> _sessions = [];
  bool _isCalendlyConnected = false;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _loadTrainerData();
  }
  
  @override
  void dispose() {
    _calendlyUrlController.dispose();
    super.dispose();
  }
  
  Future<void> _loadTrainerData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load trainer profile
      final trainer = await _authService.getUserModel();
      
      // Load Calendly URL
      final calendlyUrl = await _calendlyService.getTrainerCalendlyUrl(trainer.uid);
      if (calendlyUrl != null) {
        _calendlyUrlController.text = calendlyUrl;
        _isCalendlyConnected = true;
      }
      
      // Load sessions
      final sessions = await _calendlyService.getTrainerSessions(trainer.uid);
      
      setState(() {
        _trainer = trainer;
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading trainer data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveCalendlyUrl() async {
    if (_calendlyUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Calendly URL')),
      );
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      await _calendlyService.saveTrainerCalendlyUrl(_calendlyUrlController.text);
      
      setState(() {
        _isCalendlyConnected = true;
        _isSaving = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendly URL saved successfully')),
      );
    } catch (e) {
      print('Error saving Calendly URL: $e');
      setState(() {
        _isSaving = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving Calendly URL: $e')),
      );
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
                    
                    TextField(
                      controller: _calendlyUrlController,
                      decoration: InputDecoration(
                        labelText: 'Your Calendly URL',
                        hintText: 'https://calendly.com/yourname',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon: _isSaving
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : IconButton(
                              icon: const Icon(Icons.save),
                              onPressed: _saveCalendlyUrl,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      'Enter your Calendly URL to allow clients to schedule sessions with you.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openCalendlySettings,
                          icon: const Icon(Icons.settings),
                          label: const Text('Manage Calendly Settings'),
                        ),
                        
                        if (_isCalendlyConnected) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Connected',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
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