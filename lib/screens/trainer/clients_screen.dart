import 'package:flutter/material.dart';
import '../../services/workout_template_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/profile_avatar.dart';
import 'client_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final WorkoutTemplateService _workoutService = WorkoutTemplateService();
  final AuthService _authService = AuthService();
  
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  bool _isLoading = true;
  bool _isSuperTrainer = false;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadClients();
  }
  
  Future<void> _loadClients() async {
    print('=== LOADING CLIENTS ===');
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = await _authService.getUserModel();
      final isSuperTrainer = user.isSuperTrainer;
      print('User is super trainer: $isSuperTrainer');
      
      final clients = await _workoutService.getTrainerClients(user.uid);
      print('Loaded ${clients.length} clients');
      
      for (int i = 0; i < clients.length; i++) {
        final client = clients[i];
        print('Client $i: ${client['displayName']} (ID: ${client['id']}) - trainerId: ${client['trainerId']}');
      }
      
      setState(() {
        _clients = clients;
        _filteredClients = clients;
        _isSuperTrainer = isSuperTrainer;
        _isLoading = false;
      });
      
      print('=== CLIENTS LOADED SUCCESSFULLY ===');
    } catch (e) {
      print('Error loading clients: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clients: $e')),
        );
      }
    }
  }
  
  void _filterClients(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredClients = _clients;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredClients = _clients.where((client) {
          final name = (client['displayName'] ?? '').toLowerCase();
          final email = (client['email'] ?? '').toLowerCase();
          return name.contains(lowerQuery) || email.contains(lowerQuery);
        }).toList();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSuperTrainer ? 'All Clients' : 'My Clients'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search clients',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _filterClients,
            ),
          ),
          
          // Clients list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredClients.isEmpty
                    ? Center(
                        child: _searchQuery.isEmpty
                            ? Text(_isSuperTrainer 
                                ? 'No clients in the system yet' 
                                : 'No clients assigned to you yet')
                            : Text('No clients matching "$_searchQuery"'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadClients,
                        child: ListView.builder(
                          itemCount: _filteredClients.length,
                          itemBuilder: (context, index) {
                            final client = _filteredClients[index];
                            return ClientListItem(
                              client: client,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ClientDetailsScreen(
                                      clientId: client['id'],
                                      clientName: client['displayName'],
                                    ),
                                  ),
                                );
                                // Refresh the clients list when returning from client details
                                print('Returned from client details, refreshing clients list...');
                                await _loadClients();
                              },
                              isSuperTrainer: _isSuperTrainer,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class ClientListItem extends StatelessWidget {
  final Map<String, dynamic> client;
  final VoidCallback onTap;
  final bool isSuperTrainer;
  
  const ClientListItem({
    super.key,
    required this.client,
    required this.onTap,
    required this.isSuperTrainer,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: ProfileAvatar(
          name: client['displayName'] ?? 'Unknown',
          radius: 20,
        ),
        title: Text(client['displayName'] ?? 'Unknown'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(client['email'] ?? ''),
            if (isSuperTrainer) ...[
              const SizedBox(height: 4),
              FutureBuilder<List<String>>(
                future: _getTrainerNames(client),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    final trainerNames = snapshot.data!;
                    return Text(
                      trainerNames.length == 1 
                          ? 'Assigned to: ${trainerNames.first}'
                          : 'Assigned to: ${trainerNames.join(', ')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  } else if (snapshot.hasData && snapshot.data!.isEmpty) {
                    return Text(
                      'No trainers assigned',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
  
  /// Get trainer IDs from client data
  List<String> _getTrainerIds(Map<String, dynamic> client) {
    // Check for new format first (trainerIds array)
    if (client['trainerIds'] is List) {
      return List<String>.from(client['trainerIds']);
    }
    
    // Fall back to legacy format (single trainerId)
    final trainerId = client['trainerId'];
    if (trainerId is String) {
      return [trainerId];
    }
    
    return [];
  }

  Future<List<String>> _getTrainerNames(Map<String, dynamic> client) async {
    final trainerIds = _getTrainerIds(client);
    final List<String> trainerNames = [];
    
    for (final trainerId in trainerIds) {
      final trainerName = await _getTrainerName(trainerId);
      trainerNames.add(trainerName);
    }
    
    return trainerNames;
  }

  Future<String> _getTrainerName(String trainerId) async {
    try {
      print('ClientListItem: _getTrainerName called with trainerId: $trainerId');
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(trainerId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('ClientListItem: Trainer document found. Data keys: ${data.keys.toList()}');
        print('ClientListItem: Trainer displayName: ${data['displayName']}');
        print('ClientListItem: Trainer firstName: ${data['firstName']}');
        print('ClientListItem: Trainer lastName: ${data['lastName']}');
        print('ClientListItem: Trainer email: ${data['email']}');
        
        final displayName = data['displayName'] ?? 
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final result = displayName.isNotEmpty ? displayName : data['email'] ?? 'Unknown Trainer';
        print('ClientListItem: _getTrainerName returning: $result');
        return result;
      }
      print('ClientListItem: Trainer document not found for ID: $trainerId');
      return 'Unknown Trainer';
    } catch (e) {
      print('ClientListItem: Error in _getTrainerName: $e');
      return 'Unknown Trainer';
    }
  }
} 