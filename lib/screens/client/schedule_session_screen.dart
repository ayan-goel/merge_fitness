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
      // Use the scheduleSession method which handles Calendly API integration
      await _calendlyService.scheduleSession(
        trainerId: widget.trainerId, 
        clientId: widget.clientId,
        timeSlot: _selectedTimeSlot!,
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
        : const SizedBox.shrink(),
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected time info
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                const TextSpan(text: 'Selected time: '),
                TextSpan(
                  text: _getFormattedTimeSlot(_selectedTimeSlot!),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Location input
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location',
              border: OutlineInputBorder(),
              hintText: 'e.g., Gym, Park, Virtual',
            ),
          ),
          const SizedBox(height: 8),
          
          // Notes input
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
              hintText: 'Any special instructions or requests',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          
          // Schedule button
          ElevatedButton(
            onPressed: _isSubmitting ? null : _scheduleSession,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirm Booking'),
          ),
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
  
  String _getFormattedTimeSlot(Map<String, dynamic> slot) {
    final startTime = slot['start_time'] as DateTime;
    final endTime = slot['end_time'] as DateTime;
    
    final dateFormatter = DateFormat('E, MMM d');
    final timeFormatter = DateFormat('h:mm a');
    
    final date = dateFormatter.format(startTime);
    final start = timeFormatter.format(startTime);
    final end = timeFormatter.format(endTime);
    
    return '$date, $start - $end';
  }
} 