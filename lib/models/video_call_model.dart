import 'package:cloud_firestore/cloud_firestore.dart';

enum VideoCallStatus {
  waiting,
  active,
  ended,
  failed
}

class VideoCall {
  final String id;
  final String sessionId;
  final String trainerId;
  final String clientId;
  final String channelName;
  final VideoCallStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool trainerJoined;
  final bool clientJoined;
  final DateTime createdAt;
  final String? agoraToken;
  final int? agoraUid;

  VideoCall({
    required this.id,
    required this.sessionId,
    required this.trainerId,
    required this.clientId,
    required this.channelName,
    required this.status,
    this.startedAt,
    this.endedAt,
    required this.trainerJoined,
    required this.clientJoined,
    required this.createdAt,
    this.agoraToken,
    this.agoraUid,
  });

  factory VideoCall.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return VideoCall(
      id: doc.id,
      sessionId: data['sessionId'] ?? '',
      trainerId: data['trainerId'] ?? '',
      clientId: data['clientId'] ?? '',
      channelName: data['channelName'] ?? '',
      status: _parseStatus(data['status']),
      startedAt: data['startedAt'] != null 
          ? (data['startedAt'] as Timestamp).toDate() 
          : null,
      endedAt: data['endedAt'] != null 
          ? (data['endedAt'] as Timestamp).toDate() 
          : null,
      trainerJoined: data['trainerJoined'] ?? false,
      clientJoined: data['clientJoined'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      agoraToken: data['agoraToken'],
      agoraUid: data['agoraUid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'trainerId': trainerId,
      'clientId': clientId,
      'channelName': channelName,
      'status': status.name,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'trainerJoined': trainerJoined,
      'clientJoined': clientJoined,
      'createdAt': Timestamp.fromDate(createdAt),
      'agoraToken': agoraToken,
      'agoraUid': agoraUid,
    };
  }

  static VideoCallStatus _parseStatus(String? status) {
    switch (status) {
      case 'waiting':
        return VideoCallStatus.waiting;
      case 'active':
        return VideoCallStatus.active;
      case 'ended':
        return VideoCallStatus.ended;
      case 'failed':
        return VideoCallStatus.failed;
      default:
        return VideoCallStatus.waiting;
    }
  }

  VideoCall copyWith({
    String? id,
    String? sessionId,
    String? trainerId,
    String? clientId,
    String? channelName,
    VideoCallStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    bool? trainerJoined,
    bool? clientJoined,
    DateTime? createdAt,
    String? agoraToken,
    int? agoraUid,
  }) {
    return VideoCall(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      trainerId: trainerId ?? this.trainerId,
      clientId: clientId ?? this.clientId,
      channelName: channelName ?? this.channelName,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      trainerJoined: trainerJoined ?? this.trainerJoined,
      clientJoined: clientJoined ?? this.clientJoined,
      createdAt: createdAt ?? this.createdAt,
      agoraToken: agoraToken ?? this.agoraToken,
      agoraUid: agoraUid ?? this.agoraUid,
    );
  }

  bool get isActive => status == VideoCallStatus.active;
  bool get isWaiting => status == VideoCallStatus.waiting;
  bool get isEnded => status == VideoCallStatus.ended;
  bool get hasFailed => status == VideoCallStatus.failed;
} 