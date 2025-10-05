import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/messaging_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_styles.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final MessagingService _messagingService = MessagingService();
  final AuthService _authService = AuthService();
  
  UserModel? _currentUser;
  List<UserModel> _availableUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getUserModel();
      setState(() {
        _currentUser = user;
      });
      await _loadAvailableUsers();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e')),
        );
      }
    }
  }

  Future<void> _loadAvailableUsers() async {
    if (_currentUser == null) return;

    try {
      List<UserModel> users = [];

      if (_currentUser!.isClient) {
        // Client can message their trainer and super trainers
        if (_currentUser!.trainerId != null) {
          final trainerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.trainerId)
              .get();
          if (trainerDoc.exists) {
            final data = trainerDoc.data() as Map<String, dynamic>;
            users.add(UserModel.fromMap(
              data,
              uid: trainerDoc.id,
              email: data['email'] ?? '',
            ));
          }
        }

        // Get super trainers
        final superTrainersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'superTrainer')
            .get();
        for (var doc in superTrainersSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final trainer = UserModel.fromMap(
            data,
            uid: doc.id,
            email: data['email'] ?? '',
          );
          if (trainer.uid != _currentUser!.trainerId) {
            users.add(trainer);
          }
        }
      } else if (_currentUser!.isTrainer || _currentUser!.isSuperTrainer) {
        // Trainer can message their clients
        Query query = FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'client');

        if (!_currentUser!.isSuperTrainer) {
          query = query.where('trainerId', isEqualTo: _currentUser!.uid);
        }

        final clientsSnapshot = await query.get();
        for (var doc in clientsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          users.add(UserModel.fromMap(
            data,
            uid: doc.id,
            email: data['email'] ?? '',
          ));
        }
      }

      if (mounted) {
        setState(() {
          _availableUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  Future<void> _showUserSelectionSheet() async {
    if (_currentUser == null) return;

    try {
      // Show bottom sheet with DraggableScrollableSheet
      final selectedUser = await showModalBottomSheet<UserModel>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUser!.isClient
                          ? 'Select a Trainer'
                          : 'Select a Client',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _availableUsers.length,
                        itemBuilder: (context, index) {
                          final user = _availableUsers[index];
                          final name = user.displayName ?? 
                              '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppStyles.primarySage.withOpacity(0.2),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: AppStyles.primarySage,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(name),
                            subtitle: Text(
                              user.isSuperTrainer
                                  ? 'Super Trainer'
                                  : user.isTrainer
                                      ? 'Trainer'
                                      : 'Client',
                            ),
                            onTap: () => Navigator.pop(context, user),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (selectedUser != null) {
        await _openChat(selectedUser);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _openChat(UserModel otherUser) async {
    if (_currentUser == null) return;

    try {
      final String clientId, clientName, trainerId, trainerName;

      if (_currentUser!.isClient) {
        clientId = _currentUser!.uid;
        clientName = _currentUser!.displayName ?? 
            '${_currentUser!.firstName ?? ''} ${_currentUser!.lastName ?? ''}'.trim();
        trainerId = otherUser.uid;
        trainerName = otherUser.displayName ?? 
            '${otherUser.firstName ?? ''} ${otherUser.lastName ?? ''}'.trim();
      } else {
        trainerId = _currentUser!.uid;
        trainerName = _currentUser!.displayName ?? 
            '${_currentUser!.firstName ?? ''} ${_currentUser!.lastName ?? ''}'.trim();
        clientId = otherUser.uid;
        clientName = otherUser.displayName ?? 
            '${otherUser.firstName ?? ''} ${otherUser.lastName ?? ''}'.trim();
      }

      final conversation = await _messagingService.getOrCreateConversation(
        clientId: clientId,
        clientName: clientName,
        trainerId: trainerId,
        trainerName: trainerName,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversation: conversation,
            currentUser: _currentUser!,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening chat: $e')),
        );
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(timestamp);
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppStyles.offWhite,
        appBar: AppBar(
          title: const Text('Messages'),
          backgroundColor: AppStyles.offWhite,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: AppStyles.offWhite,
        appBar: AppBar(
          title: const Text('Messages'),
          backgroundColor: AppStyles.offWhite,
          elevation: 0,
        ),
        body: const Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppStyles.offWhite,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(color: AppStyles.textDark),
        ),
        backgroundColor: AppStyles.offWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppStyles.textDark),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUserSelectionSheet,
        backgroundColor: AppStyles.primarySage,
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: _messagingService.getUserConversations(_currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to start a conversation',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final isClient = _currentUser!.isClient;
              final otherPersonName = isClient 
                  ? conversation.trainerName 
                  : conversation.clientName;
              final hasUnread = conversation.lastSenderId != _currentUser!.uid &&
                               conversation.unreadCount > 0;
              final name = otherPersonName;

              return Card(
                elevation: hasUnread ? 3 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: hasUnread
                      ? const BorderSide(color: AppStyles.primarySage, width: 1.5)
                      : BorderSide.none,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          conversation: conversation,
                          currentUser: _currentUser!,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppStyles.primarySage.withOpacity(0.2),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppStyles.primarySage,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Conversation info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: hasUnread 
                                            ? FontWeight.bold 
                                            : FontWeight.w600,
                                        color: AppStyles.textDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _formatTimestamp(conversation.lastMessageTime),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hasUnread 
                                          ? AppStyles.primarySage 
                                          : Colors.grey[600],
                                      fontWeight: hasUnread 
                                          ? FontWeight.w600 
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      conversation.lastMessage,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: hasUnread 
                                            ? AppStyles.textDark 
                                            : Colors.grey[600],
                                        fontWeight: hasUnread 
                                            ? FontWeight.w600 
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (hasUnread)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppStyles.primarySage,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${conversation.unreadCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
              );
                  },
                );
              },
            ),
    );
  }
}

class _UserSelectionSheet extends StatefulWidget {
  final List<UserModel> availableUsers;
  final bool isClient;

  const _UserSelectionSheet({
    required this.availableUsers,
    required this.isClient,
  });

  @override
  State<_UserSelectionSheet> createState() => _UserSelectionSheetState();
}

class _UserSelectionSheetState extends State<_UserSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _filteredUsers = widget.availableUsers;
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = widget.availableUsers;
      } else {
        _filteredUsers = widget.availableUsers.where((user) {
          final name = (user.displayName ?? 
              '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim()).toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isClient ? 'Select a Trainer' : 'Select a Client',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textDark,
                ),
              ),
              const SizedBox(height: 16),
              // Search field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search, color: AppStyles.primarySage),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // User list
              Expanded(
                child: _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No users found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final name = user.displayName ?? 
                              '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppStyles.primarySage.withOpacity(0.2),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: AppStyles.primarySage,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(name),
                            subtitle: Text(
                              user.isSuperTrainer
                                  ? 'Super Trainer'
                                  : user.isTrainer
                                      ? 'Trainer'
                                      : 'Client',
                            ),
                            onTap: () => Navigator.pop(context, user),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

