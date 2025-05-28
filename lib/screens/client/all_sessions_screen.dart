import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/session_model.dart';
import '../../services/calendly_service.dart';
import '../../theme/app_styles.dart';

class AllSessionsScreen extends StatefulWidget {
  final List<TrainingSession> sessions;
  final String clientId;
  final VoidCallback onSessionCancelled;

  const AllSessionsScreen({
    super.key,
    required this.sessions,
    required this.clientId,
    required this.onSessionCancelled,
  });

  @override
  State<AllSessionsScreen> createState() => _AllSessionsScreenState();
}

class _AllSessionsScreenState extends State<AllSessionsScreen> {
  final CalendlyService _calendlyService = CalendlyService();
  List<TrainingSession> _sessions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sessions = List.from(widget.sessions);
  }

  // Format a date header
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final sessionDate = DateTime(date.year, date.month, date.day);
    
    if (sessionDate == today) {
      return 'Today, ${DateFormat('MMMM d').format(date)}';
    } else if (sessionDate == tomorrow) {
      return 'Tomorrow, ${DateFormat('MMMM d').format(date)}';
    } else {
      return DateFormat('EEEE, MMMM d').format(date);
    }
  }

  // Show cancel confirmation dialog
  Future<void> _showCancelSessionDialog(TrainingSession session) async {
    final TextEditingController reasonController = TextEditingController();
    
    // Calculate if session is within 24 hours
    final now = DateTime.now();
    final timeDifference = session.startTime.difference(now);
    final isWithin24Hours = timeDifference.inHours < 24;
    
    try {
      bool? result = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.6),
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 12,
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 400,
                maxHeight: 650, // Add max height constraint
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppStyles.errorRed.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppStyles.errorRed.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cancel_outlined,
                            color: AppStyles.errorRed,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Cancel Training Session',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppStyles.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  // Content - Make scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        // Session details card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppStyles.offWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppStyles.slateGray.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.event,
                                    size: 18,
                                    color: AppStyles.primarySage,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    session.formattedDate,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppStyles.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: AppStyles.primarySage,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    session.formattedTimeRange,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppStyles.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: AppStyles.primarySage,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      session.location,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppStyles.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Refund policy information
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isWithin24Hours 
                                ? AppStyles.errorRed.withOpacity(0.1)
                                : AppStyles.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isWithin24Hours 
                                  ? AppStyles.errorRed.withOpacity(0.3)
                                  : AppStyles.successGreen.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isWithin24Hours ? Icons.warning_amber : Icons.check_circle,
                                    color: isWithin24Hours ? AppStyles.errorRed : AppStyles.successGreen,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Refund Policy',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isWithin24Hours ? AppStyles.errorRed : AppStyles.successGreen,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isWithin24Hours
                                    ? 'This session is within 24 hours. Your session will NOT be refunded unless you have discussed with your trainer beforehand with a valid reason. If you have, your trainer will manually restore your session.'
                                    : 'This session is more than 24 hours away. Your session will be automatically refunded to your account.',
                                style: TextStyle(
                                  color: isWithin24Hours ? AppStyles.errorRed : AppStyles.successGreen,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Reason field
                        const Text(
                          'Reason for cancellation (optional):',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppStyles.textDark,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: reasonController,
                          decoration: AppStyles.inputDecoration(
                            labelText: '',
                            hintText: 'Enter your reason here...',
                          ),
                          style: const TextStyle(color: AppStyles.textDark),
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                        ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Actions
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: AppStyles.slateGray.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Keep Session',
                              style: TextStyle(
                                color: AppStyles.textDark,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppStyles.errorRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Cancel Session',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
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
        },
      );
      
      if (result == true) {
        try {
          setState(() {
            _isLoading = true;
          });
          
          final reason = reasonController.text;
          
          await _calendlyService.cancelSession(
            session.id,
            cancellationReason: reason.isEmpty ? null : reason,
          );
          
          // Refresh original sessions list through callback
          widget.onSessionCancelled();
          
          // Remove the cancelled session from the local list
          setState(() {
            _sessions.removeWhere((s) => s.id == session.id);
            _isLoading = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session cancelled successfully')),
            );
          }
        } catch (e) {
          print('Error cancelling session: $e');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error cancelling session: $e')),
            );
          }
          setState(() {
            _isLoading = false;
          });
        }
      }
    } finally {
      // Ensure controller is always disposed, even if the dialog is dismissed
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Training Sessions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSessionsList(),
    );
  }

  Widget _buildSessionsList() {
    if (_sessions.isEmpty) {
      return const Center(
        child: Text('No upcoming training sessions'),
      );
    }

    // Group sessions by date
    final Map<String, List<TrainingSession>> sessionsByDate = {};
    
    for (final session in _sessions) {
      final dateKey = '${session.startTime.year}-${session.startTime.month.toString().padLeft(2, '0')}-${session.startTime.day.toString().padLeft(2, '0')}';
      if (!sessionsByDate.containsKey(dateKey)) {
        sessionsByDate[dateKey] = [];
      }
      sessionsByDate[dateKey]!.add(session);
    }
    
    // Sort date keys
    final sortedDates = sessionsByDate.keys.toList()..sort();
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, dateIndex) {
        final dateKey = sortedDates[dateIndex];
        final sessions = sessionsByDate[dateKey]!;
        final firstSession = sessions.first;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            if (dateIndex > 0) const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                _formatDateHeader(firstSession.startTime),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Sessions for this date
            ...sessions.map((session) => _buildSessionCard(session)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildSessionCard(TrainingSession session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppStyles.primarySage.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.event,
                    color: AppStyles.primarySage,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.formattedTimeRange,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.location,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (session.canBeCancelled)
                  TextButton.icon(
                    onPressed: () => _showCancelSessionDialog(session),
                    icon: const Icon(Icons.cancel, color: AppStyles.errorRed, size: 16),
                    label: const Text('Cancel', style: TextStyle(color: AppStyles.errorRed)),
                  ),
              ],
            ),
            
            if (session.notes != null && session.notes!.isNotEmpty) ...[
              const Divider(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 16, color: AppStyles.slateGray),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.notes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppStyles.slateGray,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
} 