// ==============================================================================
// ZankoAI Iraq Payment Client API Service
// ==============================================================================

import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/payment_model.dart';

class PaymentClientService {
  final Dio? _customDio;
  PaymentClientService({Dio? dio}) : _customDio = dio;
  PaymentClientService._() : _customDio = null;
  static final PaymentClientService instance = PaymentClientService._();

  Dio get _dio => _customDio ?? ApiClient().dio;

  /// Initiates payment checkout with Iraqi gateway or mobile wallet
  Future<PaymentCheckoutResult> createCheckout({
    required String plan,
    String? provider,
    String? returnUrl,
    bool? isRenewal,
  }) async {
    final payload = <String, dynamic>{
      'plan': plan.toUpperCase(),
      'provider': ?provider?.toLowerCase(),
      'returnUrl': ?returnUrl,
      'isRenewal': ?isRenewal,
    };

    final response = await _dio.post<Map<String, dynamic>>(
      '/payments/checkout',
      data: payload,
    );

    final body = response.data ?? {};
    final data = (body['data'] as Map<String, dynamic>?) ?? body;
    return PaymentCheckoutResult.fromJson(data);
  }

  /// Retrieves payment status and verification
  Future<PaymentRecordModel> getPayment(String paymentId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/payments/' + paymentId,
    );

    final body = response.data ?? {};
    final data = (body['data'] as Map<String, dynamic>?) ?? body;
    return PaymentRecordModel.fromJson(data);
  }
}
