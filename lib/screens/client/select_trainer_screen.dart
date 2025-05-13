import 'package:flutter/material.dart';
import '../../services/calendly_service.dart';
import '../../widgets/profile_avatar.dart';
import 'schedule_session_screen.dart';

class SelectTrainerScreen extends StatefulWidget {
  final String clientId;
  
  const SelectTrainerScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<SelectTrainerScreen> createState() => _SelectTrainerScreenState();
}

class _SelectTrainerScreenState extends State<SelectTrainerScreen> {
  final CalendlyService _calendlyService = CalendlyService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _trainers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTrainers();
  }

  Future<void> _loadTrainers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final trainers = await _calendlyService.getAvailableTrainers();
      
      if (mounted) {
        setState(() {
          _trainers = trainers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading trainers: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading trainers: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _selectTrainer(Map<String, dynamic> trainer) {
    // Navigate to scheduling screen with selected trainer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleSessionScreen(
          clientId: widget.clientId,
          trainerId: trainer['id'],
          trainerName: trainer['displayName'],
        ),
      ),
    ).then((_) {
      // Optionally refresh the list when coming back
      _loadTrainers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Trainer'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _trainers.isEmpty
                  ? _buildEmptyView()
                  : _buildTrainerList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Trainers',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Please make sure trainers have been registered in the system with Calendly URLs set up.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadTrainers,
            child: const Text('Try Again'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No Trainers Available',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'There are no trainers available for scheduling at this time.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadTrainers,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _trainers.length,
      itemBuilder: (context, index) {
        final trainer = _trainers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: InkWell(
            onTap: () => _selectTrainer(trainer),
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ProfileAvatar(
                    name: trainer['displayName'] ?? 'Trainer',
                    radius: 32,
                    fontSize: 18,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trainer['displayName'],
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trainer['specialty'] ?? 'General Fitness',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => _selectTrainer(trainer),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text('Schedule Session'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
} 