import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../screens/home_screen.dart';
import 'create_template_screen.dart';

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({super.key});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  final AuthService _authService = AuthService();
  UserModel? _trainer;
  bool _isLoading = true;

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
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading trainer data: $e");
      setState(() {
        _isLoading = false;
      });
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
                icon: Icons.fitness_center,
                title: 'Templates',
                onTap: () {
                  // Navigate to Templates tab (index 2)
                  HomeScreen.navigateToTab(context, 2);
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.add_circle_outline,
                title: 'New Workout',
                onTap: () {
                  // Navigate to Create Template screen using MaterialPageRoute instead of named route
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

          // Recent activity placeholder
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView(
                padding: const EdgeInsets.all(8.0),
                children: [
                  const ListTile(
                    leading: Icon(Icons.history),
                    title: Text('No recent activities'),
                    subtitle: Text('Your recent activities will appear here'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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