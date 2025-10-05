import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/onboarding_form_model.dart';
import '../../services/onboarding_service.dart';
import '../../theme/app_styles.dart';
import '../../widgets/onboarding_form_widgets.dart';

class ClientEditableOnboardingScreen extends StatefulWidget {
  final OnboardingFormModel onboardingForm;
  final String clientName;

  const ClientEditableOnboardingScreen({
    super.key,
    required this.onboardingForm,
    required this.clientName,
  });

  @override
  State<ClientEditableOnboardingScreen> createState() => _ClientEditableOnboardingScreenState();
}

class _ClientEditableOnboardingScreenState extends State<ClientEditableOnboardingScreen> {
  final OnboardingService _onboardingService = OnboardingService();
  final _formKey = GlobalKey<FormState>();
  
  bool _isEditing = false;
  bool _isSaving = false;
  
  // Controllers for editable fields
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _lastPhysicalDateController;
  late TextEditingController _lastPhysicalResultController;
  late TextEditingController _additionalMedicalInfoController;
  late TextEditingController _exerciseFrequencyController;
  late TextEditingController _medicationsController;
  late TextEditingController _healthGoalsController;
  late TextEditingController _stressLevelController;
  late TextEditingController _bestLifePointController;
  late TextEditingController _eatingHabitsController;
  late TextEditingController _typicalBreakfastController;
  late TextEditingController _typicalLunchController;
  late TextEditingController _typicalDinnerController;
  late TextEditingController _typicalSnacksController;
  late TextEditingController _additionalNotesController;
  
  // Editable state variables
  late bool? _hasHeartDisease;
  late bool? _hasBreathingIssues;
  late bool? _hasDoctorNoteHeartTrouble;
  late bool? _hasAnginaPectoris;
  late bool? _hasHeartPalpitations;
  late bool? _hasHeartAttack;
  late bool? _hasDiabetesOrHighBloodPressure;
  late bool? _hasHeartDiseaseInFamily;
  late bool? _hasCholesterolMedication;
  late bool? _hasHeartMedication;
  late bool? _sleepsWell;
  late bool? _drinksDailyAlcohol;
  late bool? _smokescigarettes;
  late bool? _hasPhysicalCondition;
  late bool? _hasJointOrMuscleProblems;
  late bool? _isPregnant;
  late List<String> _regularFoods;
  late int _cardioRespiratoryRating;
  late int _strengthRating;
  late int _enduranceRating;
  late int _flexibilityRating;
  late int _powerRating;
  late int _bodyCompositionRating;
  late int _selfImageRating;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _phoneController = TextEditingController(text: widget.onboardingForm.phoneNumber);
    _addressController = TextEditingController(text: widget.onboardingForm.address);
    _emergencyContactController = TextEditingController(text: widget.onboardingForm.emergencyContact);
    _emergencyPhoneController = TextEditingController(text: widget.onboardingForm.emergencyPhone);
    _lastPhysicalDateController = TextEditingController(text: widget.onboardingForm.lastPhysicalDate);
    _lastPhysicalResultController = TextEditingController(text: widget.onboardingForm.lastPhysicalResult);
    _additionalMedicalInfoController = TextEditingController(text: widget.onboardingForm.additionalMedicalInfo);
    _exerciseFrequencyController = TextEditingController(text: widget.onboardingForm.exerciseFrequency);
    _medicationsController = TextEditingController(text: widget.onboardingForm.medications);
    _healthGoalsController = TextEditingController(text: widget.onboardingForm.healthGoals);
    _stressLevelController = TextEditingController(text: widget.onboardingForm.stressLevel);
    _bestLifePointController = TextEditingController(text: widget.onboardingForm.bestLifePoint);
    _eatingHabitsController = TextEditingController(text: widget.onboardingForm.eatingHabits);
    _typicalBreakfastController = TextEditingController(text: widget.onboardingForm.typicalBreakfast);
    _typicalLunchController = TextEditingController(text: widget.onboardingForm.typicalLunch);
    _typicalDinnerController = TextEditingController(text: widget.onboardingForm.typicalDinner);
    _typicalSnacksController = TextEditingController(text: widget.onboardingForm.typicalSnacks);
    _additionalNotesController = TextEditingController(text: widget.onboardingForm.additionalNotes);
    
