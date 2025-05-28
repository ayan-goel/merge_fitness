import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentHistory {
  final String id;
  final String clientId;
  final String trainerId;
  final String sessionPackageId;
  final double amount;
  final int sessionsPurchased;
  final String stripePaymentIntentId;
  final String status; // completed, pending, failed
  final DateTime createdAt;

  PaymentHistory({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.sessionPackageId,
    required this.amount,
    required this.sessionsPurchased,
    required this.stripePaymentIntentId,
    required this.status,
    required this.createdAt,
  });

  factory PaymentHistory.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return PaymentHistory(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      trainerId: data['trainerId'] ?? '',
      sessionPackageId: data['sessionPackageId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      sessionsPurchased: data['sessionsPurchased'] ?? 0,
      stripePaymentIntentId: data['stripePaymentIntentId'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'trainerId': trainerId,
      'sessionPackageId': sessionPackageId,
      'amount': amount,
      'sessionsPurchased': sessionsPurchased,
      'stripePaymentIntentId': stripePaymentIntentId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  PaymentHistory copyWith({
    String? id,
    String? clientId,
    String? trainerId,
    String? sessionPackageId,
    double? amount,
    int? sessionsPurchased,
    String? stripePaymentIntentId,
    String? status,
    DateTime? createdAt,
  }) {
    return PaymentHistory(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      trainerId: trainerId ?? this.trainerId,
      sessionPackageId: sessionPackageId ?? this.sessionPackageId,
      amount: amount ?? this.amount,
      sessionsPurchased: sessionsPurchased ?? this.sessionsPurchased,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 