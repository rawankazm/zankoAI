import '../core/network/api_client.dart';
import '../models/payment_model.dart';

/// Payment Service interacting with the DigitalOcean Backend.
/// Strict Zero-Retry Policy: Payment transactions are never blindly retried on network failure.
class PaymentService {
  final ApiClient _client;

  PaymentService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  static final PaymentService instance = PaymentService();

  /// Initiates an authoritative payment checkout with Iraqi payment gateways (FIB or ZainCash).
  /// Note: Blind retries are strictly forbidden by ApiClient on /payments.
  Future<PaymentModel> createCheckout({
    required String planType,
    required String provider, // 'fib', 'zaincash', 'fastpay'
    required double amount,
    String currency = 'IQD',
    String? redirectUrl,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/payments/checkout',
      data: {
        'plan_type': planType,
        'provider': provider.toLowerCase(),
        'amount': amount,
        'currency': currency,
        'redirect_url': ?redirectUrl,
      },
    );
    final data =
        response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
    return PaymentModel.fromJson(data);
  }

  /// Verifies current payment transaction status by ID.
  Future<PaymentModel> getPaymentStatus(String paymentId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/payments/$paymentId',
    );
    final data =
        response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
    return PaymentModel.fromJson(data);
  }
}