    _hasHeartDisease = widget.onboardingForm.hasHeartDisease;
    _hasBreathingIssues = widget.onboardingForm.hasBreathingIssues;
    _hasDoctorNoteHeartTrouble = widget.onboardingForm.hasDoctorNoteHeartTrouble;
    _hasAnginaPectoris = widget.onboardingForm.hasAnginaPectoris;
    _hasHeartPalpitations = widget.onboardingForm.hasHeartPalpitations;
    _hasHeartAttack = widget.onboardingForm.hasHeartAttack;
    _hasDiabetesOrHighBloodPressure = widget.onboardingForm.hasDiabetesOrHighBloodPressure;
    _hasHeartDiseaseInFamily = widget.onboardingForm.hasHeartDiseaseInFamily;
    _hasCholesterolMedication = widget.onboardingForm.hasCholesterolMedication;
    _hasHeartMedication = widget.onboardingForm.hasHeartMedication;
    _sleepsWell = widget.onboardingForm.sleepsWell;
    _drinksDailyAlcohol = widget.onboardingForm.drinksDailyAlcohol;
    _smokescigarettes = widget.onboardingForm.smokescigarettes;
    _hasPhysicalCondition = widget.onboardingForm.hasPhysicalCondition;
    _hasJointOrMuscleProblems = widget.onboardingForm.hasJointOrMuscleProblems;
    _isPregnant = widget.onboardingForm.isPregnant;
    _regularFoods = List.from(widget.onboardingForm.regularFoods);
    _cardioRespiratoryRating = widget.onboardingForm.cardioRespiratoryRating ?? 5;
    _strengthRating = widget.onboardingForm.strengthRating ?? 5;
    _enduranceRating = widget.onboardingForm.enduranceRating ?? 5;
    _flexibilityRating = widget.onboardingForm.flexibilityRating ?? 5;
    _powerRating = widget.onboardingForm.powerRating ?? 5;
    _bodyCompositionRating = widget.onboardingForm.bodyCompositionRating ?? 5;
    _selfImageRating = widget.onboardingForm.selfImageRating ?? 5;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _lastPhysicalDateController.dispose();
    _lastPhysicalResultController.dispose();
    _additionalMedicalInfoController.dispose();
    _exerciseFrequencyController.dispose();
    _medicationsController.dispose();
    _healthGoalsController.dispose();
    _stressLevelController.dispose();
    _bestLifePointController.dispose();
    _eatingHabitsController.dispose();
    _typicalBreakfastController.dispose();
    _typicalLunchController.dispose();
    _typicalDinnerController.dispose();
    _typicalSnacksController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updatedForm = widget.onboardingForm.copyWith(
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        emergencyContact: _emergencyContactController.text.trim(),
        emergencyPhone: _emergencyPhoneController.text.trim(),
        lastPhysicalDate: _lastPhysicalDateController.text.trim(),
        lastPhysicalResult: _lastPhysicalResultController.text.trim(),
        hasHeartDisease: _hasHeartDisease,
        hasBreathingIssues: _hasBreathingIssues,
        hasDoctorNoteHeartTrouble: _hasDoctorNoteHeartTrouble,
        hasAnginaPectoris: _hasAnginaPectoris,
        hasHeartPalpitations: _hasHeartPalpitations,
        hasHeartAttack: _hasHeartAttack,
        hasDiabetesOrHighBloodPressure: _hasDiabetesOrHighBloodPressure,
        hasHeartDiseaseInFamily: _hasHeartDiseaseInFamily,
        hasCholesterolMedication: _hasCholesterolMedication,
        hasHeartMedication: _hasHeartMedication,
        sleepsWell: _sleepsWell,
        drinksDailyAlcohol: _drinksDailyAlcohol,
        smokescigarettes: _smokescigarettes,
        hasPhysicalCondition: _hasPhysicalCondition,
        hasJointOrMuscleProblems: _hasJointOrMuscleProblems,
        isPregnant: _isPregnant,
        additionalMedicalInfo: _additionalMedicalInfoController.text.trim(),
        exerciseFrequency: _exerciseFrequencyController.text.trim(),
        medications: _medicationsController.text.trim(),
        healthGoals: _healthGoalsController.text.trim(),
        stressLevel: _stressLevelController.text.trim(),
        bestLifePoint: _bestLifePointController.text.trim(),
        regularFoods: _regularFoods,
        eatingHabits: _eatingHabitsController.text.trim(),
        typicalBreakfast: _typicalBreakfastController.text.trim(),
        typicalLunch: _typicalLunchController.text.trim(),
        typicalDinner: _typicalDinnerController.text.trim(),
        typicalSnacks: _typicalSnacksController.text.trim(),
        cardioRespiratoryRating: _cardioRespiratoryRating,
        strengthRating: _strengthRating,
        enduranceRating: _enduranceRating,
        flexibilityRating: _flexibilityRating,
        powerRating: _powerRating,
        bodyCompositionRating: _bodyCompositionRating,
        selfImageRating: _selfImageRating,
        additionalNotes: _additionalNotesController.text.trim(),
      );

