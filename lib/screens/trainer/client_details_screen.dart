import 'package:flutter/material.dart';
import '../../models/assigned_workout_model.dart';
import '../../services/workout_template_service.dart';
import 'assign_workout_screen.dart';

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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clientName),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Assign new workout',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssignWorkoutScreen(
                    clientId: widget.clientId,
                    clientName: widget.clientName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assigned workouts
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Assigned Workouts',
              style: Theme.of(context).textTheme.titleLarge,
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
                  return const Center(
                    child: Text('No workouts assigned yet'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AssignWorkoutScreen(
                clientId: widget.clientId,
                clientName: widget.clientName,
              ),
            ),
          );
        },
        child: const Icon(Icons.fitness_center),
        tooltip: 'Assign Workout',
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