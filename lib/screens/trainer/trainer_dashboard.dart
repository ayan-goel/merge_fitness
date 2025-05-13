import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/calendly_service.dart';
import '../../models/user_model.dart';
import '../../screens/home_screen.dart';
import '../../theme/app_styles.dart';
import 'create_template_screen.dart';
import 'trainer_scheduling_screen.dart';
import 'client_details_screen.dart';

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

  // Add a list of motivational messages at the class level
  final List<String> _motivationalMessages = [
    "Get ready to crush the day!",
    "Today is a chance to be better than yesterday.",
    "Be the trainer you would want to have.",
    "Every session is an opportunity to change someone's life.",
    "Create the energy your clients need today.",
    "Your dedication inspires others.",
    "Small steps lead to big transformations.",
    "Make every rep count.",
    "Consistency is your superpower.",
    "Your energy is contagious - make it positive!",
    "Be the motivation your clients are looking for.",
    "Celebrate progress, not perfection.",
    "Transform challenges into opportunities.",
    "Today's efforts are tomorrow's results.",
    "Lead by example, inspire through action.",
    "You're building more than just bodies - you're building confidence.",
    "Connect with purpose in every session.",
    "Focus on form before intensity.",
    "Empower others through your knowledge.",
    "Make wellness a lifestyle, not just a workout.",
    "Share your passion and watch it multiply.",
    "Excellence is not an act, but a habit.",
    "Push limits, not patience.",
    "Create experiences, not just exercises.",
    "Be legendary today.",
    "Your attitude determines your altitude.",
    "Today's sweat is tomorrow's strength.",
    "Plant seeds of health that grow for a lifetime.",
    "Build strength in body, mind, and spirit.",
    "Coaching changes lives - make it count.",
    "Turn 'I can't' into 'I will'.",
    "Progress happens one client at a time.",
    "The energy you bring determines the results they get.",
    "Fitness is the foundation, motivation is the key.",
    "Create habits, not expectations.",
    "The best trainers are also the best students.",
    "Today's plan is tomorrow's achievement.",
    "Be relentless in pursuit of their goals.",
    "Health is wealth - help others invest wisely.",
    "Strength isn't just physical - build mental toughness too."
  ];
  
  // Get a random motivational message
  String get _randomMotivationalMessage {
    final random = DateTime.now().millisecondsSinceEpoch;
    return _motivationalMessages[random % _motivationalMessages.length];
  }

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
          .limit(50) // Increase limit to show more activities
          .get();
      
      final activities = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'message': data['message'] ?? 'Unknown activity',
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'relatedId': data['relatedId'],
          'clientId': data['clientId'],
          'cancellationReason': data['cancellationReason'],
          'cancelledBy': data['cancelledBy'],
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
              'clientId': data['clientId'],
              'cancellationReason': data['cancellationReason'],
              'cancelledBy': data['cancelledBy'],
            };
          }).toList();
          
          // Sort manually by timestamp
          activities.sort((a, b) {
            final aTime = a['timestamp'] as DateTime;
            final bTime = b['timestamp'] as DateTime;
            return bTime.compareTo(aTime); // descending
          });
          
          // Increase limit to show more activities
          final limitedActivities = activities.take(50).toList();
          
          setState(() {
            _activityItems = limitedActivities;
          });
        } catch (fallbackError) {
          print("Fallback error loading activity feed: $fallbackError");
        }
      }
    }
  }

  // Add a method to clear the activity feed
  Future<void> _clearActivityFeed() async {
    try {
      if (_trainer == null) return;
      
      setState(() {
        _isLoading = true;
      });
      
      // Show confirmation dialog
      final shouldClear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Activity Feed'),
          content: const Text('Are you sure you want to clear all activity feed entries? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear All'),
            ),
          ],
        ),
      ) ?? false;
      
      if (!shouldClear) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Get all activity feed entries for this trainer
      final snapshot = await FirebaseFirestore.instance
          .collection('activityFeed')
          .where('trainerId', isEqualTo: _trainer!.uid)
          .get();
      
      // Delete each document in a batch
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      // Clear the local list
      setState(() {
        _activityItems = [];
        _isLoading = false;
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity feed cleared successfully')),
        );
      }
    } catch (e) {
      print('Error clearing activity feed: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing activity feed: $e')),
        );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppStyles.surfaceCharcoal.withOpacity(0.9),
                    AppStyles.backgroundCharcoal.withOpacity(0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppStyles.primaryBlue.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppStyles.primaryBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppStyles.primaryBlue.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Welcome, ${_trainer!.displayName ?? 'Trainer'}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppStyles.textWhite,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppStyles.backgroundCharcoal.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppStyles.textGrey.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppStyles.softGold.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.format_quote,
                                  color: AppStyles.softGold,
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
                                    color: AppStyles.textWhite.withOpacity(0.9),
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w300,
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
            const SizedBox(height: 32),

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
                  title: 'Templates',
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
                Row(
                  children: [
                    TextButton(
                      onPressed: _clearActivityFeed,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Clear All'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _loadActivityFeed,
                      child: const Text('Refresh'),
                    ),
                  ],
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
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
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
      case 'session_cancelled':
        icon = Icons.cancel;
        iconColor = Colors.red;
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
    
    // Handle multiline messages (like cancellation with reason)
    final message = activity['message'] as String;
    final messageParts = message.split('\n');
    final primaryMessage = messageParts.first;
    final hasSecondaryMessage = messageParts.length > 1;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.2),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(primaryMessage),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasSecondaryMessage)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                messageParts.sublist(1).join('\n'),
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.red,
                ),
              ),
            ),
          Text(formattedDate),
        ],
      ),
      isThreeLine: hasSecondaryMessage,
      onTap: () => _handleActivityTap(activity),
    );
  }
  
  void _handleActivityTap(Map<String, dynamic> activity) {
    // Handle navigation based on activity type
    switch (activity['type']) {
      case 'session_scheduled':
      case 'session_cancelled':
        // Navigate to scheduling screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TrainerSchedulingScreen(),
          ),
        );
        break;
      case 'workout_completed':
        // Navigate to client details if clientId is available
        if (activity['clientId'] != null) {
          // Import client_details_screen.dart if not already imported
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => ClientDetailsScreen(
                clientId: activity['clientId'],
                clientName: activity['message'].toString().split(' completed')[0],
              ),
            ),
          );
        }
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
          width: (MediaQuery.of(context).size.width - 64) / 3, // Consistent width accounting for padding
          height: 100, // Fixed height for consistency
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
              ),
            ],
          ),
        ),
      ),
    );
  }
} 