      if (widget.onboardingForm.id == null) {
        throw Exception('Onboarding form ID is missing');
      }
      
      await _onboardingService.updateClientOnboardingForm(
        widget.onboardingForm.id!,
        updatedForm,
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Onboarding information updated successfully'),
            backgroundColor: AppStyles.successGreen,
          ),
        );
        
        // Pop back to refresh
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating information: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Onboarding Information'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppStyles.primarySage,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppStyles.primarySage,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Information',
            ),
        ],
      ),
      body: DefaultTabController(
        length: 4,
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
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.grey[50],
                child: Form(
                  key: _formKey,
                  child: TabBarView(
                    children: [
                      _buildPersonalInfoTab(),
                      _buildMedicalHistoryTab(),
                      _buildLifestyleTab(),
                      _buildFitnessTab(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Personal Information',
            [
              _buildReadOnlyRow('Name', widget.onboardingForm.clientName),
              _buildReadOnlyRow('Email', widget.onboardingForm.email ?? 'Not provided'),
              _buildEditableRow('Phone', _phoneController),
              _buildEditableRow('Address', _addressController, maxLines: 2),
              _buildReadOnlyRow(
                'Date of Birth',
                widget.onboardingForm.dateOfBirth != null
                    ? DateFormat.yMMMd().format(widget.onboardingForm.dateOfBirth!)
                    : 'Not provided',
              ),
              _buildReadOnlyRow(
                'Height',
                widget.onboardingForm.height != null
                    ? '${_cmToFeetInches(widget.onboardingForm.height!)} (${widget.onboardingForm.height!.toStringAsFixed(1)} cm)'
                    : 'Not provided',
              ),
              _buildReadOnlyRow(
                'Weight',
                widget.onboardingForm.weight != null
                    ? '${_kgToLbs(widget.onboardingForm.weight!).toStringAsFixed(1)} lbs (${widget.onboardingForm.weight!.toStringAsFixed(1)} kg)'
                    : 'Not provided',
              ),
            ],
            icon: Icons.person,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Emergency Contact',
            [
              _buildEditableRow('Name', _emergencyContactController),
              _buildEditableRow('Phone', _emergencyPhoneController),
            ],
            icon: Icons.contact_phone,
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Medical Information',
            [
              _buildEditableRow('Last Physical Date', _lastPhysicalDateController),
              _buildEditableRow('Last Physical Result', _lastPhysicalResultController),
            ],
            icon: Icons.calendar_today,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Medical History',
            [
              _buildEditableYesNoRow('Has Heart Disease', _hasHeartDisease, (value) {
                setState(() => _hasHeartDisease = value);
              }),
              _buildEditableYesNoRow('Has Breathing Issues', _hasBreathingIssues, (value) {
                setState(() => _hasBreathingIssues = value);
              }),
              _buildEditableYesNoRow('Doctor Noted Heart Trouble', _hasDoctorNoteHeartTrouble, (value) {
                setState(() => _hasDoctorNoteHeartTrouble = value);
              }),
              _buildEditableYesNoRow('Has Angina Pectoris', _hasAnginaPectoris, (value) {
                setState(() => _hasAnginaPectoris = value);
              }),
              _buildEditableYesNoRow('Has Heart Palpitations', _hasHeartPalpitations, (value) {
                setState(() => _hasHeartPalpitations = value);
              }),
              _buildEditableYesNoRow('Has Had Heart Attack', _hasHeartAttack, (value) {
                setState(() => _hasHeartAttack = value);
              }),
              _buildEditableYesNoRow('Has Diabetes/High Blood Pressure', _hasDiabetesOrHighBloodPressure, (value) {
                setState(() => _hasDiabetesOrHighBloodPressure = value);
              }),
              _buildEditableYesNoRow('Family History of Heart Disease', _hasHeartDiseaseInFamily, (value) {
                setState(() => _hasHeartDiseaseInFamily = value);
              }),
              _buildEditableYesNoRow('Takes Cholesterol Medication', _hasCholesterolMedication, (value) {
                setState(() => _hasCholesterolMedication = value);
              }),
              _buildEditableYesNoRow('Takes Heart Medication', _hasHeartMedication, (value) {
                setState(() => _hasHeartMedication = value);
              }),
            ],
            icon: Icons.favorite,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Lifestyle Health Factors',
            [
              _buildEditableYesNoRow('Sleeps Well', _sleepsWell, (value) {
                setState(() => _sleepsWell = value);
              }),
              _buildEditableYesNoRow('Drinks Daily', _drinksDailyAlcohol, (value) {
                setState(() => _drinksDailyAlcohol = value);
              }),
              _buildEditableYesNoRow('Smokes Cigarettes', _smokescigarettes, (value) {
                setState(() => _smokescigarettes = value);
              }),
              _buildEditableYesNoRow('Has Physical Condition', _hasPhysicalCondition, (value) {
                setState(() => _hasPhysicalCondition = value);
              }),
              _buildEditableYesNoRow('Has Joint/Muscle Problems', _hasJointOrMuscleProblems, (value) {
                setState(() => _hasJointOrMuscleProblems = value);
              }),
              _buildEditableYesNoRow('Is Pregnant', _isPregnant, (value) {
                setState(() => _isPregnant = value);
              }),
            ],
            icon: Icons.nightlight,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Additional Medical Information',
            [
              _buildEditableRow(
                'Additional Details',
                _additionalMedicalInfoController,
                maxLines: 3,
              ),
            ],
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Exercise & Goals',
            [
              _buildEditableRow('Exercise Frequency', _exerciseFrequencyController),
              _buildEditableRow('Health Goals', _healthGoalsController, maxLines: 3),
              _buildEditableRow('Stress Level', _stressLevelController),
              _buildEditableRow('Best Life Point', _bestLifePointController),
            ],
            icon: Icons.fitness_center,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Medications',
            [
              _buildEditableRow('Current Medications', _medicationsController, maxLines: 2),
            ],
            icon: Icons.medication,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Dietary Information',
            [
              _buildEditableRow('Eating Habits', _eatingHabitsController),
              _buildReadOnlyRow(
                'Foods Eaten Regularly',
                _regularFoods.isNotEmpty ? _regularFoods.join(', ') : 'None specified',
              ),
            ],
            icon: Icons.restaurant,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Typical Diet',
            [
              _buildEditableRow('Breakfast', _typicalBreakfastController),
              _buildEditableRow('Lunch', _typicalLunchController),
              _buildEditableRow('Dinner', _typicalDinnerController),
              _buildEditableRow('Snacks', _typicalSnacksController),
            ],
            icon: Icons.fastfood,
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Fitness Self-Assessment',
            [
              _buildEditableRatingRow('Cardio-Respiratory', _cardioRespiratoryRating, (value) {
                setState(() => _cardioRespiratoryRating = value);
              }),
              _buildEditableRatingRow('Strength', _strengthRating, (value) {
                setState(() => _strengthRating = value);
              }),
              _buildEditableRatingRow('Endurance', _enduranceRating, (value) {
                setState(() => _enduranceRating = value);
              }),
              _buildEditableRatingRow('Flexibility', _flexibilityRating, (value) {
                setState(() => _flexibilityRating = value);
              }),
              _buildEditableRatingRow('Power', _powerRating, (value) {
                setState(() => _powerRating = value);
              }),
              _buildEditableRatingRow('Body Composition', _bodyCompositionRating, (value) {
                setState(() => _bodyCompositionRating = value);
              }),
              _buildEditableRatingRow('Self Image', _selfImageRating, (value) {
                setState(() => _selfImageRating = value);
              }),
            ],
            icon: Icons.assessment,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Additional Notes',
            [
              _buildEditableRow('Notes', _additionalNotesController, maxLines: 4),
            ],
            icon: Icons.note,
          ),
        ],
      ),
    );
  }

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

  Widget _buildReadOnlyRow(String label, String value) {
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

  Widget _buildEditableRow(String label, TextEditingController controller, {int maxLines = 1}) {
    if (!_isEditing) {
      return _buildReadOnlyRow(label, controller.text.isEmpty ? 'Not provided' : controller.text);
    }

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
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppStyles.primarySage, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableYesNoRow(String label, bool? value, Function(bool?) onChanged) {
    if (!_isEditing) {
      // Display read-only version
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
            value == null
                ? const Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: Text(
                      'Not provided',
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
                      color: value ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: value ? Colors.red.shade300 : Colors.green.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          value ? Icons.cancel : Icons.check_circle,
                          size: 16,
                          color: value ? Colors.red : Colors.green,
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

    // Editable version
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: YesNoQuestion(
        question: label,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildEditableRatingRow(String label, int rating, Function(int) onChanged) {
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
          if (_isEditing)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: rating.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: AppStyles.primarySage,
                  label: rating.toString(),
                  onChanged: (value) => onChanged(value.round()),
                ),
                const SizedBox(height: 8),
              ],
            ),
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
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: rating / 10,
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

  String _cmToFeetInches(double cm) {
    double totalInches = cm / 2.54;
    int feet = (totalInches / 12).floor();
    int inches = (totalInches % 12).round();
    return '$feet ft $inches in';
  }

  double _kgToLbs(double kg) {
    return kg * 2.20462;
  }
}

