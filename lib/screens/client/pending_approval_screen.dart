import 'package:flutter/material.dart';
import '../../theme/app_styles.dart';
import '../../services/auth_service.dart';

class PendingApprovalScreen extends StatelessWidget {
  final String status; // 'pending' or 'rejected'
  final String? rejectionReason; // Reason for rejection if status is 'rejected'

  const PendingApprovalScreen({
    super.key, 
    required this.status,
    this.rejectionReason,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending';
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isPending 
                      ? AppStyles.warningAmber.withOpacity(0.1)
                      : AppStyles.errorRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPending ? Icons.hourglass_empty : Icons.cancel_outlined,
                  size: 64,
                  color: isPending ? AppStyles.warningAmber : AppStyles.errorRed,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                isPending 
                    ? 'Account Pending Approval'
                    : 'Account Not Approved',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Message
              Text(
                isPending
                    ? 'Thank you for completing your registration! Your account is currently being reviewed by our team. You will receive a notification once your account has been approved and you can start using the app.'
                    : 'Unfortunately, your account application was not approved at this time. If you believe this was a mistake, please contact us at bj@mergeintohealth.com for assistance.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppStyles.slateGray,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isPending 
                      ? AppStyles.warningAmber.withOpacity(0.1)
                      : AppStyles.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPending 
                        ? AppStyles.warningAmber.withOpacity(0.3)
                        : AppStyles.errorRed.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPending ? Icons.schedule : Icons.info_outline,
                          color: isPending ? AppStyles.warningAmber : AppStyles.errorRed,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPending ? 'What happens next?' : 'Reason for Account Rejection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isPending ? AppStyles.warningAmber : AppStyles.errorRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isPending
                            ? 'Our team typically reviews new applications within 24-48 hours. You\'ll receive a notification once your account is approved.'
                            : rejectionReason ?? 'If you have questions about your application status or believe there was an error, please reach out to our support team.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppStyles.textDark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _signOut(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppStyles.slateGray,
                        side: BorderSide(color: AppStyles.slateGray.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Footer
              Text(
                'Merge Fitness',
                style: TextStyle(
                  fontSize: 14,
                  color: AppStyles.slateGray.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
    }
  }
} 