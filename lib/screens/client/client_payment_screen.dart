import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/session_package_model.dart';
import '../../models/payment_history_model.dart';
import '../../models/user_model.dart';
import '../../services/payment_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_styles.dart';

class ClientPaymentScreen extends StatefulWidget {
  const ClientPaymentScreen({super.key});

  @override
  State<ClientPaymentScreen> createState() => _ClientPaymentScreenState();
}

class _ClientPaymentScreenState extends State<ClientPaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  final AuthService _authService = AuthService();
  
  UserModel? _user;
  SessionPackage? _sessionPackage;
  bool _isLoading = true;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getUserModel();
      setState(() => _user = user);
      
      if (user.trainerId != null) {
        await _loadSessionPackage(user.uid, user.trainerId!);
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSessionPackage(String clientId, String trainerId) async {
    try {
      final package = await _paymentService.getSessionPackage(clientId, trainerId);
      setState(() => _sessionPackage = package);
    } catch (e) {
      print('Error loading session package: $e');
    }
  }

  // Stream for real-time session package updates
  Stream<SessionPackage?> _getSessionPackageStream(String clientId, String trainerId) {
    return FirebaseFirestore.instance
        .collection('sessionPackages')
        .where('clientId', isEqualTo: clientId)
        .where('trainerId', isEqualTo: trainerId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return SessionPackage.fromFirestore(snapshot.docs.first);
      }
      return null;
    });
  }

  Future<void> _purchaseSessions() async {
    if (_user?.trainerId == null || _sessionPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to process payment. Please try again.')),
      );
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      // Create payment intent
      final paymentIntent = await _paymentService.createPaymentIntent(
        clientId: _user!.uid,
        trainerId: _user!.trainerId!,
        amount: _sessionPackage!.costPerTenSessions,
        currency: 'usd',
      );

      if (paymentIntent == null) {
        throw Exception('Failed to create payment intent');
      }

      // Initialize Stripe payment sheet
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          style: ThemeMode.system,
          merchantDisplayName: 'Merge Fitness',
        ),
      );

      // Present payment sheet
      await stripe.Stripe.instance.presentPaymentSheet();

      // Payment successful - confirm and add sessions
      final success = await _paymentService.confirmPaymentAndAddSessions(
        clientId: _user!.uid,
        trainerId: _user!.trainerId!,
        paymentIntentId: paymentIntent['id'],
        amount: _sessionPackage!.costPerTenSessions,
      );

      if (success) {
        await _loadSessionPackage(_user!.uid, _user!.trainerId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment successful! 10 sessions added.')),
          );
        }
      } else {
        throw Exception('Failed to confirm payment');
      }
    } catch (e) {
      if (mounted) {
        // Check if the error is a cancellation
        String errorMessage = 'Payment cancelled';
        
        if (e is stripe.StripeException) {
          final stripeError = e.error;
          // Check if it's a cancellation
          if (stripeError.code == stripe.FailureCode.Canceled) {
            errorMessage = 'Payment cancelled';
          } else {
            // Other Stripe errors
            errorMessage = 'Payment failed. Please try again.';
          }
        } else if (e.toString().toLowerCase().contains('cancel')) {
          errorMessage = 'Payment cancelled';
        } else {
          errorMessage = 'Payment failed. Please try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      setState(() => _isProcessingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user?.trainerId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No trainer assigned',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'You need to be assigned to a trainer to purchase sessions.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment & Sessions'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sessions remaining card - now with real-time updates
            StreamBuilder<SessionPackage?>(
              stream: _user?.trainerId != null 
                  ? _getSessionPackageStream(_user!.uid, _user!.trainerId!)
                  : null,
              builder: (context, snapshot) {
                final currentPackage = snapshot.data ?? _sessionPackage;
                
                return Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.fitness_center,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Your Sessions',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sessions Remaining',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${currentPackage?.sessionsRemaining ?? 0}',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (currentPackage != null)
                              Expanded(
                                flex: 3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '\$${currentPackage.costPerTenSessions.toStringAsFixed(2)}/10',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),

            // Purchase sessions button - updated to use real-time data
            StreamBuilder<SessionPackage?>(
              stream: _user?.trainerId != null 
                  ? _getSessionPackageStream(_user!.uid, _user!.trainerId!)
                  : null,
              builder: (context, snapshot) {
                final currentPackage = snapshot.data ?? _sessionPackage;
                
                if (currentPackage == null) return const SizedBox.shrink();
                
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessingPayment ? null : () {
                          // Update _sessionPackage before purchasing
                          _sessionPackage = currentPackage;
                          _purchaseSessions();
                        },
                        icon: _isProcessingPayment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.payment),
                        label: Text(
                          _isProcessingPayment
                              ? 'Processing...'
                              : 'Purchase 10 Sessions - \$${currentPackage.costPerTenSessions.toStringAsFixed(2)}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // Payment history
            Text(
              'Payment History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Expanded(
              child: _user?.trainerId != null
                  ? StreamBuilder<List<PaymentHistory>>(
                      stream: _paymentService.getPaymentHistory(
                        _user!.uid,
                        _user!.trainerId!,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        final payments = snapshot.data ?? [];

                        if (payments.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No payment history yet',
                                  style: TextStyle(fontSize: 16),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Your payment history will appear here after your first purchase.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: payments.length,
                          itemBuilder: (context, index) {
                            final payment = payments[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: payment.status == 'completed'
                                      ? Colors.green
                                      : payment.status == 'pending'
                                          ? Colors.orange
                                          : Colors.red,
                                  child: Icon(
                                    payment.status == 'completed'
                                        ? Icons.check
                                        : payment.status == 'pending'
                                            ? Icons.pending
                                            : Icons.error,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  '\$${payment.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${payment.sessionsPurchased} sessions purchased'),
                                    Text(
                                      DateFormat('MMM dd, yyyy - hh:mm a')
                                          .format(payment.createdAt),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: payment.status == 'completed'
                                        ? Colors.green.withOpacity(0.1)
                                        : payment.status == 'pending'
                                            ? Colors.orange.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    payment.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: payment.status == 'completed'
                                          ? Colors.green.shade700
                                          : payment.status == 'pending'
                                              ? Colors.orange.shade700
                                              : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
} 