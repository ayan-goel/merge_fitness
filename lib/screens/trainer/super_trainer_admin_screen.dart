import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_styles.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/payment_service.dart';
import '../../models/user_model.dart';
import 'trainer_schedule_view_screen.dart';
import 'financial_analytics_screen.dart';

class SuperTrainerAdminScreen extends StatefulWidget {
  const SuperTrainerAdminScreen({super.key});

  @override
  State<SuperTrainerAdminScreen> createState() => _SuperTrainerAdminScreenState();
}

class _SuperTrainerAdminScreenState extends State<SuperTrainerAdminScreen> {
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  UserModel? _user;
  List<Map<String, dynamic>> _pendingClients = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getUserModel();
      setState(() {
        _user = user;
      });
      await _loadPendingClients();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPendingClients() async {
    try {
      print("Loading pending clients...");
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('accountStatus', isEqualTo: 'pending')
          .where('role', isEqualTo: 'client')
          .orderBy('createdAt', descending: true)
          .get();

      print("Found ${snapshot.docs.length} pending clients");
      
      final clients = snapshot.docs.map((doc) {
        final data = doc.data();
        print("Client data: ${data.keys.toList()}"); // Log available fields
        
        // Safely construct display name
        String displayName = data['displayName'] as String? ?? '';
        if (displayName.isEmpty) {
          final firstName = data['firstName'] as String? ?? '';
          final lastName = data['lastName'] as String? ?? '';
          if (firstName.isNotEmpty && lastName.isNotEmpty) {
            displayName = '$firstName $lastName';
          } else if (firstName.isNotEmpty) {
            displayName = firstName;
          } else if (lastName.isNotEmpty) {
            displayName = lastName;
          } else {
            displayName = data['email'] as String? ?? 'Unknown';
          }
        }
        
        return {
          'id': doc.id,
          'displayName': displayName,
          'email': data['email'] ?? '',
          'createdAt': data['createdAt'],
          'onboardingData': data['onboardingData'] ?? {},
        };
      }).toList();

      print("Processed ${clients.length} clients");
      setState(() {
        _pendingClients = clients;
      });
    } catch (e) {
      print("Error loading pending clients: $e");
      // If there's an index error, try without orderBy
      if (e.toString().contains('index')) {
        print("Trying without orderBy due to index error...");
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('accountStatus', isEqualTo: 'pending')
              .where('role', isEqualTo: 'client')
              .get();

          print("Found ${snapshot.docs.length} pending clients (without orderBy)");
          
          final clients = snapshot.docs.map((doc) {
            final data = doc.data();
            
            // Safely construct display name
            String displayName = data['displayName'] as String? ?? '';
            if (displayName.isEmpty) {
              final firstName = data['firstName'] as String? ?? '';
              final lastName = data['lastName'] as String? ?? '';
              if (firstName.isNotEmpty && lastName.isNotEmpty) {
                displayName = '$firstName $lastName';
              } else if (firstName.isNotEmpty) {
                displayName = firstName;
              } else if (lastName.isNotEmpty) {
                displayName = lastName;
              } else {
                displayName = data['email'] as String? ?? 'Unknown';
              }
            }
            
            return {
              'id': doc.id,
              'displayName': displayName,
              'email': data['email'] ?? '',
              'createdAt': data['createdAt'],
              'onboardingData': data['onboardingData'] ?? {},
            };
          }).toList();

          setState(() {
            _pendingClients = clients;
          });
        } catch (e2) {
          print("Error loading pending clients (fallback): $e2");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppStyles.primarySage.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppStyles.primarySage.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: AppStyles.primarySage,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Super Trainer Admin',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppStyles.textDark,
                              ),
                            ),
                            Text(
                              'Welcome, ${_user?.displayName ?? 'Super Trainer'}',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppStyles.slateGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You have access to all trainer features plus additional administrative capabilities.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppStyles.slateGray,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // New Client Approvals Section
            _buildNewClientApprovalsCard(),
            
            const SizedBox(height: 16),
            
            // View Trainer Schedule Section
            _buildTrainerScheduleCard(),
            
            const SizedBox(height: 16),
            
            // Financial Analytics Section
            _buildFinancialAnalyticsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewClientApprovalsCard() {
    return GestureDetector(
      onTap: () => _navigateToAllPendingClients(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppStyles.primarySage.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppStyles.primarySage.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person_add,
                    color: AppStyles.primarySage,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            Text(
                        'New Client Approvals',
              style: TextStyle(
                          fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppStyles.textDark,
              ),
            ),
                      Text(
                        '${_pendingClients.length} clients pending approval',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppStyles.slateGray,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_pendingClients.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppStyles.warningAmber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_pendingClients.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            if (_pendingClients.isNotEmpty) ...[
            const SizedBox(height: 16),
              ...(_pendingClients.take(3).map((client) => _buildClientPreview(client))),
              
              if (_pendingClients.length > 3) ...[
                const SizedBox(height: 12),
                Text(
                  'Tap to view all ${_pendingClients.length} pending clients',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.primarySage,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'No clients pending approval',
                style: TextStyle(
                  fontSize: 14,
                  color: AppStyles.slateGray,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientPreview(Map<String, dynamic> client) {
    final displayName = client['displayName'] ?? client['email'] ?? 'Unknown Client';
    final firstLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppStyles.offWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppStyles.primarySage.withOpacity(0.1)),
      ),
      child: Row(
              children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppStyles.primarySage.withOpacity(0.2),
            child: Text(
              firstLetter,
              style: TextStyle(
                color: AppStyles.primarySage,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
                ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  client['email'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.slateGray,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: AppStyles.slateGray,
          ),
        ],
      ),
    );
  }

  void _navigateToAllPendingClients() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PendingClientsScreen(pendingClients: _pendingClients),
      ),
    ).then((_) => _loadPendingClients()); // Refresh when returning
  }

  Widget _buildTrainerScheduleCard() {
    return GestureDetector(
      onTap: () => _navigateToTrainerSchedule(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppStyles.primarySage.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppStyles.primarySage.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: AppStyles.primarySage,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            Text(
                        'View Trainer Schedule',
              style: TextStyle(
                          fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppStyles.textDark,
              ),
                      ),
                      Text(
                        'View and manage trainer sessions',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppStyles.slateGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppStyles.slateGray,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Select a trainer to view their schedule and completed sessions',
              style: TextStyle(
                fontSize: 14,
                color: AppStyles.slateGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTrainerSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrainerScheduleViewScreen(),
      ),
    );
  }

  Widget _buildFinancialAnalyticsCard() {
    return GestureDetector(
      onTap: () => _navigateToFinancialAnalytics(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppStyles.primarySage.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppStyles.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.analytics,
                    color: AppStyles.successGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View Financial Analytics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.textDark,
                        ),
                      ),
                      Text(
                        'Track trainer earnings and revenue',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppStyles.slateGray,
                  ),
                ),
              ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppStyles.slateGray,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'View detailed financial reports, trainer earnings, and revenue analytics',
              style: TextStyle(
                fontSize: 14,
                color: AppStyles.slateGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToFinancialAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FinancialAnalyticsScreen(),
      ),
    );
  }
}

class PendingClientsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> pendingClients;

  const PendingClientsScreen({super.key, required this.pendingClients});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Client Approvals'),
      ),
      body: pendingClients.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppStyles.successGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No clients pending approval',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All client accounts have been reviewed',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppStyles.slateGray,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pendingClients.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final client = pendingClients[index];
                return _buildClientCard(context, client);
              },
            ),
    );
  }

  Widget _buildClientCard(BuildContext context, Map<String, dynamic> client) {
    final displayName = client['displayName'] ?? client['email'] ?? 'Unknown Client';
    final firstLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    
    return GestureDetector(
      onTap: () => _navigateToClientReview(context, client),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppStyles.primarySage.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppStyles.primarySage.withOpacity(0.2),
              child: Text(
                firstLetter,
                style: TextStyle(
              color: AppStyles.primarySage,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Text(
                    displayName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                      fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
                    client['email'] ?? '',
              style: TextStyle(
                      fontSize: 14,
                color: AppStyles.slateGray,
              ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pending approval',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.warningAmber,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppStyles.slateGray,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToClientReview(BuildContext context, Map<String, dynamic> client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientReviewScreen(client: client),
      ),
    );
  }
}

class ClientReviewScreen extends StatelessWidget {
  final Map<String, dynamic> client;

  const ClientReviewScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final onboardingData = client['onboardingData'] as Map<String, dynamic>? ?? {};
    final displayName = client['displayName'] ?? client['email'] ?? 'Unknown Client';
    final firstLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Review $displayName'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client Info Card
                    _buildSectionCard(
                      'Client Information',
                      [
                        _buildInfoRow('Name', displayName),
                        _buildInfoRow('Email', client['email'] ?? 'Not provided'),
                        _buildInfoRow('Phone', onboardingData['phoneNumber'] ?? 'Not provided'),
                        _buildInfoRow('Address', onboardingData['address'] ?? 'Not provided'),
                        if (onboardingData['emergencyContact'] != null)
                          _buildInfoRow('Emergency Contact', onboardingData['emergencyContact']),
                        if (onboardingData['emergencyPhone'] != null)
                          _buildInfoRow('Emergency Phone', onboardingData['emergencyPhone']),
                      ],
                      icon: Icons.person,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Medical History Section
                    if (_hasMedicalData(onboardingData))
                      _buildSectionCard(
                        'Medical History',
                        [
                          if (onboardingData['lastPhysicalDate'] != null)
                            _buildInfoRow('Last Physical Date', onboardingData['lastPhysicalDate']),
                          if (onboardingData['lastPhysicalResult'] != null)
                            _buildInfoRow('Last Physical Result', onboardingData['lastPhysicalResult']),
                          if (onboardingData['hasHeartDisease'] != null)
                            _buildYesNoRow('Has Heart Disease', onboardingData['hasHeartDisease']),
                          if (onboardingData['hasBreathingIssues'] != null)
                            _buildYesNoRow('Has Breathing Issues', onboardingData['hasBreathingIssues']),
                          if (onboardingData['hasDoctorNoteHeartTrouble'] != null)
                            _buildYesNoRow('Doctor Noted Heart Trouble', onboardingData['hasDoctorNoteHeartTrouble']),
                          if (onboardingData['hasAnginaPectoris'] != null)
                            _buildYesNoRow('Has Angina Pectoris', onboardingData['hasAnginaPectoris']),
                          if (onboardingData['hasHeartPalpitations'] != null)
                            _buildYesNoRow('Has Heart Palpitations', onboardingData['hasHeartPalpitations']),
                          if (onboardingData['hasHeartAttack'] != null)
                            _buildYesNoRow('Has Had Heart Attack', onboardingData['hasHeartAttack']),
                          if (onboardingData['hasDiabetesOrHighBloodPressure'] != null)
                            _buildYesNoRow('Has Diabetes/High Blood Pressure', onboardingData['hasDiabetesOrHighBloodPressure']),
                          if (onboardingData['hasHeartDiseaseInFamily'] != null)
                            _buildYesNoRow('Family History of Heart Disease', onboardingData['hasHeartDiseaseInFamily']),
                          if (onboardingData['hasCholesterolMedication'] != null)
                            _buildYesNoRow('Takes Cholesterol Medication', onboardingData['hasCholesterolMedication']),
                          if (onboardingData['hasHeartMedication'] != null)
                            _buildYesNoRow('Takes Heart Medication', onboardingData['hasHeartMedication']),
                          if (onboardingData['sleepsWell'] != null)
                            _buildYesNoRow('Sleeps Well', onboardingData['sleepsWell']),
                          if (onboardingData['drinksDailyAlcohol'] != null)
                            _buildYesNoRow('Drinks Daily', onboardingData['drinksDailyAlcohol']),
                          if (onboardingData['smokescigarettes'] != null)
                            _buildYesNoRow('Smokes Cigarettes', onboardingData['smokescigarettes']),
                          if (onboardingData['hasPhysicalCondition'] != null)
                            _buildYesNoRow('Has Physical Condition', onboardingData['hasPhysicalCondition']),
                          if (onboardingData['hasJointOrMuscleProblems'] != null)
                            _buildYesNoRow('Has Joint/Muscle Problems', onboardingData['hasJointOrMuscleProblems']),
                          if (onboardingData['isPregnant'] != null)
                            _buildYesNoRow('Is Pregnant', onboardingData['isPregnant']),
                          if (onboardingData['additionalMedicalInfo'] != null && onboardingData['additionalMedicalInfo'].toString().isNotEmpty)
                            _buildTextAreaRow('Additional Medical Info', onboardingData['additionalMedicalInfo']),
                        ],
                        icon: Icons.favorite,
                      ),
                    
                    if (_hasMedicalData(onboardingData)) const SizedBox(height: 16),
                    
                    // Lifestyle & Exercise Section
                    if (_hasLifestyleData(onboardingData))
                      _buildSectionCard(
                        'Lifestyle & Exercise',
                        [
                          if (onboardingData['exerciseFrequency'] != null)
                            _buildInfoRow('Exercise Frequency', onboardingData['exerciseFrequency']),
                          if (onboardingData['medications'] != null)
                            _buildInfoRow('Medications', onboardingData['medications']),
                          if (onboardingData['healthGoals'] != null)
                            _buildTextAreaRow('Health Goals', onboardingData['healthGoals']),
                          if (onboardingData['stressLevel'] != null)
                            _buildInfoRow('Stress Level', onboardingData['stressLevel']),
                          if (onboardingData['bestLifePoint'] != null)
                            _buildTextAreaRow('Best Life Point', onboardingData['bestLifePoint']),
                          if (onboardingData['selectedGoals'] != null && onboardingData['selectedGoals'] is List)
                            _buildInfoRow('Fitness Goals', (onboardingData['selectedGoals'] as List).join(', ')),
                        ],
                        icon: Icons.fitness_center,
                      ),
                    
                    if (_hasLifestyleData(onboardingData)) const SizedBox(height: 16),
                    
                    // Dietary Information Section
                    if (_hasDietaryData(onboardingData))
                      _buildSectionCard(
                        'Dietary Information',
                        [
                          if (onboardingData['eatingHabits'] != null)
                            _buildTextAreaRow('Eating Habits', onboardingData['eatingHabits']),
                          if (onboardingData['regularFoods'] != null && onboardingData['regularFoods'] is List)
                            _buildInfoRow('Regular Foods', (onboardingData['regularFoods'] as List).join(', ')),
                          if (onboardingData['typicalBreakfast'] != null)
                            _buildInfoRow('Typical Breakfast', onboardingData['typicalBreakfast']),
                          if (onboardingData['typicalLunch'] != null)
                            _buildInfoRow('Typical Lunch', onboardingData['typicalLunch']),
                          if (onboardingData['typicalDinner'] != null)
                            _buildInfoRow('Typical Dinner', onboardingData['typicalDinner']),
                          if (onboardingData['typicalSnacks'] != null)
                            _buildInfoRow('Typical Snacks', onboardingData['typicalSnacks']),
                        ],
                        icon: Icons.restaurant,
                      ),
                    
                    if (_hasDietaryData(onboardingData)) const SizedBox(height: 16),
                    
                    // Fitness Ratings Section
                    if (_hasFitnessRatings(onboardingData))
                      _buildSectionCard(
                        'Fitness Self-Assessment',
                        [
                          if (onboardingData['cardioRespiratoryRating'] != null)
                            _buildRatingRow('Cardio-Respiratory', onboardingData['cardioRespiratoryRating']),
                          if (onboardingData['strengthRating'] != null)
                            _buildRatingRow('Strength', onboardingData['strengthRating']),
                          if (onboardingData['enduranceRating'] != null)
                            _buildRatingRow('Endurance', onboardingData['enduranceRating']),
                          if (onboardingData['flexibilityRating'] != null)
                            _buildRatingRow('Flexibility', onboardingData['flexibilityRating']),
                          if (onboardingData['powerRating'] != null)
                            _buildRatingRow('Power', onboardingData['powerRating']),
                          if (onboardingData['bodyCompositionRating'] != null)
                            _buildRatingRow('Body Composition', onboardingData['bodyCompositionRating']),
                          if (onboardingData['selfImageRating'] != null)
                            _buildRatingRow('Self Image', onboardingData['selfImageRating']),
                        ],
                        icon: Icons.assessment,
                      ),
                    
                    if (_hasFitnessRatings(onboardingData)) const SizedBox(height: 16),
                    
                    // Additional Notes Section
                    if (onboardingData['additionalNotes'] != null && onboardingData['additionalNotes'].toString().isNotEmpty)
                      _buildSectionCard(
                        'Additional Notes',
                        [
                          _buildTextAreaRow('Notes', onboardingData['additionalNotes']),
                        ],
                        icon: Icons.note,
                      ),
                    
                    // Signature Section
                    if (onboardingData['signatureTimestamp'] != null)
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildSectionCard(
                            'Agreement Signed',
                            [
                              _buildInfoRow('Signed on', onboardingData['signatureTimestamp']),
                            ],
                            icon: Icons.assignment_turned_in,
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 32), // Extra space before buttons
                  ],
                ),
              ),
            ),
            
            // Action Buttons with proper spacing
            Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
                    color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
                    offset: const Offset(0, -2),
          ),
        ],
      ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _approveClient(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyles.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Approve Client',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => _rejectClient(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppStyles.errorRed,
                          side: BorderSide(color: AppStyles.errorRed),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build section cards
  Widget _buildSectionCard(String title, List<Widget> children, {required IconData icon}) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Icon(icon, color: AppStyles.primarySage, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.primarySage,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(thickness: 1),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  // Helper method for regular info rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: Color(0xFF555555),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for text area rows
  Widget _buildTextAreaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Text(
            value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build yes/no rows
  Widget _buildYesNoRow(String label, dynamic value) {
    bool? boolValue;
    if (value is bool) {
      boolValue = value;
    } else if (value is String) {
      boolValue = value.toLowerCase() == 'true';
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Color(0xFF555555),
              ),
            ),
          ),
          const Spacer(),
          boolValue == null
              ? const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Text('Not provided', 
            style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF888888),
                    ),
                  ),
                )
              : Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: boolValue ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: boolValue ? Colors.red.shade300 : Colors.green.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        boolValue ? Icons.cancel : Icons.check_circle,
                        size: 16,
                        color: boolValue ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        boolValue ? 'Yes' : 'No',
                        style: TextStyle(
                          fontSize: 14,
                          color: boolValue ? Colors.red.shade700 : Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  // Helper method to build rating rows
  Widget _buildRatingRow(String label, dynamic rating) {
    int ratingValue = 0;
    if (rating is int) {
      ratingValue = rating;
    } else if (rating is String) {
      ratingValue = int.tryParse(rating) ?? 0;
    }
    
    Color ratingColor;
    String ratingText;
    
    if (ratingValue < 4) {
      ratingColor = Colors.red.shade400;
      ratingText = 'Low';
    } else if (ratingValue < 7) {
      ratingColor = Colors.orange.shade400;
      ratingText = 'Medium';
    } else {
      ratingColor = Colors.green.shade400;
      ratingText = 'High';
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 110,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ratingColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ratingColor, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ratingValue.toString(),
                      style: TextStyle(
                        color: ratingColor,
              fontWeight: FontWeight.bold,
                        fontSize: 16,
            ),
          ),
                    const SizedBox(width: 8),
          Text(
                      ratingText,
            style: TextStyle(
                        color: ratingColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ratingValue / 10,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: ratingColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods to check if sections have data
  bool _hasMedicalData(Map<String, dynamic> data) {
    return data['lastPhysicalDate'] != null ||
           data['lastPhysicalResult'] != null ||
           data['hasHeartDisease'] != null ||
           data['hasBreathingIssues'] != null ||
           data['additionalMedicalInfo'] != null;
  }

  bool _hasLifestyleData(Map<String, dynamic> data) {
    return data['exerciseFrequency'] != null ||
           data['medications'] != null ||
           data['healthGoals'] != null ||
           data['stressLevel'] != null ||
           data['bestLifePoint'] != null ||
           data['selectedGoals'] != null;
  }

  bool _hasDietaryData(Map<String, dynamic> data) {
    return data['eatingHabits'] != null ||
           data['regularFoods'] != null ||
           data['typicalBreakfast'] != null ||
           data['typicalLunch'] != null ||
           data['typicalDinner'] != null ||
           data['typicalSnacks'] != null;
  }

  bool _hasFitnessRatings(Map<String, dynamic> data) {
    return data['cardioRespiratoryRating'] != null ||
           data['strengthRating'] != null ||
           data['enduranceRating'] != null ||
           data['flexibilityRating'] != null ||
           data['powerRating'] != null ||
           data['bodyCompositionRating'] != null ||
           data['selfImageRating'] != null;
  }

  Future<void> _rejectClient(BuildContext context) async {
    final displayName = client['displayName'] ?? client['email'] ?? 'Unknown Client';
    
    // Show dialog to get rejection reason
    final rejectionReason = await _showRejectionReasonDialog(context);
    if (rejectionReason == null || rejectionReason.trim().isEmpty) {
      // User cancelled or didn't provide a reason
      return;
    }
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(client['id'])
          .update({
            'accountStatus': 'rejected',
            'rejectionReason': rejectionReason.trim(),
          });
      
      // Send rejection notification to the client
      final notificationService = NotificationService();
      await notificationService.sendAccountRejectionNotification(client['id']);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$displayName has been rejected'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting client: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
    }
  }

  Future<String?> _showRejectionReasonDialog(BuildContext context) async {
    final TextEditingController reasonController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rejection Reason'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide a reason for rejecting this client application:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppStyles.primarySage),
                  ),
                ),
              ),
            ],
          ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppStyles.slateGray),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isNotEmpty) {
                  Navigator.of(context).pop(reason);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyles.errorRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject Client'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approveClient(BuildContext context) async {
    final displayName = client['displayName'] ?? client['email'] ?? 'Unknown Client';
    
    // Show trainer selection dialog first
    final selectedTrainer = await _showTrainerSelectionDialog(context);
    if (selectedTrainer == null) {
      // User cancelled trainer selection
      return;
    }
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(client['id'])
          .update({
            'accountStatus': 'approved',
            'trainerId': selectedTrainer['id'], // Assign selected trainer
          });
      
      // Send approval notification to the client
      final notificationService = NotificationService();
      await notificationService.sendAccountApprovalNotification(client['id']);
      
      // Create default session package with $1000 cost
      final paymentService = PaymentService();
      await paymentService.createDefaultSessionPackage(
        clientId: client['id'],
        trainerId: selectedTrainer['id'],
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$displayName has been approved and assigned to ${selectedTrainer['name']}'),
            backgroundColor: AppStyles.successGreen,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving client: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showTrainerSelectionDialog(BuildContext context) async {
    // Get all available trainers
    List<Map<String, dynamic>> trainers = [];
    
    try {
      // Get both regular trainers and super trainers
      final trainerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'trainer')
          .get();
          
      final superTrainerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'superTrainer')
          .get();
      
      for (final doc in [...trainerQuery.docs, ...superTrainerQuery.docs]) {
        final data = doc.data();
        final displayName = data['displayName'] ?? 
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final name = displayName.isNotEmpty ? displayName : data['email'] ?? 'Unknown';
        
        trainers.add({
          'id': doc.id,
          'name': name,
          'email': data['email'] ?? '',
          'role': data['role'] ?? 'trainer',
        });
      }
      
      if (trainers.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No trainers available for assignment'),
              backgroundColor: AppStyles.errorRed,
            ),
          );
        }
        return null;
      }
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading trainers: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
      return null;
    }
    
    // Show selection dialog
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Assign Trainer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a trainer to assign to ${client['displayName'] ?? client['email']}:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    children: trainers.map((trainer) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppStyles.primarySage.withOpacity(0.2),
                            child: Text(
                              trainer['name'].isNotEmpty ? trainer['name'][0].toUpperCase() : 'T',
                              style: TextStyle(
                                color: AppStyles.primarySage,
                                fontWeight: FontWeight.bold,
          ),
                            ),
                          ),
                          title: Text(trainer['name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(trainer['email']),
                              Text(
                                trainer['role'] == 'superTrainer' ? 'Super Trainer' : 'Trainer',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppStyles.primarySage,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: AppStyles.primarySage.withOpacity(0.2)),
                          ),
                          onTap: () => Navigator.of(context).pop(trainer),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppStyles.slateGray),
              ),
            ),
          ],
        );
      },
    );
  }
} 