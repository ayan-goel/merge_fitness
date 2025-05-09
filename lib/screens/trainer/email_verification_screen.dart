import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trainer_onboarding_screen.dart';

class TrainerEmailVerificationScreen extends StatefulWidget {
  final User user;
  
  const TrainerEmailVerificationScreen({
    super.key,
    required this.user,
  });

  @override
  State<TrainerEmailVerificationScreen> createState() => _TrainerEmailVerificationScreenState();
}

class _TrainerEmailVerificationScreenState extends State<TrainerEmailVerificationScreen> {
  bool _isVerifying = false;
  bool _isResendingEmail = false;
  Timer? _verificationTimer;
  Timer? _cooldownTimer;
  int _resendCooldown = 0;
  
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
        await widget.user.reload();
        final user = FirebaseAuth.instance.currentUser;
        
        if (user != null && user.emailVerified) {
          timer.cancel();
          if (mounted) {
            // Navigate to the trainer onboarding screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const TrainerOnboardingScreen(),
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
          // Navigate to the trainer onboarding screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const TrainerOnboardingScreen(),
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
              'Please check your inbox and click the verification link in the email to complete your registration.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
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
            TextButton(
              onPressed: _resendCooldown > 0 || _isResendingEmail
                  ? null
                  : _sendVerificationEmail,
              child: _resendCooldown > 0
                  ? Text('Resend Email (${_resendCooldown}s)')
                  : _isResendingEmail
                      ? const Text('Sending...')
                      : const Text('Resend Verification Email'),
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