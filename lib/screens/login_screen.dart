import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'onboarding_quiz_screen.dart';
import 'trainer/trainer_onboarding_screen.dart';
import 'trainer/email_verification_screen.dart';

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
  bool _isTrainer = false; // Toggle for trainer account
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

  // Handle login/signup
  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        // Login
        await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        // Navigate to home on success
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        // Signup - Debug output
        print("Starting user creation...");
        
        try {
          // Create the user account with appropriate role
          final UserRole role = _isTrainer ? UserRole.trainer : UserRole.client;
          final UserCredential userCredential = await _authService.createUserWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
            role: role,
          );
          
          print("User created successfully: ${userCredential.user?.uid}");
          
          // Navigate to the appropriate onboarding screen based on role
          if (mounted && userCredential.user != null) {
            if (_isTrainer) {
              print("Navigating to trainer email verification...");
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => TrainerEmailVerificationScreen(
                    user: userCredential.user!,
                  ),
                ),
              );
            } else {
              print("Navigating to client onboarding quiz...");
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const OnboardingQuizScreen()),
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
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
      if (_isLogin) {
        _isTrainer = false; // Reset trainer toggle when switching to login
      }
    });
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
                    // Logo placeholder
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // App name
                    Text(
                      'Merge Fitness',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Tagline
                    Text(
                      'Your personal fitness companion',
                      style: Theme.of(context).textTheme.bodyLarge,
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
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
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
                            _handleAuth();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Confirm Password field (signup only)
                      if (!_isLogin)
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(Icons.check_circle_outline),
                            border: OutlineInputBorder(),
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
                          onFieldSubmitted: (_) => _handleAuth(),
                        ),
                      
                      // Trainer toggle (signup only)
                      if (!_isLogin) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Switch(
                              value: _isTrainer,
                              onChanged: (value) {
                                setState(() {
                                  _isTrainer = value;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isTrainer ? 'Register as a Trainer' : 'Register as a Client',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                      
                      // Spacing
                      SizedBox(height: _isLogin ? 8 : 16),
                      
                      // Forgot password
                      if (_isLogin)
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: () {
                              // Handle forgot password
                            },
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      
                      // Error message
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.red.withOpacity(0.1),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      if (_errorMessage != null)
                        const SizedBox(height: 16),
                      
                      // Login/Signup button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleAuth,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isLogin ? 'Log In' : 'Sign Up'),
                      ),
                      const SizedBox(height: 16),
                      
                      // Toggle auth mode
                      TextButton(
                        onPressed: _toggleAuthMode,
                        child: Text(
                          _isLogin
                              ? 'Don\'t have an account? Sign Up'
                              : 'Already have an account? Log In',
                        ),
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