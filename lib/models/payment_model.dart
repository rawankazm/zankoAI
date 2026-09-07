// ==============================================================================
// ZankoAI Iraq Payment Architecture — Payment Models
// ==============================================================================

enum PaymentStatusType {
  pending,
  paid,
  failed,
  cancelled,
  refunded,
}

class PaymentRecordModel {
  final String id;
  final String userId;
  final String provider;
  final String orderId;
  final String? transactionId;
  final double amount;
  final String currency;
  final PaymentStatusType status;
  final String plan;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentRecordModel({
    required this.id,
    required this.userId,
    required this.provider,
    required this.orderId,
    this.transactionId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.plan,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPaid => status == PaymentStatusType.paid;
  bool get isPending => status == PaymentStatusType.pending;
  bool get isFailed => status == PaymentStatusType.failed;
  bool get isCancelled => status == PaymentStatusType.cancelled;

  factory PaymentRecordModel.fromJson(Map<String, dynamic> json) {
    return PaymentRecordModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      transactionId: json['transaction_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'IQD',
      status: _parseStatus(json['status'] as String?),
      plan: json['plan'] as String? ?? '',
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'provider': provider,
      'order_id': orderId,
      'transaction_id': transactionId,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'plan': plan,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static PaymentStatusType _parseStatus(String? str) {
    switch (str?.toLowerCase()) {
      case 'paid':
      case 'success':
      case 'completed':
        return PaymentStatusType.paid;
      case 'failed':
      case 'declined':
        return PaymentStatusType.failed;
      case 'cancelled':
      case 'canceled':
      case 'expired':
        return PaymentStatusType.cancelled;
      case 'refunded':
        return PaymentStatusType.refunded;
      case 'pending':
      default:
        return PaymentStatusType.pending;
    }
  }
}

class PaymentCheckoutResult {
  final bool success;
  final String orderId;
  final String? transactionId;
  final String? paymentUrl;
  final String? qrPayload;
  final PaymentStatusType status;
  final double? amount;
  final String? currency;

  const PaymentCheckoutResult({
    required this.success,
    required this.orderId,
    this.transactionId,
    this.paymentUrl,
    this.qrPayload,
    required this.status,
    this.amount,
    this.currency,
  });

  factory PaymentCheckoutResult.fromJson(Map<String, dynamic> json) {
    return PaymentCheckoutResult(
      success: json['success'] as bool? ?? false,
      orderId: json['orderId'] as String? ?? '',
      transactionId: json['transactionId'] as String?,
      paymentUrl: json['paymentUrl'] as String?,
      qrPayload: json['qrPayload'] as String?,
      status: json['status'] != null
          ? PaymentRecordModel._parseStatus(json['status'] as String)
          : PaymentStatusType.pending,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
    );
  }
}
