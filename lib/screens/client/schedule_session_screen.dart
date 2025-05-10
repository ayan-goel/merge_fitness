import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/calendly_service.dart';
import '../../models/session_model.dart';
import '../../widgets/session_time_slot.dart';

class ScheduleSessionScreen extends StatefulWidget {
  final String clientId;
  final String trainerId;
  final String trainerName;
  
  const ScheduleSessionScreen({
    super.key,
    required this.clientId,
    required this.trainerId,
    required this.trainerName,
  });

  @override
  State<ScheduleSessionScreen> createState() => _ScheduleSessionScreenState();
}

class _ScheduleSessionScreenState extends State<ScheduleSessionScreen> {
  final CalendlyService _calendlyService = CalendlyService();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableTimeSlots = [];
  Map<String, dynamic>? _selectedTimeSlot;
  bool _isSubmitting = false;
  
  // Group time slots by date
  Map<DateTime, List<Map<String, dynamic>>> _timeSlotsByDate = {};
  
  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }
  
  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _loadAvailability() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get next 7 days of availability
      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(days: 7));
      
      final slots = await _calendlyService.getTrainerAvailability(
        widget.trainerId,
        startDate: startDate,
        endDate: endDate,
      );
      
      // Group time slots by date
      final Map<DateTime, List<Map<String, dynamic>>> slotsByDate = {};
      
      for (final slot in slots) {
        final startTime = slot['start_time'] as DateTime;
        final normalizedDate = DateTime(startTime.year, startTime.month, startTime.day);
        
        if (!slotsByDate.containsKey(normalizedDate)) {
          slotsByDate[normalizedDate] = [];
        }
        
        slotsByDate[normalizedDate]!.add(slot);
      }
      
      setState(() {
        _availableTimeSlots = slots;
        _timeSlotsByDate = slotsByDate;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading availability: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading trainer availability: $e')),
      );
    }
  }
  
  Future<void> _scheduleSession() async {
    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }
    
    if (_locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location')),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Create a session in our database
      final startTime = _selectedTimeSlot!['start_time'] as DateTime;
      final endTime = _selectedTimeSlot!['end_time'] as DateTime;
      
      await _calendlyService.createSession(
        trainerId: widget.trainerId,
        clientId: widget.clientId,
        startTime: startTime,
        endTime: endTime,
        location: _locationController.text,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      
      // Show success message and pop back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session scheduled successfully!')),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('Error scheduling session: $e');
      setState(() {
        _isSubmitting = false;
      });
      
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scheduling session: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule with ${widget.trainerName}'),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildContent(),
      bottomNavigationBar: _selectedTimeSlot != null
        ? _buildBottomBar()
        : null,
    );
  }
  
  Widget _buildContent() {
    if (_availableTimeSlots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No available time slots',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again later',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    // Sort dates chronologically
    final sortedDates = _timeSlotsByDate.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    
    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final slots = _timeSlotsByDate[date]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                _formatDate(date),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.map((slot) {
                  final startTime = slot['start_time'] as DateTime;
                  final endTime = slot['end_time'] as DateTime;
                  final isSelected = _selectedTimeSlot == slot;
                  
                  return SessionTimeSlot(
                    startTime: startTime,
                    endTime: endTime,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedTimeSlot = slot;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildBottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If a time slot is selected, show the session details form
          if (_selectedTimeSlot != null) ...[
            // Show selected time
            Text(
              'Selected Time:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatTimeSlot(_selectedTimeSlot!),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            
            // Location input
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location*',
                hintText: 'e.g., Central Park, Zoom call, etc.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            
            // Notes input
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Any special instructions or requests',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            // Schedule button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _scheduleSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Schedule Session'),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Today, ${DateFormat('MMMM d').format(date)}';
    } else if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      return 'Tomorrow, ${DateFormat('MMMM d').format(date)}';
    } else {
      return DateFormat('EEEE, MMMM d').format(date);
    }
  }
  
  String _formatTimeSlot(Map<String, dynamic> slot) {
    final startTime = slot['start_time'] as DateTime;
    final endTime = slot['end_time'] as DateTime;
    
    final date = DateFormat('EEEE, MMMM d').format(startTime);
    final start = DateFormat('h:mm a').format(startTime);
    final end = DateFormat('h:mm a').format(endTime);
    
    return '$date from $start to $end';
  }
} 