import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus {
  scheduled,
  confirmed,
  canceled,
  completed,
}

class TrainingSession {
  final String id;
  final String clientId;
  final String trainerId;
  final DateTime time;
  final SessionStatus status;
  final String? calendarUrl;
  final String? locationName;
  final double? locationLat;
  final double? locationLng;
  final String? notes;

  TrainingSession({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.time,
    required this.status,
    this.calendarUrl,
    this.locationName,
    this.locationLat,
    this.locationLng,
    this.notes,
  });

  factory TrainingSession.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return TrainingSession(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      trainerId: data['trainerId'] ?? '',
      time: (data['time'] as Timestamp).toDate(),
      status: _stringToSessionStatus(data['status'] ?? 'scheduled'),
      calendarUrl: data['calendarUrl'],
      locationName: data['locationName'],
      locationLat: data['locationLat']?.toDouble(),
      locationLng: data['locationLng']?.toDouble(),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'trainerId': trainerId,
      'time': Timestamp.fromDate(time),
      'status': _sessionStatusToString(status),
      'calendarUrl': calendarUrl,
      'locationName': locationName,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'notes': notes,
    };
  }

  // Helper to convert string to SessionStatus enum
  static SessionStatus _stringToSessionStatus(String statusStr) {
    switch (statusStr.toLowerCase()) {
      case 'confirmed':
        return SessionStatus.confirmed;
      case 'canceled':
        return SessionStatus.canceled;
      case 'completed':
        return SessionStatus.completed;
      case 'scheduled':
      default:
        return SessionStatus.scheduled;
    }
  }

  // Helper to convert SessionStatus enum to string
  static String _sessionStatusToString(SessionStatus status) {
    switch (status) {
      case SessionStatus.confirmed:
        return 'confirmed';
      case SessionStatus.canceled:
        return 'canceled';
      case SessionStatus.completed:
        return 'completed';
      case SessionStatus.scheduled:
        return 'scheduled';
    }
  }

  // Create a copy with updated values
  TrainingSession copyWith({
    String? id,
    String? clientId,
    String? trainerId,
    DateTime? time,
    SessionStatus? status,
    String? calendarUrl,
    String? locationName,
    double? locationLat,
    double? locationLng,
    String? notes,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      trainerId: trainerId ?? this.trainerId,
      time: time ?? this.time,
      status: status ?? this.status,
      calendarUrl: calendarUrl ?? this.calendarUrl,
      locationName: locationName ?? this.locationName,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      notes: notes ?? this.notes,
    );
  }

  // Change session status
  TrainingSession updateStatus(SessionStatus newStatus) {
    return copyWith(status: newStatus);
  }

  // Update location
  TrainingSession updateLocation({
    required String locationName,
    required double locationLat,
    required double locationLng,
  }) {
    return copyWith(
      locationName: locationName,
      locationLat: locationLat,
      locationLng: locationLng,
    );
  }
} 