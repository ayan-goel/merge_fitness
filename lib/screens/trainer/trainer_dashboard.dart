import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/calendly_service.dart';
import '../../models/user_model.dart';
import '../../screens/home_screen.dart';
import 'create_template_screen.dart';
import 'trainer_scheduling_screen.dart';

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({super.key});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  final AuthService _authService = AuthService();
  final CalendlyService _calendlyService = CalendlyService();
  UserModel? _trainer;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activityItems = [];

  @override
  void initState() {
    super.initState();
    _loadTrainerData();
  }

  Future<void> _loadTrainerData() async {
    try {
      final user = await _authService.getUserModel();
      setState(() {
        _trainer = user;
      });
      
      // Load activity feed
      await _loadActivityFeed();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading trainer data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadActivityFeed() async {
    try {
      if (_trainer == null) return;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('activityFeed')
          .where('trainerId', isEqualTo: _trainer!.uid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      
      final activities = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'message': data['message'] ?? 'Unknown activity',
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'relatedId': data['relatedId'],
        };
      }).toList();
      
      setState(() {
        _activityItems = activities;
      });
    } catch (e) {
      print("Error loading activity feed: $e");
      
      // If the error is about indexes building, try an alternative approach
      if (e.toString().contains('index is currently building') || 
          e.toString().contains('requires an index')) {
        try {
          // Get without ordering (works without index)
          final snapshot = await FirebaseFirestore.instance
              .collection('activityFeed')
              .where('trainerId', isEqualTo: _trainer!.uid)
              .get();
          
          // Process and sort manually
          final activities = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'type': data['type'] ?? 'unknown',
              'message': data['message'] ?? 'Unknown activity',
              'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'relatedId': data['relatedId'],
            };
          }).toList();
          
          // Sort manually by timestamp
          activities.sort((a, b) {
            final aTime = a['timestamp'] as DateTime;
            final bTime = b['timestamp'] as DateTime;
            return bTime.compareTo(aTime); // descending
          });
          
          // Limit to 10 items
          final limitedActivities = activities.take(10).toList();
          
          setState(() {
            _activityItems = limitedActivities;
          });
        } catch (fallbackError) {
          print("Fallback error loading activity feed: $fallbackError");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trainer == null) {
      return const Center(child: Text('Error loading trainer data'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${_trainer!.displayName ?? 'Trainer'}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trainer Dashboard',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(_trainer!.email),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionCard(
                context,
                icon: Icons.people,
                title: 'Clients',
                onTap: () {
                  // Navigate to Clients tab (index 1)
                  HomeScreen.navigateToTab(context, 1);
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.calendar_month,
                title: 'Scheduling',
                onTap: () {
                  // Navigate to Scheduling screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TrainerSchedulingScreen(),
                    ),
                  ).then((_) {
                    // Refresh activity feed when returning
                    _loadActivityFeed();
                  });
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.fitness_center,
                title: 'New Workout',
                onTap: () {
                  // Navigate to Create Template screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateTemplateScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Activity feed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: _loadActivityFeed,
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              child: _activityItems.isEmpty
                ? const Center(
                    child: Text('No recent activities'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _activityItems.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final activity = _activityItems[index];
                      return _buildActivityItem(activity);
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final IconData icon;
    final Color iconColor;
    
    // Determine icon and color based on activity type
    switch (activity['type']) {
      case 'session_scheduled':
        icon = Icons.calendar_month;
        iconColor = Colors.green;
        break;
      case 'workout_assigned':
        icon = Icons.fitness_center;
        iconColor = Colors.blue;
        break;
      case 'workout_completed':
        icon = Icons.check_circle;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
    }
    
    // Format timestamp
    final timestamp = activity['timestamp'] as DateTime;
    final formattedDate = _formatActivityDate(timestamp);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.2),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(activity['message']),
      subtitle: Text(formattedDate),
      onTap: () => _handleActivityTap(activity),
    );
  }
  
  void _handleActivityTap(Map<String, dynamic> activity) {
    // Handle navigation based on activity type
    switch (activity['type']) {
      case 'session_scheduled':
        // Navigate to scheduling screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TrainerSchedulingScreen(),
          ),
        );
        break;
      default:
        // Do nothing for other types for now
        break;
    }
  }
  
  String _formatActivityDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final activityDate = DateTime(date.year, date.month, date.day);
    
    if (activityDate == today) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (activityDate == yesterday) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: 2,
        child: Container(
          width: MediaQuery.of(context).size.width / 3.5, // Responsive width based on screen size
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 