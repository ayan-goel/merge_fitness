import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/workout_service.dart';
import '../models/workout_model.dart';
import '../theme/app_styles.dart';
import '../widgets/merge_app_bar.dart';
import 'login_screen.dart';
import 'trainer/templates_screen.dart';
import 'trainer/clients_screen.dart';
import 'trainer/trainer_dashboard.dart';
import 'trainer/trainer_scheduling_screen.dart';
import 'trainer/trainer_profile_screen.dart';
import 'client/client_dashboard.dart';
import 'client/client_workouts_screen.dart';
import 'client/client_progress_screen.dart';
import 'client/client_profile_screen.dart';
import 'client/client_nutrition_screen.dart';
import 'client/workout_detail_screen.dart';
import '../models/assigned_workout_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
  
  // Public method to navigate to a specific tab from anywhere in the app
  static void navigateToTab(BuildContext context, int index) {
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
    if (homeState != null) {
      homeState.navigateToTab(index);
    }
  }
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<UserModel> _userFuture;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final WorkoutService _workoutService = WorkoutService();
  int _selectedIndex = 0;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUser();
    
    // Listen for workout notification responses
    _notificationService.workoutSelectedStream.listen(_handleWorkoutSelected);
  }
  
  Future<UserModel> _loadUser() async {
    final user = await _authService.getUserModel();
    _user = user;
    return user;
  }
  
  // Handle workout selected from notification
  void _handleWorkoutSelected(String workoutId) async {
    // Only proceed if we have a user and they're a client
    if (_user == null || _user!.role != UserRole.client) return;
    
    try {
      // First navigate to workouts tab
      navigateToTab(1); // Navigate to workouts tab
      
      // After navigation, use the static method to navigate to the workout
      // Allow some time for the tab change to complete
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        
        // Use the static method in ClientWorkoutsScreen to navigate to the workout
        ClientWorkoutsScreen.navigateToWorkoutById(context, workoutId);
      });
    } catch (e) {
      print('Error handling workout notification: $e');
    }
  }

  // Handle bottom nav bar taps
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Public method to navigate to a specific tab
  void navigateToTab(int index) {
    _onItemTapped(index);
  }

  // Method that can be called by external widgets to access navigation
  static _HomeScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<_HomeScreenState>();
  }

  // Handle sign out
  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error loading user data: ${snapshot.error}'),
            ),
          );
        }

        final user = snapshot.data!;
        
        // Screens based on user role
        final List<Widget> _screens = _getScreensForRole(user.role);
        
        // Bottom navigation items based on user role
        final List<BottomNavigationBarItem> _navItems = _getNavItemsForRole(user.role);

        return Scaffold(
          body: _screens[_selectedIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_navItems.length, (index) {
                    return _buildNavItem(index, _navItems[index]);
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Get screens based on user role
  List<Widget> _getScreensForRole(UserRole role) {
    switch (role) {
      case UserRole.trainer:
        return [
          const TrainerDashboard(),
          const ClientsScreen(),
          const TemplatesScreen(),
          const TrainerSchedulingScreen(),
          _buildProfileScreen(),
        ];
      case UserRole.admin:
        return [
          _buildAdminDashboard(),
          _buildUsersScreen(),
          _buildStatsScreen(),
          _buildProfileScreen(),
        ];
      case UserRole.client:
      default:
        return [
          const ClientDashboard(),
          const ClientWorkoutsScreen(),
          const ClientProgressScreen(),
          _buildFoodLogScreen(),
          _buildProfileScreen(),
        ];
    }
  }

  // Get nav items based on user role
  List<BottomNavigationBarItem> _getNavItemsForRole(UserRole role) {
    switch (role) {
      case UserRole.trainer:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Clients',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Templates',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Sessions',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ];
      case UserRole.admin:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ];
      case UserRole.client:
      default:
        return [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Progress',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Food',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ];
    }
  }

  // Placeholder screens for each section

  Widget _buildClientDashboard() {
    return const Center(
      child: Text('Client Dashboard - Coming Soon'),
    );
  }

  Widget _buildTrainerDashboard() {
    return const Center(
      child: Text('Trainer Dashboard - Coming Soon'),
    );
  }

  Widget _buildAdminDashboard() {
    return const Center(
      child: Text('Admin Dashboard - Coming Soon'),
    );
  }

  Widget _buildWorkoutsScreen() {
    return const Center(
      child: Text('Workouts - Coming Soon'),
    );
  }

  Widget _buildProgressScreen() {
    return const Center(
      child: Text('Progress Tracking - Coming Soon'),
    );
  }

  Widget _buildFoodLogScreen() {
    return const ClientNutritionScreen();
  }

  Widget _buildScheduleScreen() {
    return const Center(
      child: Text('Schedule - Coming Soon'),
    );
  }

  Widget _buildUsersScreen() {
    return const Center(
      child: Text('Users Management - Coming Soon'),
    );
  }

  Widget _buildStatsScreen() {
    return const Center(
      child: Text('Statistics - Coming Soon'),
    );
  }

  Widget _buildProfileScreen() {
    if (_user?.role == UserRole.trainer) {
      return const TrainerProfileScreen();
    } else {
      return const ClientProfileScreen();
    }
  }

  Widget _buildNavItem(int index, BottomNavigationBarItem item) {
    final IconData iconData = _getIconData(index);
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            color: _selectedIndex == index ? Theme.of(context).colorScheme.primary : Colors.grey,
            size: 24.0,
          ),
          const SizedBox(height: 4),
          Text(
            item.label ?? '',
            style: TextStyle(
              color: _selectedIndex == index ? Theme.of(context).colorScheme.primary : Colors.grey,
              fontSize: 10.0,
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getIconData(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard;
      case 1:
        return _user?.role == UserRole.trainer ? Icons.people : Icons.fitness_center;
      case 2:
        return _user?.role == UserRole.trainer ? Icons.fitness_center : Icons.insights;
      case 3:
        return _user?.role == UserRole.trainer ? Icons.calendar_month : Icons.restaurant_menu;
      case 4:
        return Icons.person;
      default:
        return Icons.error;
    }
  }
} 