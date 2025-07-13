import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/family_model.dart';
import '../../models/user_model.dart';
import '../../services/family_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/profile_avatar.dart';
import '../../theme/app_styles.dart';
import '../../theme/app_widgets.dart';

class FamilyManagementScreen extends StatefulWidget {
  final String familyId;
  
  const FamilyManagementScreen({
    Key? key,
    required this.familyId,
  }) : super(key: key);

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  final FamilyService _familyService = FamilyService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  
  Family? _family;
  UserModel? _currentUser;
  List<UserModel> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = await _authService.getUserModel();
      final family = await _familyService.getFamily(widget.familyId);
      
      setState(() {
        _currentUser = user;
        _family = family;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading family data: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final results = await _familyService.searchClientsForInvitation(
        query: query,
        familyId: widget.familyId,
      );
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      _showErrorSnackBar('Error searching users: $e');
    }
  }

  Future<void> _inviteMember(String userId, String displayName, String email) async {
    try {
      await _familyService.inviteUserToFamily(
        familyId: widget.familyId,
        invitedUserId: userId,
        message: 'You have been invited to join our family!',
      );
      
      _showSuccessSnackBar('Invitation sent to $displayName');
      await _loadData(); // Refresh family data
      _searchController.clear();
      setState(() {
        _searchResults = [];
        _searchQuery = '';
      });
    } catch (e) {
      _showErrorSnackBar('Error sending invitation: $e');
    }
  }

  Future<void> _reinviteMember(FamilyMember member) async {
    try {
      await _familyService.inviteUserToFamily(
        familyId: widget.familyId,
        invitedUserId: member.userId,
        message: 'You have been re-invited to join our family!',
      );
      
      _showSuccessSnackBar('Re-invitation sent to ${member.displayName}');
      await _loadData();
    } catch (e) {
      _showErrorSnackBar('Error re-inviting member: $e');
    }
  }

  Future<void> _removeMember(FamilyMember member) async {
    final confirm = await _showConfirmDialog(
      'Remove Member',
      'Are you sure you want to remove ${member.displayName} from the family?',
    );
    
    if (confirm) {
      try {
        await _familyService.removeMemberFromFamily(member.userId);
        _showSuccessSnackBar('${member.displayName} removed from family');
        await _loadData();
      } catch (e) {
        _showErrorSnackBar('Error removing member: $e');
      }
    }
  }

  Future<void> _deleteFamily() async {
    final confirm = await _showConfirmDialog(
      'Delete Family',
      'Are you sure you want to delete this family? This action cannot be undone.',
    );
    
    if (confirm) {
      try {
        await _familyService.deleteFamily();
        _showSuccessSnackBar('Family deleted successfully');
        Navigator.of(context).pop();
      } catch (e) {
        _showErrorSnackBar('Error deleting family: $e');
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Family Management'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_family == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Family Management'),
        ),
        body: const Center(
          child: Text('Family not found'),
        ),
      );
    }

    final isOrganizer = _family!.organizerId == _currentUser?.uid;

    return Scaffold(
      backgroundColor: AppStyles.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _family!.name,
          style: TextStyle(
            color: AppStyles.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppStyles.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isOrganizer)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppStyles.textDark),
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteFamily();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: AppStyles.errorRed),
                      const SizedBox(width: 8),
                      Text('Delete Family', style: TextStyle(color: AppStyles.errorRed)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isOrganizer) ...[
            // Search section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_add,
                          color: AppStyles.primarySage,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Invite New Members',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppStyles.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name...',
                        hintStyle: TextStyle(color: AppStyles.slateGray),
                        prefixIcon: Icon(Icons.search, color: AppStyles.primarySage),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: AppStyles.slateGray),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchUsers('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppStyles.slateGray.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppStyles.primarySage, width: 2),
                        ),
                      ),
                      onChanged: _searchUsers,
                    ),
                    const SizedBox(height: 12),
                    if (_isSearching)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppStyles.primarySage),
                          ),
                        ),
                      )
                    else if (_searchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppStyles.slateGray.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade100,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            return Container(
                              margin: EdgeInsets.only(
                                left: 8,
                                right: 8,
                                top: index == 0 ? 2 : 3,
                                bottom: index == _searchResults.length - 1 ? 2 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    ProfileAvatar(
                                      name: user.displayName ?? '${user.firstName} ${user.lastName}',
                                      radius: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        user.displayName ?? '${user.firstName} ${user.lastName}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: AppStyles.textDark,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: () => _inviteMember(
                                        user.uid,
                                        user.displayName ?? '${user.firstName} ${user.lastName}',
                                        user.email,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppStyles.primarySage,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        minimumSize: const Size(60, 32),
                                      ),
                                      child: const Text(
                                        'Invite',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else if (_searchQuery.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(
                              color: AppStyles.slateGray,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // Family members section
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.family_restroom,
                        color: AppStyles.primarySage,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Family Members (${_family!.activeMemberCount})',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppStyles.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<UserModel>>(
                    future: _familyService.getFamilyMembers(_family!.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppStyles.primarySage),
                            ),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppStyles.errorRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Error loading members: ${snapshot.error}',
                            style: TextStyle(color: AppStyles.errorRed),
                          ),
                        );
                      }
                      
                      final members = snapshot.data ?? [];
                      
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: members.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final user = members[index];
                          final isCurrentUser = user.uid == _currentUser?.uid;
                          final isOrganizerUser = user.uid == _family!.organizerId;
                          final canRemove = isOrganizer && !isCurrentUser && !isOrganizerUser;
                          
                          // Find the corresponding family member for status info (if not organizer)
                          final familyMember = _family!.getMember(user.uid);
                          
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppStyles.slateGray.withOpacity(0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                ProfileAvatar(
                                  name: user.displayName ?? '${user.firstName} ${user.lastName}',
                                  radius: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              user.displayName ?? '${user.firstName} ${user.lastName}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: AppStyles.textDark,
                                              ),
                                            ),
                                          ),
 
                                          if (isCurrentUser && !isOrganizerUser)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppStyles.slateGray,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'YOU',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (isOrganizerUser) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Family Organizer',
                                          style: TextStyle(
                                            color: AppStyles.primarySage,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (familyMember != null && isOrganizer && (canRemove || familyMember.status == FamilyMemberStatus.pending))
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: AppStyles.slateGray),
                                    onSelected: (value) {
                                      if (value == 'remove' && canRemove) {
                                        _removeMember(familyMember);
                                      } else if (value == 'reinvite' && 
                                                 familyMember.status == FamilyMemberStatus.pending) {
                                        _reinviteMember(familyMember);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (familyMember.status == FamilyMemberStatus.pending)
                                        PopupMenuItem(
                                          value: 'reinvite',
                                          child: Row(
                                            children: [
                                              Icon(Icons.send, color: AppStyles.primarySage),
                                              const SizedBox(width: 8),
                                              Text('Re-invite'),
                                            ],
                                          ),
                                        ),
                                      if (canRemove)
                                        PopupMenuItem(
                                          value: 'remove',
                                          child: Row(
                                            children: [
                                              Icon(Icons.remove_circle, color: AppStyles.errorRed),
                                              const SizedBox(width: 8),
                                              Text('Remove', style: TextStyle(color: AppStyles.errorRed)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 