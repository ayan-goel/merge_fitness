import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingSession {
  final String id;
  final String trainerId;
  final String clientId;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String status; // scheduled, completed, cancelled
  final String? notes;
  final DateTime createdAt;
  final String? calendlyEventUri;
  
  TrainingSession({
    required this.id,
    required this.trainerId,
    required this.clientId,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.status,
    this.notes,
    required this.createdAt,
    this.calendlyEventUri,
  });
  
  factory TrainingSession.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return TrainingSession(
      id: doc.id,
      trainerId: data['trainerId'] ?? '',
      clientId: data['clientId'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      location: data['location'] ?? '',
      status: data['status'] ?? 'scheduled',
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      calendlyEventUri: data['calendlyEventUri'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'trainerId': trainerId,
      'clientId': clientId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'location': location,
      'status': status,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'calendlyEventUri': calendlyEventUri,
    };
  }
  
  // Get duration in minutes
  int get durationMinutes {
    return endTime.difference(startTime).inMinutes;
  }
  
  // Format time range for display (e.g., "9:00 AM - 10:00 AM")
  String get formattedTimeRange {
    final startFormat = _formatTime(startTime);
    final endFormat = _formatTime(endTime);
    return '$startFormat - $endFormat';
  }
  
  // Format date for display (e.g., "Monday, May 9")
  String get formattedDate {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 
                    'August', 'September', 'October', 'November', 'December'];
    
    final dayName = days[startTime.weekday - 1];
    final monthName = months[startTime.month - 1];
    
    return '$dayName, $monthName ${startTime.day}';
  }
  
  // Format time (e.g., "9:00 AM")
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    
    return '$hour:$minute $period';
  }
} 