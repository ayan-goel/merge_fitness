import 'package:cloud_firestore/cloud_firestore.dart';

class SessionPackage {
  final String id;
  final String clientId;
  final String trainerId;
  final double costPerTenSessions;
  final int sessionsRemaining;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SessionPackage({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.costPerTenSessions,
    required this.sessionsRemaining,
    required this.createdAt,
    this.updatedAt,
  });

  factory SessionPackage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return SessionPackage(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      trainerId: data['trainerId'] ?? '',
      costPerTenSessions: (data['costPerTenSessions'] ?? 0).toDouble(),
      sessionsRemaining: data['sessionsRemaining'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? 
        (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'trainerId': trainerId,
      'costPerTenSessions': costPerTenSessions,
      'sessionsRemaining': sessionsRemaining,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  SessionPackage copyWith({
    String? id,
    String? clientId,
    String? trainerId,
    double? costPerTenSessions,
    int? sessionsRemaining,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionPackage(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      trainerId: trainerId ?? this.trainerId,
      costPerTenSessions: costPerTenSessions ?? this.costPerTenSessions,
      sessionsRemaining: sessionsRemaining ?? this.sessionsRemaining,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 