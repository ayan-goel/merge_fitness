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
            'MERGE Health Fitness & Nutrition, Inc.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Informed Consent Agreement',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
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
            'present and future therein. The Client understands and warrants, releases and agrees that '
            'he/she is in good physical condition and has no disability, impairment or ailment that prevents '
            'from engaging in active or passive exercise that will be detrimental to heart, safety, or comfort, '
            'or physical condition (other than those items fully discussed on health history form). The client '
            'releases MERGE from any and all liability, damages, causes of action, allegations, suits, sums of '
            'money, claims and demands whatsoever, in law or equity, which the Client ever had, now has or '
            'will have in the future against MERGE, arising from the Client\\\'s past or future participation in, '
            'or otherwise with respect to, the Program, unless arising from the gross negligence of MERGE.'
          ),
          
          _buildContractSection('DESCRIPTION OF POTENTIAL RISKS & DISCLAIMER:', 
            'Personal Training & Boot Camp: The Client understands that Merge Health Fitness & '
            'Nutrition, Inc. (MERGE) shall not be liable for any damages arising from personal injuries '
            'sustained by client while and during the personal training program. Clients using the exercise '
            'equipment during the personal training program do so at his/her own risk. Clients assume full '
            'responsibility for any injuries or damages which may occur during the training. The Client states '
            'that he/she has had a recent physical checkup and has the permission from a personal physician '
            'to engage in aerobic and/or anaerobic conditioning.\n\n'
            'Health Coaching & Nutrition: The Client understands that the role of the health '
            'professional is not to prescribe or assess micro- and macronutrient levels; provide health care, '
            'medical or nutrition therapy services; or to diagnose, treat or cure any disease, condition or '
            'other physical or mental ailment of the human body. The Client understands that the health '
            'professional is not acting in the capacity of a doctor, licensed dietician-nutritionist, or '
            'psychologist and that any advice given is not meant to take the place of advice by these '
            'professionals. If the Client is under the care of a health care professional or currently uses '
            'prescription medications, the Client should discuss any dietary changes or supplements use with '
            'his or her doctor, and should not discontinue any prescription medications without first '
            'consulting his or her doctor.'
          ),
          
          _buildContractSection('POLICIES',
            'Cancellation Policy: If you must cancel, please do so within 24 hours so that we can fill your '
            'spot with another client. If you do not cancel within 24 hours, you will be charged the regular '
            'rate. Sessions must be rescheduled within the same month, as long as the trainer has '
            'availability, otherwise the session will be forfeited.\n\n'
            'Confidentiality: MERGE will keep the Client\\\'s information private, and will not share the '
            'Client\\\'s information to any third party unless compelled to by law.\n\n'
            'Payment: Payment is accepted by cash, check or credit card and is due at the 1st of every month '
            'unless otherwise noted.'
          ),
          
          _buildContractSection('ARBITRATION, CHOICE OF LAW, AND LIMITED REMEDIES',
            'In the event that there ever arises a dispute between a health professional at MERGE and Client '
            'with respect to the services provided pursuant to this agreement or otherwise pertaining to the '
            'relationship between the parties, the parties agree to submit to binding arbitration before the '
            'American Arbitration Association (Commercial Arbitration and Mediation Center for the '
            'Americas Mediation and Arbitration Rules). Any judgment on the award rendered by the '
            'arbitrator(s) may be entered in any court having jurisdiction thereof. Such arbitration shall be '
            'conducted by a single arbitrator. The sole remedy that can be awarded to the Client in the event '
            'that an award is granted in arbitration is refund of the Program Fee. Without limiting the '
            'generality of the foregoing, no award of consequential or other damages, unless specifically set '
            'forth herein, may be granted to the Client.\n\n'
            'This agreement shall be construed according to the laws of the State of Georgia. In the event that '
            'any provision of this Agreement is deemed unenforceable, the remaining portions of the '
            'Agreement shall be severed and remain in full force.'
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