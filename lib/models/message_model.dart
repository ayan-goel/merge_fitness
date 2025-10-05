import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a single message in a conversation
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isRead = false,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Model representing a conversation between a client and trainer
class Conversation {
  final String id;
  final String clientId;
  final String clientName;
  final String trainerId;
  final String trainerName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount; // Unread count for the OTHER user
  final String lastSenderId;

  Conversation({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.trainerId,
    required this.trainerName,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    required this.lastSenderId,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      trainerId: data['trainerId'] ?? '',
      trainerName: data['trainerName'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
      unreadCount: data['unreadCount'] ?? 0,
      lastSenderId: data['lastSenderId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCount': unreadCount,
      'lastSenderId': lastSenderId,
    };
  }

  // Generate a consistent conversation ID from client and trainer IDs
  static String generateId(String clientId, String trainerId) {
    // Always put smaller ID first for consistency
    final ids = [clientId, trainerId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Conversation copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? trainerId,
    String? trainerName,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    String? lastSenderId,
  }) {
    return Conversation(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      trainerId: trainerId ?? this.trainerId,
      trainerName: trainerName ?? this.trainerName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      lastSenderId: lastSenderId ?? this.lastSenderId,
    );
  }
}

