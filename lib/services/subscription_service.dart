import '../core/network/api_client.dart';
import '../models/subscription_model.dart';

/// Service managing user VIP subscriptions, checkout sessions, and grace periods.
class SubscriptionService {
  final ApiClient _client;

  SubscriptionService({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  static final SubscriptionService instance = SubscriptionService();

  /// Fetches the active user's subscription and grace period lifecycle state.
  Future<SubscriptionModel> getSubscription() async {
    final response = await _client.get<Map<String, dynamic>>('/subscription');
    final data =
        response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
    return SubscriptionModel.fromJson(data);
  }

  /// Fetches subscription audit history and past invoices.
  Future<Map<String, dynamic>> getHistory() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/subscription/history',
    );
    return response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
  }

  /// Initiates a subscription upgrade checkout session with FIB or ZainCash.
  Future<Map<String, dynamic>> createCheckout({
    required SubscriptionPlanType planType,
    required String provider, // 'fib' or 'zaincash'
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/subscription/checkout',
      data: {'plan_type': planType.value, 'provider': provider.toLowerCase()},
    );
    return response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
  }

  /// Cancels recurring renewal at period end.
  Future<bool> cancelSubscription({String? reason}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/subscription/cancel',
      data: {'reason': ?reason},
    );
    return response.statusCode == 200;
  }

  /// Restores verified mobile App Store / Play Store purchases server-side.
  Future<Map<String, dynamic>> restoreSubscription() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/subscription/restore',
    );
    return response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
  }
}
