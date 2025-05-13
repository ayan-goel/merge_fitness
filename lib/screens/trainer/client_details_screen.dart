import 'package:flutter/material.dart';
import '../../models/assigned_workout_model.dart';
import '../../models/nutrition_plan_model.dart';
import '../../services/workout_template_service.dart';
import '../../services/nutrition_service.dart';
import 'assign_workout_screen.dart';
import 'assign_nutrition_plan_screen.dart';
import 'client_info_screen.dart';
import 'client_meal_history_screen.dart';

class ClientDetailsScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  const ClientDetailsScreen({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final NutritionService _nutritionService = NutritionService();
  
  void _navigateToAssignWorkout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignWorkoutScreen(
          clientId: widget.clientId,
          clientName: widget.clientName,
        ),
      ),
    );
  }
  
  void _navigateToAssignNutritionPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignNutritionPlanScreen(
          clientId: widget.clientId,
          clientName: widget.clientName,
        ),
      ),
    ).then((result) {
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nutrition plan deleted successfully')),
        );
      } else if (result == 'created') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nutrition plan assigned successfully')),
        );
      }
    });
  }
  
  void _navigateToClientInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientInfoScreen(
          clientId: widget.clientId,
          clientName: widget.clientName,
        ),
      ),
    );
  }
  
  void _navigateToEditNutritionPlan(NutritionPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignNutritionPlanScreen(
          clientId: widget.clientId,
          clientName: widget.clientName,
          existingPlan: plan,
        ),
      ),
    ).then((result) {
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nutrition plan deleted successfully')),
        );
      } else if (result == 'updated') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nutrition plan updated successfully')),
        );
      }
    });
  }
  
  void _confirmDeleteNutritionPlan(NutritionPlan plan) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Nutrition Plan'),
          content: Text('Are you sure you want to delete "${plan.name}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _nutritionService.deleteNutritionPlan(plan.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nutrition plan deleted successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting nutrition plan: $e')),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
  
  void _navigateToClientMeals() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientMealHistoryScreen(
          clientId: widget.clientId,
          clientName: widget.clientName,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.clientName),
          actions: [
            IconButton(
              icon: const Icon(Icons.person),
              tooltip: 'View client information',
              onPressed: _navigateToClientInfo,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Workouts', icon: Icon(Icons.fitness_center)),
              Tab(text: 'Nutrition', icon: Icon(Icons.restaurant_menu)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // WORKOUTS TAB
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assigned workouts header with assign button
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _navigateToAssignWorkout,
                          icon: const Icon(Icons.fitness_center),
                          label: const Text('Assign Workout'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: StreamBuilder<List<AssignedWorkout>>(
                    stream: _workoutService.getClientWorkouts(widget.clientId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }
                      
                      final workouts = snapshot.data ?? [];
                      
                      if (workouts.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.fitness_center,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No workouts assigned yet',
                                  style: Theme.of(context).textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: 200,
                                  child: TextButton(
                                    onPressed: _navigateToAssignWorkout,
                                    style: TextButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text('Assign First Workout'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: workouts.length,
                        itemBuilder: (context, index) {
                          final workout = workouts[index];
                          return WorkoutCard(workout: workout);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            
            // NUTRITION TAB
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nutrition plans header with assign button
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamBuilder<List<NutritionPlan>>(
                        stream: _nutritionService.getClientNutritionPlans(widget.clientId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }

                          final plans = snapshot.data ?? [];
                          final hasActivePlan = plans.isNotEmpty;
                          final activePlan = hasActivePlan ? plans.first : null;
                          
                          // Show different actions based on whether there's an active plan
                          if (!hasActivePlan) {
                            return SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: _navigateToAssignNutritionPlan,
                                icon: const Icon(Icons.restaurant_menu),
                                label: const Text('Assign Nutrition Plan'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            );
                          } else {
                            // Show Edit and Delete buttons when a plan exists
                            return Row(
                              children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () => _navigateToEditNutritionPlan(activePlan!),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit Plan'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () => _confirmDeleteNutritionPlan(activePlan!),
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Delete Plan'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: StreamBuilder<List<NutritionPlan>>(
                    stream: _nutritionService.getClientNutritionPlans(widget.clientId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }
                      
                      final plans = snapshot.data ?? [];
                      
                      if (plans.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.restaurant_menu,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No nutrition plans assigned yet',
                                  style: Theme.of(context).textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: 200,
                                  child: TextButton(
                                    onPressed: _navigateToAssignNutritionPlan,
                                    style: TextButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text('Assign First Plan'),
                                  ),
                                ),
                                // View Meals button even if no plan
                                const SizedBox(height: 24),
                                OutlinedButton.icon(
                                  onPressed: () => _navigateToClientMeals(),
                                  icon: const Icon(Icons.restaurant),
                                  label: const Text('View Client\'s Meals'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      return Column(
                        children: [
                          // Add a button to view client's meals - MOVED UP
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _navigateToClientMeals(),
                                icon: const Icon(Icons.restaurant, size: 24),
                                label: const Text('View Client\'s Meals', style: TextStyle(fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: plans.length,
                              itemBuilder: (context, index) {
                                final plan = plans[index];
                                return NutritionPlanCard(plan: plan);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WorkoutCard extends StatelessWidget {
  final AssignedWorkout workout;
  
  const WorkoutCard({
    super.key,
    required this.workout,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workout.workoutName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4.0),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Scheduled: ${_formatDate(workout.scheduledDate)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            Row(
              children: [
                Icon(
                  _getStatusIcon(workout.status),
                  size: 16,
                  color: _getStatusColor(workout.status, context),
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Status: ${_formatStatus(workout.status)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _getStatusColor(workout.status, context),
                  ),
                ),
              ],
            ),
            if (workout.exercises.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              Text(
                '${workout.exercises.length} exercise${workout.exercises.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (workout.notes != null && workout.notes!.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              Text(
                'Notes: ${workout.notes}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
  
  String _formatStatus(WorkoutStatus status) {
    switch (status) {
      case WorkoutStatus.assigned:
        return 'Assigned';
      case WorkoutStatus.inProgress:
        return 'In Progress';
      case WorkoutStatus.completed:
        return 'Completed';
      case WorkoutStatus.skipped:
        return 'Skipped';
    }
  }
  
  IconData _getStatusIcon(WorkoutStatus status) {
    switch (status) {
      case WorkoutStatus.assigned:
        return Icons.assignment;
      case WorkoutStatus.inProgress:
        return Icons.play_circle_outline;
      case WorkoutStatus.completed:
        return Icons.check_circle_outline;
      case WorkoutStatus.skipped:
        return Icons.cancel_outlined;
    }
  }
  
  Color _getStatusColor(WorkoutStatus status, BuildContext context) {
    switch (status) {
      case WorkoutStatus.assigned:
        return Theme.of(context).colorScheme.primary;
      case WorkoutStatus.inProgress:
        return Colors.orange;
      case WorkoutStatus.completed:
        return Colors.green;
      case WorkoutStatus.skipped:
        return Colors.red;
    }
  }
}

class NutritionPlanCard extends StatelessWidget {
  final NutritionPlan plan;
  
  const NutritionPlanCard({
    super.key,
    required this.plan,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isActive = plan.startDate.isBefore(now) && 
                    (plan.endDate == null || plan.endDate!.isAfter(now));
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    plan.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4.0),
                Text(
                  _getDateRangeText(),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4.0),
                Text(
                  'Calories: ${plan.dailyCalories} kcal',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            
            // Macronutrients
            Text(
              'Macronutrients:',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4.0),
            Row(
              children: [
                _macronutrientChip('Protein', '${plan.macronutrients['protein']?.toInt() ?? 0}g', Colors.red.shade100),
                const SizedBox(width: 8),
                _macronutrientChip('Carbs', '${plan.macronutrients['carbs']?.toInt() ?? 0}g', Colors.green.shade100),
                const SizedBox(width: 8),
                _macronutrientChip('Fat', '${plan.macronutrients['fat']?.toInt() ?? 0}g', Colors.blue.shade100),
              ],
            ),
            
            // Micronutrients
            const SizedBox(height: 8.0),
            Text(
              'Micronutrients:',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4.0),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _macronutrientChip('Sodium', '${plan.micronutrients['sodium']?.toInt() ?? 0}mg', Colors.purple.shade100),
                _macronutrientChip('Cholesterol', '${plan.micronutrients['cholesterol']?.toInt() ?? 0}mg', Colors.purple.shade100),
                _macronutrientChip('Fiber', '${plan.micronutrients['fiber']?.toInt() ?? 0}g', Colors.purple.shade100),
                _macronutrientChip('Sugar', '${plan.micronutrients['sugar']?.toInt() ?? 0}g', Colors.purple.shade100),
              ],
            ),
            
            if (plan.description != null && plan.description!.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              Text(
                plan.description!,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _macronutrientChip(String label, String value, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label: $value'),
    );
  }
  
  String _getDateRangeText() {
    final dateFormat = '${plan.startDate.month}/${plan.startDate.day}/${plan.startDate.year}';
    
    if (plan.endDate == null) {
      return 'From $dateFormat';
    } else {
      final endDateFormat = '${plan.endDate!.month}/${plan.endDate!.day}/${plan.endDate!.year}';
      return '$dateFormat - $endDateFormat';
    }
  }
} 