import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../theme/app_styles.dart';
import '../widgets/merge_button.dart';
import '../main.dart';
import 'home_screen.dart';
import 'onboarding_quiz_screen.dart';
import 'trainer/trainer_onboarding_screen.dart';
import 'trainer/email_verification_screen.dart';
import 'client/client_email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLogin = true; // Toggle between login and signup
  String? _errorMessage;
  
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Validate email format
  bool _isEmailValid(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Handle login
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Dismiss keyboard before proceeding
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      // Navigate to main app on success - let AuthWrapper handle routing
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException during login: ${e.code} - ${e.message}");
      
      // Show a user-friendly error message
      setState(() {
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
          _errorMessage = 'Incorrect login information. Please check your email and password.';
        } else {
          _errorMessage = e.message ?? 'An authentication error occurred';
        }
      });
    } catch (e) {
      print("General exception during login: $e");
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Handle signup with role
  Future<void> _handleSignup(UserRole role) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Dismiss keyboard before proceeding
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Signup - Debug output
      print("Starting user creation...");
      
      try {
        // Create the user account with appropriate role
        final UserCredential userCredential = await _authService.createUserWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
          role: role,
        );
        
        print("User created successfully: ${userCredential.user?.uid}");
        
        // Navigate to the appropriate onboarding screen based on role
        if (mounted && userCredential.user != null) {
          if (role == UserRole.trainer) {
            print("Navigating to trainer email verification...");
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => TrainerEmailVerificationScreen(
                  user: userCredential.user!,
                ),
              ),
            );
          } else {
            print("Navigating to client email verification...");
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ClientEmailVerificationScreen(
                  user: userCredential.user!,
                ),
              ),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        print("FirebaseAuthException during signup: ${e.code} - ${e.message}");
        if (e.code == 'email-already-in-use') {
          setState(() {
            _errorMessage = 'Email is already in use. Please use a different email or try logging in.';
          });
        } else {
          throw e; // Re-throw to be caught by the outer catch block
        }
        return; // Return here to prevent the re-thrown exception from being caught
      } catch (signupError) {
        print("Other error during signup: $signupError");
        throw signupError; // Re-throw to be caught by the outer catch block
      }
    } on FirebaseAuthException catch (e) {
      print("Outer FirebaseAuthException: ${e.code} - ${e.message}");
      
      // Show a user-friendly error message
      setState(() {
        if (e.code == 'email-already-in-use') {
          _errorMessage = 'Email is already in use. Please use a different email or try logging in.';
        } else {
          _errorMessage = e.message ?? 'An authentication error occurred';
        }
      });
    } catch (e) {
      print("Outer general exception during auth: $e");
      setState(() {
        // Check if the error message contains "email-already-in-use"
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('email-already-in-use') || errorStr.contains('email is already in use')) {
          _errorMessage = 'Email is already in use. Please use a different email or try logging in.';
        } else {
          _errorMessage = 'An error occurred. Please try again.';
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Toggle between login and signup
  void _toggleAuthMode() {
    // Dismiss keyboard when switching modes
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
    });
  }

  // Handle trainer signup with access code verification
  Future<void> _handleTrainerSignup() async {
    // First show the access code dialog
    final isVerified = await _showTrainerAccessCodeDialog();
    
    if (isVerified) {
      // If access code is verified, proceed with trainer signup
      await _handleSignup(UserRole.trainer);
    }
  }

  // Show dialog for trainer access code
  Future<bool> _showTrainerAccessCodeDialog() async {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.security, color: AppStyles.primarySage, size: 24),
            const SizedBox(width: 12),
            const Text('Trainer Access Required'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please enter the trainer access code to continue. This helps us ensure only authorized trainers can register on our platform.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.light
                    ? AppStyles.textDark.withOpacity(0.8)
                    : AppStyles.textLight.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Access Code',
                  hintText: 'Enter trainer access code',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppStyles.slateGray.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppStyles.slateGray.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppStyles.primarySage,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.shade50
                    : AppStyles.lightCharcoal,
                  prefixIcon: Icon(
                    Icons.vpn_key,
                    color: AppStyles.mutedBlue,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the access code';
                  }
                  if (value != 'bj-and-dj') {
                    return 'Invalid access code';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop(false);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppStyles.slateGray,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.primarySage,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Verify'),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
    
    return result == true;
  }

  // Handle forgot password
  Future<void> _handleForgotPassword() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // Check if email is valid
    final email = _emailController.text.trim();
    if (email.isEmpty || !_isEmailValid(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Show confirmation dialog
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('We will send a password reset link to $email. Do you want to proceed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
    
    if (shouldProceed != true) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _authService.sendPasswordResetEmail(email);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to send password reset email'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo and app name
                Column(
                  children: [
                    // MERGE Logo
                    Container(
                      width: 180,
                      height: 180,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppStyles.slateGray.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/mergelogo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // App name - using the theme color
                    Text(
                      'Welcome to Merge!',
                      style: TextStyle(
                        fontSize: 28,
                        color: AppStyles.primarySage,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Tagline - Updated for a more calming feel
                    Text(
                      'Harmonize Your Health Journey',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppStyles.slateGray,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
                
                // Login/Signup form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Form title
                      Text(
                        _isLogin ? 'Log In' : 'Create Account',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      // Email field
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: AppStyles.mutedBlue,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppStyles.slateGray.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppStyles.slateGray.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppStyles.primarySage,
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.light
                              ? Colors.grey.shade50
                              : AppStyles.lightCharcoal,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!_isEmailValid(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: AppStyles.mutedBlue,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppStyles.slateGray.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppStyles.slateGray.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppStyles.primarySage,
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.light
                              ? Colors.grey.shade50
                              : AppStyles.lightCharcoal,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        obscureText: true,
                        textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (!_isLogin && value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (_isLogin) {
                            _handleLogin();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Confirm Password field (signup only)
                      if (!_isLogin)
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(
                              Icons.check_circle_outline,
                              color: AppStyles.mutedBlue,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppStyles.slateGray.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppStyles.slateGray.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppStyles.primarySage,
                                width: 1.5,
                              ),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey.shade50
                                : AppStyles.lightCharcoal,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            // In signup mode, we now have two separate buttons
                            // so no automatic submission on field submit
                          },
                        ),
                      
                      // Spacing
                      SizedBox(height: _isLogin ? 8 : 16),
                      
                      // Forgot password
                      if (_isLogin)
                        Align(
                          alignment: Alignment.center,
                          child: MergeButton(
                            text: 'Forgot Password?',
                            onPressed: _handleForgotPassword,
                            type: MergeButtonType.text,
                            size: MergeButtonSize.small,
                            color: AppStyles.mutedBlue,
                          ),
                        ),
                      const SizedBox(height: 8),
                      
                      // Login button or Signup buttons
                      if (_isLogin) ...[
                        // Single login button
                        MergeButton(
                          text: 'Log In',
                          onPressed: _isLoading ? null : _handleLogin,
                          isLoading: _isLoading,
                          fullWidth: true,
                          type: MergeButtonType.primary,
                          size: MergeButtonSize.medium,
                        ),
                      ] else ...[
                        // Two signup buttons: Client and Trainer
                        MergeButton(
                          text: 'Sign Up as Client',
                          icon: Icons.person,
                          onPressed: _isLoading ? null : () => _handleSignup(UserRole.client),
                          isLoading: _isLoading,
                          fullWidth: true,
                          type: MergeButtonType.primary,
                          size: MergeButtonSize.medium,
                          color: AppStyles.primarySage,
                        ),
                        const SizedBox(height: 12),
                        MergeButton(
                          text: 'Sign Up as Trainer',
                          icon: Icons.fitness_center,
                          onPressed: _isLoading ? null : _handleTrainerSignup,
                          isLoading: _isLoading,
                          fullWidth: true,
                          type: MergeButtonType.outline,
                          size: MergeButtonSize.medium,
                          color: AppStyles.mutedBlue,
                        ),
                      ],
                      const SizedBox(height: 16),
                      
                      // Error message (moved after login button)
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppStyles.errorRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppStyles.errorRed.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AppStyles.errorRed,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: AppStyles.errorRed.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ),
                      const SizedBox(height: 16),
                      ],
                      
                      // Toggle auth mode (always visible)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLogin
                                ? "Don't have an account? "
                                : 'Already have an account? ',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.light
                                ? AppStyles.textDark.withOpacity(0.7)
                                : AppStyles.textLight.withOpacity(0.7),
                            ),
                          ),
                          MergeButton(
                            text: _isLogin ? 'Sign Up' : 'Log In',
                            onPressed: _toggleAuthMode,
                            type: MergeButtonType.text,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 