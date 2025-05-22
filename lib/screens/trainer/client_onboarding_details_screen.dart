import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/onboarding_form_model.dart';
import '../../theme/app_styles.dart';

class ClientOnboardingDetailsScreen extends StatelessWidget {
  final OnboardingFormModel onboardingForm;
  final String clientName;

  const ClientOnboardingDetailsScreen({
    super.key,
    required this.onboardingForm,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${clientName}\'s Onboarding Form'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
      ),
      body: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            Container(
              color: AppStyles.offWhite,
              child: TabBar(
                isScrollable: true,
                indicatorColor: AppStyles.primarySage,
                labelColor: AppStyles.primarySage,
                unselectedLabelColor: AppStyles.textDark,
                tabs: const [
                  Tab(text: 'Personal Info'),
                  Tab(text: 'Medical History'),
                  Tab(text: 'Lifestyle'),
                  Tab(text: 'Fitness'),
                  Tab(text: 'Gym Setup'),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.grey[50],
                child: TabBarView(
                  children: [
                    _buildPersonalInfoTab(),
                    _buildMedicalHistoryTab(),
                    _buildLifestyleTab(),
                    _buildFitnessTab(),
                    _buildGymSetupTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Personal Info Tab
  Widget _buildPersonalInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Personal Information',
            [
              _buildInfoRow('Name', onboardingForm.clientName),
              _buildInfoRow('Email', onboardingForm.email ?? 'Not provided'),
              _buildInfoRow('Phone', onboardingForm.phoneNumber ?? 'Not provided'),
              _buildInfoRow('Address', onboardingForm.address ?? 'Not provided'),
              _buildInfoRow(
                'Date of Birth', 
                onboardingForm.dateOfBirth != null 
                  ? DateFormat.yMMMd().format(onboardingForm.dateOfBirth!) 
                  : 'Not provided'
              ),
              _buildInfoRow(
                'Height', 
                onboardingForm.height != null 
                  ? '${_cmToFeetInches(onboardingForm.height!)} (${onboardingForm.height!.toStringAsFixed(1)} cm)' 
                  : 'Not provided'
              ),
              _buildInfoRow(
                'Weight', 
                onboardingForm.weight != null 
                  ? '${_kgToLbs(onboardingForm.weight!).toStringAsFixed(1)} lbs (${onboardingForm.weight!.toStringAsFixed(1)} kg)' 
                  : 'Not provided'
              ),
            ],
            icon: Icons.person,
          ),
          
          const SizedBox(height: 16),
          _buildSectionCard(
            'Emergency Contact',
            [
              _buildInfoRow('Name', onboardingForm.emergencyContact ?? 'Not provided'),
              _buildInfoRow('Phone', onboardingForm.emergencyPhone ?? 'Not provided'),
            ],
            icon: Icons.contact_phone,
          ),
          
          if (onboardingForm.signatureTimestamp != null) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              'Contract',
              [
                _buildInfoRow('Signed on', onboardingForm.signatureTimestamp!),
              ],
              icon: Icons.assignment_turned_in,
            ),
          ],
        ],
      ),
    );
  }
  
  // Medical History Tab
  Widget _buildMedicalHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Medical Information',
            [
              _buildLabelValueRow('Last Physical Date', onboardingForm.lastPhysicalDate ?? 'Not provided'),
              _buildLabelValueRow('Last Physical Result', onboardingForm.lastPhysicalResult ?? 'Not provided'),
            ],
            icon: Icons.calendar_today,
          ),
          
          const SizedBox(height: 16),
          _buildSectionCard(
            'Medical History',
            [
              _buildYesNoRow('Has Heart Disease', onboardingForm.hasHeartDisease),
              _buildYesNoRow('Has Breathing Issues', onboardingForm.hasBreathingIssues),
              _buildYesNoRow('Doctor Noted Heart Trouble', onboardingForm.hasDoctorNoteHeartTrouble),
              _buildYesNoRow('Has Angina Pectoris', onboardingForm.hasAnginaPectoris),
              _buildYesNoRow('Has Heart Palpitations', onboardingForm.hasHeartPalpitations),
              _buildYesNoRow('Has Had Heart Attack', onboardingForm.hasHeartAttack),
              _buildYesNoRow('Has Diabetes/High Blood Pressure', onboardingForm.hasDiabetesOrHighBloodPressure),
              _buildYesNoRow('Family History of Heart Disease', onboardingForm.hasHeartDiseaseInFamily),
              _buildYesNoRow('Takes Cholesterol Medication', onboardingForm.hasCholesterolMedication),
              _buildYesNoRow('Takes Heart Medication', onboardingForm.hasHeartMedication),
            ],
            icon: Icons.favorite,
          ),
          
          const SizedBox(height: 16),
          _buildSectionCard(
            'Lifestyle Health Factors',
            [
              _buildYesNoRow('Sleeps Well', onboardingForm.sleepsWell),
              _buildYesNoRow('Drinks Daily', onboardingForm.drinksDailyAlcohol),
              _buildYesNoRow('Smokes Cigarettes', onboardingForm.smokescigarettes),
              _buildYesNoRow('Has Physical Condition', onboardingForm.hasPhysicalCondition),
              _buildYesNoRow('Has Joint/Muscle Problems', onboardingForm.hasJointOrMuscleProblems),
              _buildYesNoRow('Is Pregnant', onboardingForm.isPregnant),
            ],
            icon: Icons.nightlight,
          ),
          
          if (onboardingForm.additionalMedicalInfo != null && onboardingForm.additionalMedicalInfo!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              'Additional Medical Information',
              [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: Text(onboardingForm.additionalMedicalInfo!),
                ),
              ],
              icon: Icons.info_outline,
            ),
          ],
        ],
      ),
    );
  }
  
  // Lifestyle Tab
  Widget _buildLifestyleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Exercise & Goals',
            [
              _buildInfoRow('Exercise Frequency', onboardingForm.exerciseFrequency ?? 'Not provided'),
              _buildInfoRow('Health Goals', onboardingForm.healthGoals ?? 'Not provided'),
              _buildInfoRow('Stress Level', onboardingForm.stressLevel ?? 'Not provided'),
              _buildInfoRow('Best Life Point', onboardingForm.bestLifePoint ?? 'Not provided'),
            ],
            icon: Icons.fitness_center,
          ),
          
          const SizedBox(height: 16),
          _buildSectionCard(
            'Medications',
            [
              _buildInfoRow('Current Medications', onboardingForm.medications ?? 'None reported'),
            ],
            icon: Icons.medication,
          ),
          
          const SizedBox(height: 16),
          _buildSectionCard(
            'Fitness Goals',
            [
              ...(onboardingForm.healthGoals?.isNotEmpty == true 
              ? [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Text(onboardingForm.healthGoals!),
                  ),
                ] 
              : [_buildInfoRow('Goals', 'None specified')]),
            ],
            icon: Icons.flag,
          ),
          
          const SizedBox(height: 16),
          _buildSectionCard(
            'Dietary Information',
            [
              _buildInfoRow('Eating Habits', onboardingForm.eatingHabits ?? 'Not provided'),
              _buildInfoRow('Foods Eaten Regularly', 
                onboardingForm.regularFoods.isNotEmpty 
                  ? onboardingForm.regularFoods.join(', ') 
                  : 'None specified'),
            ],
            icon: Icons.restaurant,
          ),
              
          const SizedBox(height: 16),
          _buildSectionCard(
            'Typical Diet',
            [
              _buildInfoRow('Breakfast', onboardingForm.typicalBreakfast ?? 'Not provided'),
              _buildInfoRow('Lunch', onboardingForm.typicalLunch ?? 'Not provided'),
              _buildInfoRow('Dinner', onboardingForm.typicalDinner ?? 'Not provided'),
              _buildInfoRow('Snacks', onboardingForm.typicalSnacks ?? 'Not provided'),
            ],
            icon: Icons.fastfood,
          ),
        ],
      ),
    );
  }
  
  // Fitness Tab
  Widget _buildFitnessTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Fitness Self-Assessment',
            [
              _buildRatingRow('Cardio-Respiratory', onboardingForm.cardioRespiratoryRating ?? 0),
              _buildRatingRow('Strength', onboardingForm.strengthRating ?? 0),
              _buildRatingRow('Endurance', onboardingForm.enduranceRating ?? 0),
              _buildRatingRow('Flexibility', onboardingForm.flexibilityRating ?? 0),
              _buildRatingRow('Power', onboardingForm.powerRating ?? 0),
              _buildRatingRow('Body Composition', onboardingForm.bodyCompositionRating ?? 0),
              _buildRatingRow('Self Image', onboardingForm.selfImageRating ?? 0),
            ],
            icon: Icons.assessment,
          ),
          
          if (onboardingForm.additionalNotes != null && onboardingForm.additionalNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              'Additional Notes',
              [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: Text(onboardingForm.additionalNotes!),
                ),
              ],
              icon: Icons.note,
            ),
          ],
        ],
      ),
    );
  }
  
  // Gym Setup Tab
  Widget _buildGymSetupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Client\'s Gym Setup Photos',
            [
              onboardingForm.gymSetupPhotos.isNotEmpty
                ? GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: onboardingForm.gymSetupPhotos.length,
                    itemBuilder: (context, index) {
                      final photoUrl = onboardingForm.gymSetupPhotos[index];
                      return GestureDetector(
                        onTap: () => _showFullScreenImage(context, photoUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / 
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading image: $error');
                              return Container(
                                color: Colors.grey[200],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Text(
                                        'Error loading image',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red[700],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, 
                            size: 64, 
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No gym setup photos available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            icon: Icons.photo_camera,
          ),
        ],
      ),
    );
  }
  
  // Helper method to show full-screen image
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppStyles.primarySage,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / 
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
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
  
  // Helper method to build section titles - keep for backward compatibility
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppStyles.primarySage,
            ),
          ),
          const Divider(thickness: 1),
        ],
      ),
    );
  }
  
  // Helper method to build label-value rows without semicolon
  Widget _buildLabelValueRow(String label, String value) {
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
  
  // Helper method for regular info rows without semicolon
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
  
  // Helper method to build yes/no rows
  Widget _buildYesNoRow(String label, bool? value) {
    // No longer using isNoPositive - all Nos get green check, all Yeses get red X
    // Colors for No (always green) and Yes (always red)
    final Color noColor = Colors.green;
    final Color yesColor = Colors.red;
    
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
          Spacer(), // Add spacer to push content to the right
          value == null
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
                  width: 80, // Fixed width for consistent bubble size
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: value ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: value ? Colors.red.shade300 : Colors.green.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center, // Center content
                    children: [
                      Icon(
                        value ? Icons.cancel : Icons.check_circle,
                        size: 16,
                        color: value ? yesColor : noColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        value ? 'Yes' : 'No',
                        style: TextStyle(
                          fontSize: 14,
                          color: value ? Colors.red.shade700 : Colors.green.shade700,
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
  Widget _buildRatingRow(String label, int rating) {
    Color ratingColor;
    String ratingText;
    
    if (rating < 4) {
      ratingColor = Colors.red.shade400;
      ratingText = 'Low';
    } else if (rating < 7) {
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
                width: 110, // Fixed width for consistent bubble size
                height: 40, // Fixed height for better appearance
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ratingColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20), // More rounded corners
                  border: Border.all(color: ratingColor, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, // Center the content
                  children: [
                    Text(
                      rating.toString(),
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
                      height: 10, // Slightly taller progress bar
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: rating / 10,
                      child: Container(
                        height: 10, // Slightly taller progress bar
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
  
  // Helper method to convert cm to feet and inches
  String _cmToFeetInches(double cm) {
    double totalInches = cm / 2.54;
    int feet = (totalInches / 12).floor();
    int inches = (totalInches % 12).round();
    return '$feet ft $inches in';
  }
  
  // Helper method to convert kg to lbs
  double _kgToLbs(double kg) {
    return kg * 2.20462;
  }
} 