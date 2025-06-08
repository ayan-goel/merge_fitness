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
      print("SelectTrainerScreen: Attempting to load trainers");
      final trainers = await _calendlyService.getAvailableTrainers();
      
      if (mounted) {
        setState(() {
          _trainers = trainers;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      print('SelectTrainerScreen: Error loading trainers: $e');
      if (mounted) {
        String errorMessage = 'Error loading trainers, please try again.';
        
        // Provide more specific error messages
        if (e.toString().contains('No trainer assigned')) {
          errorMessage = 'No trainer has been assigned to you yet. Please contact support.';
        } else if (e.toString().contains('not set up their scheduling calendar')) {
          errorMessage = 'Your trainer has not set up their scheduling calendar yet. Please contact them directly.';
        } else if (e.toString().contains('User data not found')) {
          errorMessage = 'Account setup incomplete. Please contact support.';
        }
        
        setState(() {
          _errorMessage = errorMessage;
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _errorMessage!.contains('No trainer assigned') 
                  ? Icons.person_off_outlined
                  : _errorMessage!.contains('scheduling calendar')
                      ? Icons.calendar_today_outlined
                      : Icons.error_outline,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!.contains('No trainer assigned')
                  ? 'No Trainer Assigned'
                  : _errorMessage!.contains('scheduling calendar')
                      ? 'Scheduling Unavailable'
                      : 'Connection Error',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (!_errorMessage!.contains('No trainer assigned') && 
                !_errorMessage!.contains('Account setup incomplete'))
              ElevatedButton(
                onPressed: _loadTrainers,
                child: const Text('Try Again'),
              ),
            if (_errorMessage!.contains('No trainer assigned') || 
                _errorMessage!.contains('Account setup incomplete'))
              ElevatedButton(
                onPressed: () {
                  // You could add a contact support action here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please contact support at bj@mergeintohealth.com'),
                      duration: Duration(seconds: 5),
                    ),
                  );
                },
                child: const Text('Contact Support'),
              ),
          ],
        ),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (trainer['email'] != null && trainer['email'].isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.email, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      trainer['email'],
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            if (trainer['phoneNumber'] != null && trainer['phoneNumber'].isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    trainer['phoneNumber'],
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                          ],
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