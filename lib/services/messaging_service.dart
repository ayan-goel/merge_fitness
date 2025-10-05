import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _conversationsCollection => _firestore.collection('conversations');
  CollectionReference get _messagesCollection => _firestore.collection('messages');

  /// Get all conversations for a user (client or trainer)
  Stream<List<Conversation>> getUserConversations(String userId) {
    return _conversationsCollection
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Conversation.fromFirestore(doc))
              .toList();
        });
  }

  /// Get total unread message count for a user
  Stream<int> getUnreadMessageCount(String userId) {
    return _conversationsCollection
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lastSenderId = data['lastSenderId'] ?? '';
            // Only count if the last message was NOT from this user
            if (lastSenderId != userId) {
              total += (data['unreadCount'] ?? 0) as int;
            }
          }
          return total;
        });
  }

  /// Get or create a conversation between client and trainer
  Future<Conversation> getOrCreateConversation({
    required String clientId,
    required String clientName,
    required String trainerId,
    required String trainerName,
  }) async {
    final conversationId = Conversation.generateId(clientId, trainerId);
    final doc = await _conversationsCollection.doc(conversationId).get();

    if (doc.exists) {
      return Conversation.fromFirestore(doc);
    }

    // Create new conversation
    final conversation = Conversation(
      id: conversationId,
      clientId: clientId,
      clientName: clientName,
      trainerId: trainerId,
      trainerName: trainerName,
      lastMessage: 'Start a conversation',
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      lastSenderId: '',
    );

    await _conversationsCollection.doc(conversationId).set({
      ...conversation.toMap(),
      'participants': [clientId, trainerId],
    });

    return conversation;
  }

  /// Get messages for a conversation
  Stream<List<Message>> getMessages(String conversationId) {
    return _messagesCollection
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: true)
        .limit(100) // Limit to last 100 messages
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Message.fromFirestore(doc))
              .toList();
        });
  }

  /// Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    final message = Message(
      id: '', // Will be set by Firestore
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      text: text.trim(),
      timestamp: DateTime.now(),
      isRead: false,
    );

    // Add message to messages collection
    await _messagesCollection.add(message.toMap());

    // Update conversation's last message and increment unread count
    final conversationRef = _conversationsCollection.doc(conversationId);
    final conversationDoc = await conversationRef.get();
    
    if (conversationDoc.exists) {
      final data = conversationDoc.data() as Map<String, dynamic>;
      final currentUnreadCount = data['unreadCount'] ?? 0;
      
      await conversationRef.update({
        'lastMessage': text.trim(),
        'lastMessageTime': Timestamp.fromDate(DateTime.now()),
        'lastSenderId': senderId,
        'unreadCount': currentUnreadCount + 1,
      });
    }
  }

  /// Mark messages as read in a conversation
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    // Get all unread messages where the user is NOT the sender
    final unreadMessages = await _messagesCollection
        .where('conversationId', isEqualTo: conversationId)
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: userId)
        .get();

    // Batch update to mark as read
    final batch = _firestore.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();

    // Reset unread count in conversation if this user was the last recipient
    final conversationRef = _conversationsCollection.doc(conversationId);
    final conversationDoc = await conversationRef.get();
    
    if (conversationDoc.exists) {
      final data = conversationDoc.data() as Map<String, dynamic>;
      final lastSenderId = data['lastSenderId'] ?? '';
      
      // Only reset if the last message was NOT from this user
      if (lastSenderId != userId) {
        await conversationRef.update({'unreadCount': 0});
      }
    }
  }

  /// Get a specific conversation
  Future<Conversation?> getConversation(String conversationId) async {
    final doc = await _conversationsCollection.doc(conversationId).get();
    if (!doc.exists) return null;
    return Conversation.fromFirestore(doc);
  }

  /// Delete a conversation (for testing/admin purposes)
  Future<void> deleteConversation(String conversationId) async {
    // Delete all messages in the conversation
    final messages = await _messagesCollection
        .where('conversationId', isEqualTo: conversationId)
        .get();
    
    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }
    
    // Delete the conversation
    batch.delete(_conversationsCollection.doc(conversationId));
    
    await batch.commit();
  }
}

