import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/app_styles.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../models/payment_history_model.dart';

class FinancialAnalyticsScreen extends StatefulWidget {
  const FinancialAnalyticsScreen({super.key});

  @override
  State<FinancialAnalyticsScreen> createState() => _FinancialAnalyticsScreenState();
}

class _FinancialAnalyticsScreenState extends State<FinancialAnalyticsScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  
  // Financial data
  double _totalRevenue = 0.0;
  double _monthlyRevenue = 0.0;
  int _totalTransactions = 0;
  int _monthlyTransactions = 0;
  List<Map<String, dynamic>> _trainerEarnings = [];
  List<PaymentHistory> _recentTransactions = [];
  Map<String, double> _monthlyRevenueData = {};
  
  // Date range for chart
  DateTime _chartStartDate = DateTime.now().subtract(const Duration(days: 150)); // ~5 months ago
  DateTime _chartEndDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadRevenueData(),
        _loadTrainerEarnings(),
        _loadRecentTransactions(),
        _loadMonthlyRevenueData(),
      ]);
    } catch (e) {
      print('Error loading financial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading financial data: $e'),
            backgroundColor: AppStyles.errorRed,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRevenueData() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      // Get all payments from paymentHistory collection
      final paymentsSnapshot = await FirebaseFirestore.instance
          .collection('paymentHistory')
          .where('status', isEqualTo: 'completed')
          .get();

      double totalRevenue = 0.0;
      double monthlyRevenue = 0.0;
      int totalTransactions = paymentsSnapshot.docs.length;
      int monthlyTransactions = 0;

      for (final doc in paymentsSnapshot.docs) {
        final data = doc.data();
        final grossAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        // Calculate net amount after Stripe fees (2.9% + $0.30)
        final stripeFee = (grossAmount * 0.029) + 0.30;
        final netAmount = grossAmount - stripeFee;
        
        totalRevenue += netAmount;
        
        if (createdAt != null && createdAt.isAfter(startOfMonth)) {
          monthlyRevenue += netAmount;
          monthlyTransactions++;
        }
      }

      setState(() {
        _totalRevenue = totalRevenue;
        _monthlyRevenue = monthlyRevenue;
        _totalTransactions = totalTransactions;
        _monthlyTransactions = monthlyTransactions;
      });
    } catch (e) {
      print('Error loading revenue data: $e');
    }
  }

  Future<void> _loadTrainerEarnings() async {
    try {
      // Get all trainers
      final trainersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['trainer', 'superTrainer'])
          .get();

      List<Map<String, dynamic>> trainerEarnings = [];

      for (final trainerDoc in trainersSnapshot.docs) {
        final trainerData = trainerDoc.data();
        final trainerId = trainerDoc.id;
        final trainerName = trainerData['displayName'] ?? 
            '${trainerData['firstName'] ?? ''} ${trainerData['lastName'] ?? ''}'.trim();
        final name = trainerName.isNotEmpty ? trainerName : trainerData['email'] ?? 'Unknown';

        // Get payments for this trainer from paymentHistory collection
        final paymentsSnapshot = await FirebaseFirestore.instance
            .collection('paymentHistory')
            .where('trainerId', isEqualTo: trainerId)
            .where('status', isEqualTo: 'completed')
            .get();

        double totalEarnings = 0.0;
        double monthlyEarnings = 0.0;
        int totalSessions = 0;
        int monthlySessions = 0;
        
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);

        for (final paymentDoc in paymentsSnapshot.docs) {
          final paymentData = paymentDoc.data();
          final grossAmount = (paymentData['amount'] as num?)?.toDouble() ?? 0.0;
          final sessions = (paymentData['sessionsPurchased'] as num?)?.toInt() ?? 0;
          final createdAt = (paymentData['createdAt'] as Timestamp?)?.toDate();
          
          // Calculate net amount after Stripe fees (2.9% + $0.30)
          final stripeFee = (grossAmount * 0.029) + 0.30;
          final netAmount = grossAmount - stripeFee;
          
          totalEarnings += netAmount;
          totalSessions += sessions;
          
          if (createdAt != null && createdAt.isAfter(startOfMonth)) {
            monthlyEarnings += netAmount;
            monthlySessions += sessions;
          }
        }

        trainerEarnings.add({
          'trainerId': trainerId,
          'name': name,
          'email': trainerData['email'] ?? '',
          'role': trainerData['role'] ?? 'trainer',
          'totalEarnings': totalEarnings,
          'monthlyEarnings': monthlyEarnings,
          'totalSessions': totalSessions,
          'monthlySessions': monthlySessions,
        });
      }

      // Sort by total earnings (highest first)
      trainerEarnings.sort((a, b) => (b['totalEarnings'] as double).compareTo(a['totalEarnings'] as double));

      setState(() {
        _trainerEarnings = trainerEarnings;
      });
    } catch (e) {
      print('Error loading trainer earnings: $e');
    }
  }

  Future<void> _loadRecentTransactions() async {
    try {
      final recentSnapshot = await FirebaseFirestore.instance
          .collection('paymentHistory')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      List<PaymentHistory> transactions = [];

      for (final doc in recentSnapshot.docs) {
        try {
          final data = doc.data();
          final grossAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          
          // Calculate net amount after Stripe fees (2.9% + $0.30)
          final stripeFee = (grossAmount * 0.029) + 0.30;
          final netAmount = grossAmount - stripeFee;
          
          // Create PaymentHistory with net amount
          final payment = PaymentHistory(
            id: doc.id,
            clientId: data['clientId'] ?? '',
            trainerId: data['trainerId'] ?? '',
            sessionPackageId: data['sessionPackageId'] ?? '',
            amount: netAmount, // Use net amount instead of gross
            sessionsPurchased: data['sessionsPurchased'] ?? 0,
            stripePaymentIntentId: data['stripePaymentIntentId'] ?? '',
            status: data['status'] ?? 'pending',
            createdAt: (data['createdAt'] as Timestamp).toDate(),
          );
          
          transactions.add(payment);
        } catch (e) {
          print('Error parsing payment ${doc.id}: $e');
        }
      }
      
      setState(() {
        _recentTransactions = transactions;
      });
    } catch (e) {
      print('Error loading recent transactions: $e');
    }
  }

  Future<void> _loadMonthlyRevenueData() async {
    try {
      final now = DateTime.now();
      Map<String, double> monthlyData = {};

      // Get data for the last 6 months
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(now.year, now.month - i + 1, 1);
        final monthKey = DateFormat('MMM yyyy').format(month);

        final paymentsSnapshot = await FirebaseFirestore.instance
            .collection('paymentHistory')
            .where('status', isEqualTo: 'completed')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(month))
            .where('createdAt', isLessThan: Timestamp.fromDate(nextMonth))
            .get();

        double monthRevenue = 0.0;
        for (final doc in paymentsSnapshot.docs) {
          final data = doc.data();
          final grossAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          
          // Calculate net amount after Stripe fees (2.9% + $0.30)
          final stripeFee = (grossAmount * 0.029) + 0.30;
          final netAmount = grossAmount - stripeFee;
          
          monthRevenue += netAmount;
        }
        
        monthlyData[monthKey] = monthRevenue;
      }

      setState(() {
        _monthlyRevenueData = monthlyData;
      });
    } catch (e) {
      print('Error loading monthly revenue data: $e');
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _chartStartDate,
        end: _chartEndDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppStyles.primarySage,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppStyles.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _chartStartDate = picked.start;
        _chartEndDate = picked.end;
      });
      await _loadCustomRangeRevenueData();
    }
  }

  Future<void> _loadCustomRangeRevenueData() async {
    try {
      Map<String, double> monthlyData = {};
      
      // Generate months between start and end date
      DateTime current = DateTime(_chartStartDate.year, _chartStartDate.month, 1);
      final endMonth = DateTime(_chartEndDate.year, _chartEndDate.month, 1);
      
      while (current.isBefore(endMonth) || current.isAtSameMomentAs(endMonth)) {
        final nextMonth = DateTime(current.year, current.month + 1, 1);
        final monthKey = DateFormat('MMM yyyy').format(current);

        final paymentsSnapshot = await FirebaseFirestore.instance
            .collection('paymentHistory')
            .where('status', isEqualTo: 'completed')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(current))
            .where('createdAt', isLessThan: Timestamp.fromDate(nextMonth))
            .get();

        double monthRevenue = 0.0;
        for (final doc in paymentsSnapshot.docs) {
          final data = doc.data();
          final grossAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          
          // Calculate net amount after Stripe fees (2.9% + $0.30)
          final stripeFee = (grossAmount * 0.029) + 0.30;
          final netAmount = grossAmount - stripeFee;
          
          monthRevenue += netAmount;
        }
        
        monthlyData[monthKey] = monthRevenue;
        current = nextMonth;
      }

      setState(() {
        _monthlyRevenueData = monthlyData;
      });
    } catch (e) {
      print('Error loading custom range revenue data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analytics'),
        backgroundColor: AppStyles.offWhite,
        foregroundColor: AppStyles.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFinancialData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Revenue Overview Cards
            _buildRevenueOverview(),
            
            const SizedBox(height: 24),
            
            // Monthly Revenue Chart
            _buildMonthlyRevenueChart(),
            
            const SizedBox(height: 24),
            
            // Trainer Earnings Section
            _buildTrainerEarningsSection(),
            
            const SizedBox(height: 24),
            
            // Recent Transactions Section
            _buildRecentTransactionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppStyles.textDark,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Revenue',
                '\$${_totalRevenue.toStringAsFixed(2)}',
                Icons.attach_money,
                AppStyles.successGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Monthly Revenue',
                '\$${_monthlyRevenue.toStringAsFixed(2)}',
                Icons.trending_up,
                AppStyles.primarySage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Transactions',
                _totalTransactions.toString(),
                Icons.receipt,
                AppStyles.mutedBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Monthly Payments',
                _monthlyTransactions.toString(),
                Icons.payment,
                AppStyles.warningAmber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.slateGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyRevenueChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppStyles.primarySage.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: AppStyles.primarySage, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Monthly Revenue Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.textDark,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _selectDateRange,
                icon: Icon(Icons.date_range, size: 16, color: AppStyles.primarySage),
                label: Text(
                  'Date Range',
                  style: TextStyle(
                    color: AppStyles.primarySage,
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('MMM dd, yyyy').format(_chartStartDate)} - ${DateFormat('MMM dd, yyyy').format(_chartEndDate)}',
            style: TextStyle(
              fontSize: 12,
              color: AppStyles.slateGray,
            ),
          ),
          const SizedBox(height: 20),
          
          // Simple bar chart representation
          if (_monthlyRevenueData.isNotEmpty) ...[
            const SizedBox(height: 100),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _monthlyRevenueData.entries.map((entry) {
                final maxRevenue = _monthlyRevenueData.values.reduce((a, b) => a > b ? a : b);
                final height = maxRevenue > 0 ? (entry.value / maxRevenue) * 80 : 0.0;
                
                return Column(
                  children: [
                    Text(
                      '\$${entry.value.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppStyles.slateGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 30,
                      height: height,
                      decoration: BoxDecoration(
                        color: AppStyles.primarySage,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.key.split(' ')[0], // Show only month abbreviation (e.g., "Jan", "Feb")
                      style: TextStyle(
                        fontSize: 10,
                        color: AppStyles.slateGray,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ] else
            Center(
              child: Text(
                'No revenue data available',
                style: TextStyle(
                  color: AppStyles.slateGray,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrainerEarningsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, color: AppStyles.primarySage, size: 24),
            const SizedBox(width: 12),
            Text(
              'Revenue by Trainer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppStyles.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_trainerEarnings.isEmpty)
          Center(
            child: Text(
              'No trainer earnings data available',
              style: TextStyle(
                color: AppStyles.slateGray,
                fontSize: 14,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _trainerEarnings.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final trainer = _trainerEarnings[index];
              return _buildTrainerEarningCard(trainer);
            },
          ),
      ],
    );
  }

  Widget _buildTrainerEarningCard(Map<String, dynamic> trainer) {
    final name = trainer['name'] as String;
    final totalEarnings = trainer['totalEarnings'] as double;
    final monthlyEarnings = trainer['monthlyEarnings'] as double;
    final totalSessions = trainer['totalSessions'] as int;
    final monthlySessions = trainer['monthlySessions'] as int;
    final role = trainer['role'] as String;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppStyles.primarySage.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppStyles.primarySage.withOpacity(0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'T',
                  style: TextStyle(
                    color: AppStyles.primarySage,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      role == 'superTrainer' ? 'Super Trainer' : 'Trainer',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.slateGray,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppStyles.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '\$${totalEarnings.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppStyles.successGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Month',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.slateGray,
                      ),
                    ),
                    Text(
                      '\$${monthlyEarnings.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.primarySage,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Sessions',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.slateGray,
                      ),
                    ),
                    Text(
                      totalSessions.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.mutedBlue,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Sessions',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.slateGray,
                      ),
                    ),
                    Text(
                      monthlySessions.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.warningAmber,
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

  Widget _buildRecentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long, color: AppStyles.primarySage, size: 24),
            const SizedBox(width: 12),
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppStyles.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_recentTransactions.isEmpty)
          Center(
            child: Text(
              'No recent transactions',
              style: TextStyle(
                color: AppStyles.slateGray,
                fontSize: 14,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentTransactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final transaction = _recentTransactions[index];
              return _buildTransactionCard(transaction);
            },
          ),
      ],
    );
  }

  Widget _buildTransactionCard(PaymentHistory payment) {
    Color statusColor;
    IconData statusIcon;
    
    switch (payment.status) {
      case 'completed':
        statusColor = AppStyles.successGreen;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = AppStyles.warningAmber;
        statusIcon = Icons.schedule;
        break;
      case 'failed':
        statusColor = AppStyles.errorRed;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = AppStyles.slateGray;
        statusIcon = Icons.help;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppStyles.primarySage.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${payment.sessionsPurchased} sessions purchased',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(payment.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.slateGray,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${payment.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              Text(
                payment.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 