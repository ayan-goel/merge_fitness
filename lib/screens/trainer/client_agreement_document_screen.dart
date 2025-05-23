import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/onboarding_form_model.dart';
import '../../theme/app_styles.dart';

class ClientAgreementDocumentScreen extends StatelessWidget {
  final OnboardingFormModel onboardingForm;
  final String clientName;

  const ClientAgreementDocumentScreen({
    super.key,
    required this.onboardingForm,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Agreement'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDocumentHeader(),
                _buildAgreementContent(),
                _buildAcknowledgementCard(),
                _buildSignatureCard(),
                _buildDocumentFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentHeader() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/merge.png', 
                height: 60,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.fitness_center, size: 60, color: AppStyles.primarySage);
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'MERGE Health Fitness & Nutrition, Inc.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Client Services Agreement & Informed Consent',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppStyles.primarySage,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                width: 120,
                height: 2,
                color: AppStyles.primarySage,
              ),
            ],
          ),
        ),
        
        // Client info card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Client Name',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      onboardingForm.clientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Agreement Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      onboardingForm.signatureTimestamp ?? 'Not signed',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgreementContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AGREEMENT TERMS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppStyles.primarySage,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(thickness: 1),
          const SizedBox(height: 12),
          _buildContractSection('GENERAL STATEMENT OF PROGRAM OBJECTIVES & PROCEDURES:', 
            'Over the upcoming weeks, the Client will learn ways to achieve a healthier lifestyle and diet '
            'through improved health, fitness and nutrition. The Client understands that this physical '
            'fitness program includes exercises to build the cardio respiratory system (heart and lungs), the '
            'musculoskeletal system (muscle endurance and strength, and flexibility), and to improve body '
            'composition (decrease of body fat in individuals needing to lose fat, with an increase in weight of '
            'muscle and bone). Exercise may include aerobic activities, callisthenic exercises, and weight '
            'lifting to improve muscular strength, and endurance and flexibility exercises to improve joint '
            'range of motion.\n\n'
            'The Client has chosen to work with the health professionals at MERGE and understands that the '
            'information received should not be seen as medical or nursing advice and is not meant to take '
            'the place of seeing licensed health professionals. The Client hereby fully and forever release and '
            'discharge MERGE, its assigns and agents from all claims, demands, damages, rights of action, '
            'present and future therein.'
          ),
          
          _buildContractSection('DESCRIPTION OF POTENTIAL RISKS:', 
            'The Client understands and acknowledges there are inherent risks in participating in any exercise program. ' 
            'The Client understands that sensations of fatigue, discomfort, and pain may be experienced during physical '
            'activity. The Client also recognizes that strains, tears, bone injuries, and other serious injuries are '
            'possible. During exercise, the heart works harder to pump oxygen-carrying blood to the muscles, and the '
            'Client understands there is a risk that the heart may not be able to respond properly causing death, stroke, heart '
            'attack or other serious outcomes. The Client further understands that there is risk of abnormal changes in '
            'blood pressure or heart rhythm during exercise.\n\n'
            'The Client has discussed with their physician and with MERGE health professionals any exercise limitations '
            'and understands the recommendation to seek medical clearance before beginning an exercise program. '
            'MERGE recommends that all Clients seek medical clearance prior to beginning an exercise program. '
            'The Client will immediately stop exercising and inform MERGE if the Client feels faint, dizzy, or uncomfortable.'
          ),
          
          _buildContractSection('DESCRIPTION OF POTENTIAL BENEFITS:', 
            'The Client understands that a regular exercise program has been shown to produce improvements in '
            'aerobic power, endurance, body composition, muscle strength, and muscle endurance while reducing risks '
            'for certain diseases. The degree of improvement as well as the time needed to achieve benefits varies '
            'greatly among participants, and the Client understands there is no guarantee that these changes will '
            'occur and recognizes his or her responsibility to engage wholeheartedly in the program to maximize '
            'benefits. The Client will report any health changes or abnormal responses to the exercise professional '
            'immediately.'
          ),
          
          _buildContractSection('CONFIDENTIALITY AND USE OF INFORMATION:', 
            "The Client acknowledges that program information may be used by MERGE for program evaluation, for "
            "research, for reports, or for education without disclosing the Client's identity. The Client agrees to the use of "
            "photographs, videos, and written feedback for use by MERGE for promotional purposes so long as the Client's "
            "identity is not shared without explicit permission. The Client understands that MERGE employees, "
            "representatives, and agents will respect privacy and confidentiality, and will not share Client's private "
            "health information with third parties unless legally required."
          ),
        ],
      ),
    );
  }

  Widget _buildContractSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppStyles.primarySage,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcknowledgementCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACKNOWLEDGMENT',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppStyles.primarySage,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(thickness: 1),
          const SizedBox(height: 12),
          const Text(
            'By signing below, I acknowledge that:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '(1) I have received a copy of this agreement\n'
            '(2) I have had an opportunity to discuss the contents with a health professional at MERGE and, if desired, to have it reviewed by an attorney\n'
            '(3) I understand, accept and agree to abide by the terms hereof',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSignatureCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SIGNATURE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppStyles.primarySage,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(thickness: 1),
          const SizedBox(height: 12),
          // Signature section
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Client Signature:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            onboardingForm.clientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date Signed:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        onboardingForm.signatureTimestamp ?? 'Not signed',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
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

  Widget _buildDocumentFooter() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'MERGE Health Fitness & Nutrition, Inc. - Legal Document',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Document Generated: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
} 