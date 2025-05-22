import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_styles.dart';

class SignatureDialog extends StatelessWidget {
  final Function(String) onSigned;
  final String clientName;

  const SignatureDialog({
    super.key,
    required this.onSigned,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'MERGE Health Fitness & Nutrition, Inc.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
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
            
            // Contract text in scrollable container
            Container(
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      'or otherwise with respect to, the Program, unless arising from the gross negligence of MERGE.',
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
                      'consulting his or her doctor.',
                    ),
                    
                    _buildContractSection('POLICIES',
                      'Cancellation Policy: If you must cancel, please do so within 24 hours so that we can fill your '
                      'spot with another client. If you do not cancel within 24 hours, you will be charged the regular '
                      'rate. Sessions must be rescheduled within the same month, as long as the trainer has '
                      'availability, otherwise the session will be forfeited.\n\n'
                      'Confidentiality: MERGE will keep the Client\\\'s information private, and will not share the '
                      'Client\\\'s information to any third party unless compelled to by law.\n\n'
                      'Payment: Payment is accepted by cash, check or credit card and is due at the 1st of every month '
                      'unless otherwise noted.',
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
                      'Agreement shall be severed and remain in full force.',
                    ),
                    
                    const SizedBox(height: 16),
                    const Text(
                      'By signing below, I acknowledge that:\n'
                      '(1) I have received a copy of this agreement\n'
                      '(2) I have had an opportunity to discuss the contents with a health professional at MERGE and, if desired, to have it reviewed by an attorney\n'
                      '(3) I understand, accept and agree to abide by the terms hereof',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Client Signature
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppStyles.primarySage),
                const SizedBox(width: 8),
                const Text('I agree to the terms above', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Signature buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Generate signature timestamp
                    final now = DateTime.now();
                    final formattedDate = DateFormat('MMMM d, yyyy').format(now);
                    final timestamp = '$formattedDate by $clientName';
                    
                    onSigned(timestamp);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyles.primarySage,
                  ),
                  child: const Text(
                    'Sign & Accept',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
} 