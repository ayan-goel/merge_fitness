import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/session_package_model.dart';
import '../../models/payment_history_model.dart';
import '../../services/payment_service.dart';
import '../../theme/app_styles.dart';

class ClientPaymentTab extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String trainerId;

  const ClientPaymentTab({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.trainerId,
  });

  @override
  State<ClientPaymentTab> createState() => _ClientPaymentTabState();
}

class _ClientPaymentTabState extends State<ClientPaymentTab> {
  final PaymentService _paymentService = PaymentService();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _adjustmentController = TextEditingController();
  bool _isLoading = false;
  SessionPackage? _sessionPackage;

  @override
  void initState() {
    super.initState();
    _loadSessionPackage();
  }

  @override
  void dispose() {
    _costController.dispose();
    _adjustmentController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionPackage() async {
    setState(() => _isLoading = true);
    try {
      final package = await _paymentService.getSessionPackage(
        widget.clientId,
        widget.trainerId,
      );
      setState(() {
        _sessionPackage = package;
        if (package != null) {
          _costController.text = package.costPerTenSessions.toStringAsFixed(2);
        }
      });
    } catch (e) {
      print('Error loading session package: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateCost() async {
    if (_costController.text.isEmpty) return;

    final cost = double.tryParse(_costController.text);
    if (cost == null || cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid cost')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _paymentService.createOrUpdateSessionPackage(
        clientId: widget.clientId,
        trainerId: widget.trainerId,
        costPerTenSessions: cost,
      );
      await _loadSessionPackage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cost updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating cost: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAdjustSessionsDialog() {
    _adjustmentController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Sessions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current sessions: ${_sessionPackage?.sessionsRemaining ?? 0}'),
            const SizedBox(height: 16),
            TextField(
              controller: _adjustmentController,
              keyboardType: TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Adjustment (+/-)',
                hintText: 'e.g., +5 or -2',
                border: OutlineInputBorder(),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^[+-]?\d*')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final adjustmentText = _adjustmentController.text;
              if (adjustmentText.isEmpty) return;

              int? adjustment = int.tryParse(adjustmentText);
              if (adjustment == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number')),
                );
                return;
              }

              Navigator.pop(context);

              setState(() => _isLoading = true);
              try {
                final success = await _paymentService.adjustSessions(
                  clientId: widget.clientId,
                  trainerId: widget.trainerId,
                  sessionChange: adjustment,
                );

                if (success) {
                  await _loadSessionPackage();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sessions adjusted successfully')),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error adjusting sessions')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              } finally {
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppStyles.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session package info
          Container(
            decoration: AppStyles.cardDecoration,
            padding: AppStyles.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppStyles.primarySage.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: AppStyles.primarySage,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Session Package',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppStyles.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppStyles.textDark,
                        ),
                        decoration: AppStyles.inputDecoration(
                          labelText: 'Cost for 10 Sessions (\$)',
                          prefixIcon: const Icon(
                            Icons.attach_money,
                            color: AppStyles.primarySage,
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updateCost,
                      style: AppStyles.primaryButtonStyle,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Update'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_sessionPackage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppStyles.primarySage.withOpacity(0.05),
                      borderRadius: AppStyles.defaultBorderRadius,
                      border: Border.all(
                        color: AppStyles.primarySage.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sessions Remaining',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppStyles.slateGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_sessionPackage!.sessionsRemaining}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppStyles.primarySage,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _showAdjustSessionsDialog,
                          style: AppStyles.secondaryButtonStyle.copyWith(
                            backgroundColor: MaterialStateProperty.all(Colors.transparent),
                          ),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Adjust'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Payment history
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppStyles.mutedBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history,
                  color: AppStyles.mutedBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Payment History',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppStyles.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<PaymentHistory>>(
              stream: _paymentService.getPaymentHistory(
                widget.clientId,
                widget.trainerId,
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
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: AppStyles.cardDecoration,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppStyles.slateGray.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: AppStyles.slateGray,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No payment history yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppStyles.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Payment history will appear here after purchases',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppStyles.slateGray,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: payments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    final statusColor = payment.status == 'completed'
                        ? AppStyles.successGreen
                        : payment.status == 'pending'
                            ? AppStyles.warningAmber
                            : AppStyles.errorRed;
                    
                    return Container(
                      decoration: AppStyles.cardDecoration,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Icon(
                              payment.status == 'completed'
                                  ? Icons.check_circle_outline
                                  : payment.status == 'pending'
                                      ? Icons.schedule
                                      : Icons.error_outline,
                              color: statusColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '\$${payment.amount.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppStyles.textDark,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: statusColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        payment.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${payment.sessionsPurchased} sessions purchased',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppStyles.slateGray,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('MMM dd, yyyy - hh:mm a').format(payment.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppStyles.slateGray.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 