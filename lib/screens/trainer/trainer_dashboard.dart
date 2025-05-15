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
        backgroundColor: AppStyles.offWhite,
        elevation: 0,
        actions: [], // Empty actions to remove any existing buttons
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section - using flexible sizing instead of fixed height
            Container(
              // Remove fixed height to prevent overflow
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
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0), // Reduced padding from 28 to 20
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Use minimum required space
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
                            DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
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
                      'Welcome, ${_trainer!.displayName ?? 'Trainer'}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppStyles.primarySage.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppStyles.slateGray.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppStyles.taupeBrown.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.format_quote,
                              color: AppStyles.taupeBrown,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
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
            ),
            const SizedBox(height: 12), // Further reduced from 16

            // Quick actions - more compact row
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12), // Further reduced from 16

            // Activity feed - giving it a flexible weight of 1 to take remaining space
            Expanded(
              flex: 2, // Give it more weight
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            style: TextButton.styleFrom(foregroundColor: AppStyles.errorRed),
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
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _activityItems.isEmpty
                        ? const Center(
                            child: Text('No recent activities'),
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0), // Reduced vertical padding
                            itemCount: _activityItems.length,
                            separatorBuilder: (context, index) => const Divider(height: 8, thickness: 1),
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
        iconColor = AppStyles.successGreen;
        break;
      case 'session_cancelled':
        icon = Icons.cancel;
        iconColor = AppStyles.errorRed;
        break;
      case 'workout_assigned':
        icon = Icons.fitness_center;
        iconColor = AppStyles.mutedBlue;
        break;
      case 'workout_completed':
        icon = Icons.check_circle;
        iconColor = AppStyles.primarySage;
        break;
      default:
        icon = Icons.notifications;
        iconColor = AppStyles.slateGray;
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
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: iconColor.withOpacity(0.2),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        primaryMessage,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasSecondaryMessage)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, top: 4),
              child: Text(
                messageParts.sublist(1).join('\n'),
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppStyles.errorRed,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          SizedBox(height: hasSecondaryMessage ? 4 : 2),
          Text(
            formattedDate,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      isThreeLine: hasSecondaryMessage,
      dense: true, // Makes the tile more compact
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
          height: 85, // Reduced height
          padding: const EdgeInsets.all(12), // Reduced padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28, // Reduced icon size
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 6), // Reduced spacing
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 