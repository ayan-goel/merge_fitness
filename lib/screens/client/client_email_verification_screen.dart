import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../onboarding_quiz_screen.dart';

class ClientEmailVerificationScreen extends StatefulWidget {
  final User user;
  
  const ClientEmailVerificationScreen({
    super.key,
    required this.user,
  });

  @override
  State<ClientEmailVerificationScreen> createState() => _ClientEmailVerificationScreenState();
}

class _ClientEmailVerificationScreenState extends State<ClientEmailVerificationScreen> {
  bool _isVerifying = false;
  bool _isResendingEmail = false;
  Timer? _verificationTimer;
  Timer? _cooldownTimer;
  int _resendCooldown = 0;
  int _verificationAttempts = 0;
  final int _maxVerificationAttempts = 20; // ~60 seconds of checking
  
  @override
  void initState() {
    super.initState();
    // Send verification email immediately
    _sendVerificationEmail();
    // Start timer to check verification status
    _startVerificationTimer();
  }
  
  @override
  void dispose() {
    // Cancel all timers to prevent memory leaks and setState after dispose
    _verificationTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _sendVerificationEmail() async {
    if (_isResendingEmail) return;
    
    if (!mounted) return;
    setState(() {
      _isResendingEmail = true;
    });
    
    try {
      await widget.user.sendEmailVerification();
      
      // Cancel any existing cooldown timer
      _cooldownTimer?.cancel();
      
      if (!mounted) return;
      setState(() {
        _resendCooldown = 60; // 60 seconds cooldown
      });
      
      // Create a new cooldown timer
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCooldown > 0) {
          if (mounted) {
            setState(() {
              _resendCooldown--;
            });
          }
        } else {
          timer.cancel();
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending verification email: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResendingEmail = false;
        });
      }
    }
  }
  
  void _startVerificationTimer() {
    // Check every 3 seconds if email is verified
    _verificationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) async {
        _verificationAttempts++;
        
        // Stop checking after max attempts to prevent auto-proceed without verification
        if (_verificationAttempts >= _maxVerificationAttempts) {
          timer.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please verify your email and tap "I\'ve Verified My Email" to continue.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
        
        await widget.user.reload();
        final user = FirebaseAuth.instance.currentUser;
        
        if (user != null && user.emailVerified) {
          timer.cancel();
          if (mounted) {
            // Navigate to the client onboarding quiz
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const OnboardingQuizScreen(),
              ),
            );
          }
        }
      },
    );
  }
  
  Future<void> _checkEmailVerification() async {
    if (_isVerifying) return;
    
    if (!mounted) return;
    setState(() {
      _isVerifying = true;
    });
    
    try {
      // Reload user to get latest status
      await widget.user.reload();
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null && user.emailVerified) {
        if (mounted) {
          // Navigate to the client onboarding quiz
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const OnboardingQuizScreen(),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email not verified yet. Please check your inbox.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking verification: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate remaining verification checking time
    final int remainingChecks = _maxVerificationAttempts - _verificationAttempts;
    final bool isCheckingExpired = remainingChecks <= 0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.email_outlined,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              'Verify Your Email',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'We\'ve sent a verification email to:\n${widget.user.email}',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'Please check your inbox and click the verification link in the email to complete your registration. You\'ll be able to access the onboarding questionnaire after verification.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!isCheckingExpired) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Auto-checking: ${remainingChecks * 3}s',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You must verify your email to continue. Click the verification link in your email.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            ElevatedButton(
              onPressed: _isVerifying ? null : _checkEmailVerification,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isVerifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('I\'ve Verified My Email'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _isResendingEmail || _resendCooldown > 0 
                ? null 
                : _sendVerificationEmail,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isResendingEmail
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Text(_resendCooldown > 0
                      ? 'Resend Email (${_resendCooldown}s)'
                      : 'Resend Verification Email'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: If you don\'t see the email, please check your spam or junk folder.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 