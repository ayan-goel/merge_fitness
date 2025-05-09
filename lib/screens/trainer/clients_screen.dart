import 'package:flutter/material.dart';
import '../../services/workout_template_service.dart';
import '../../services/auth_service.dart';
import 'client_details_screen.dart';

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
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadClients();
  }
  
  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = await _authService.getUserModel();
      final clients = await _workoutService.getTrainerClients(user.uid);
      
      setState(() {
        _clients = clients;
        _filteredClients = clients;
        _isLoading = false;
      });
    } catch (e) {
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
                            ? const Text('No clients found')
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
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ClientDetailsScreen(
                                      clientId: client['id'],
                                      clientName: client['displayName'],
                                    ),
                                  ),
                                );
                              },
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
  
  const ClientListItem({
    super.key,
    required this.client,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          backgroundImage: client['photoUrl'] != null 
              ? NetworkImage(client['photoUrl']) 
              : null,
          child: client['photoUrl'] == null 
              ? Text((client['displayName'] ?? 'U').substring(0, 1)) 
              : null,
        ),
        title: Text(client['displayName'] ?? 'Unknown'),
        subtitle: Text(client['email'] ?? ''),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
} 