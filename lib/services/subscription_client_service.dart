// ==============================================================================
// ZankoAI Subscription Client API Service
// ==============================================================================

import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/subscription_model.dart';

class SubscriptionClientService {
  final Dio? _customDio;
  SubscriptionClientService({Dio? dio}) : _customDio = dio;
  SubscriptionClientService._() : _customDio = null;
  static final SubscriptionClientService instance = SubscriptionClientService._();

  Dio get _dio => _customDio ?? ApiClient().dio;

  /// Fetches authoritative, server-verified subscription status
  Future<UserSubscriptionModel> getSubscription() async {
    final response = await _dio.get<Map<String, dynamic>>('/subscription');
    final body = response.data ?? {};
    final data = body['data'] as Map<String, dynamic>? ?? body;
    return UserSubscriptionModel.fromJson(data);
  }

  /// Initiates verified payment checkout with chosen provider
  Future<SubscriptionCheckoutModel> createCheckout({
    required SubscriptionPlanType plan,
    required String provider,
    String? returnUrl,
    String? cancelUrl,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/subscription/checkout',
      data: {
        'plan': plan.value,
        'provider': provider.toLowerCase(),
        'returnUrl': ?returnUrl,
        'cancelUrl': ?cancelUrl,
      },
    );

    final body = response.data ?? {};
    final data = body['data'] as Map<String, dynamic>? ?? body;
    return SubscriptionCheckoutModel.fromJson(data);
  }

  /// Cancels recurring subscription at period end
  Future<Map<String, dynamic>> cancelSubscription({String? reason}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/subscription/cancel',
      data: {
        'reason': ?reason,
      },
    );

    final body = response.data ?? {};
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  /// Restores subscription through direct server-to-server provider verification.
  /// Flutter claims of payment are never trusted.
  Future<UserSubscriptionModel> restoreSubscription() async {
    final response = await _dio.post<Map<String, dynamic>>('/subscription/restore');
    final body = response.data ?? {};
    final data = body['data'] as Map<String, dynamic>? ?? body;
    return UserSubscriptionModel.fromJson(data);
  }

  /// Fetches subscription history, payment history, and event audit history
  Future<Map<String, dynamic>> getHistory() async {
    final response = await _dio.get<Map<String, dynamic>>('/subscription/history');
    final body = response.data ?? {};
    return (body['data'] as Map<String, dynamic>?) ?? body;
  }
}
