// ==============================================================================
// ZankoAI Subscription Client API Service
// ==============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/network/api_client.dart';
import '../models/subscription_model.dart';
import 'vip_firestore_service.dart';

class SubscriptionClientService {
  final Dio? _customDio;
  SubscriptionClientService({Dio? dio}) : _customDio = dio;
  SubscriptionClientService._() : _customDio = null;
  static final SubscriptionClientService instance =
      SubscriptionClientService._();

  Dio get _dio => _customDio ?? ApiClient().dio;

  /// Fetches authoritative, server-verified subscription status
  Future<UserSubscriptionModel> getSubscription() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/subscription');
      final body = response.data ?? {};
      final data = body['data'] as Map<String, dynamic>? ?? body;
      return UserSubscriptionModel.fromJson(data);
    } catch (e) {
      if (_customDio != null) rethrow; // Keep strict behavior in unit tests
      if (e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.response == null ||
              e.message?.contains('NETWORK_ERROR') == true)) {
        return await _fallbackFromSupabase();
      }
      rethrow;
    }
  }

  /// Supabase direct query fallback when DigitalOcean backend is unreachable
  Future<UserSubscriptionModel> _fallbackFromSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        return UserSubscriptionModel.fromJson({
          'hasActiveSubscription': false,
          'isPremium': false,
          'plan': 'FREE',
          'status': 'expired',
        });
      }

      // Check & sync from Firestore VIP requests if not yet verified
      try {
        await VipFirestoreService.checkAndSyncVipStatus(
          userId: currentUser.id,
          userEmail: currentUser.email ?? '',
        );
      } catch (_) {}

      // Query profiles table
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id, plan, is_vip, vip_status, vip_expiry')
          .eq('id', currentUser.id)
          .maybeSingle();

      // Query subscriptions table
      final sub = await Supabase.instance.client
          .from('subscriptions')
          .select('*')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final isVip = profile?['is_vip'] == true ||
          profile?['plan'] == 'premium' ||
          sub?['status'] == 'active';

      final expiryStr = sub?['current_period_end'] ?? profile?['vip_expiry'];
      final expiry =
          expiryStr != null ? DateTime.tryParse(expiryStr.toString()) : null;

      final isStillActive =
          isVip && (expiry == null || expiry.isAfter(DateTime.now()));

      return UserSubscriptionModel.fromJson({
        'hasActiveSubscription': isStillActive,
        'isPremium': isStillActive,
        'plan': isStillActive
            ? (sub?['plan'] ?? profile?['plan'] ?? 'PREMIUM_MONTHLY')
            : 'FREE',
        'status': isStillActive ? 'active' : 'expired',
        'currentPeriodEnd': expiry?.toIso8601String(),
        'provider': sub?['provider'] ?? 'admin_grant',
      });
    } catch (_) {
      return UserSubscriptionModel.fromJson({
        'hasActiveSubscription': false,
        'isPremium': false,
        'plan': 'FREE',
        'status': 'expired',
      });
    }
  }

  /// Initiates verified payment checkout with chosen provider
  Future<SubscriptionCheckoutModel> createCheckout({
    required SubscriptionPlanType plan,
    required String provider,
    String? returnUrl,
    String? cancelUrl,
  }) async {
    try {
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
    } catch (e) {
      if (_customDio != null) rethrow; // Keep strict behavior in unit tests
      if (e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.response == null ||
              e.message?.contains('NETWORK_ERROR') == true)) {
        return await _fallbackCreateCheckout(plan: plan, provider: provider);
      }
      rethrow;
    }
  }

  /// Direct checkout fallback when backend API is offline
  Future<SubscriptionCheckoutModel> _fallbackCreateCheckout({
    required SubscriptionPlanType plan,
    required String provider,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'guest';
    final userEmail = user?.email ?? '';
    final userName = user?.userMetadata?['name']?.toString() ??
        user?.userMetadata?['full_name']?.toString() ??
        'خوێندکار';
    final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
    final amount = plan.priceIqd;

    final planDays = plan.durationDays;
    final planIdStr = plan == SubscriptionPlanType.premiumYearly
        ? '9_months'
        : (plan == SubscriptionPlanType.premiumQuarterly
            ? '3_months'
            : '1_month');

    // 1. Post to Firestore vip_requests so it appears immediately on zanko-admin.vercel.app/vip
    try {
      await VipFirestoreService.submitVipRequest(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        planId: planIdStr,
        amountIqd: amount,
        paymentMethod: provider,
        transactionId: orderId,
      );
    } catch (fsErr) {
      debugPrint('Notice submitting to Firestore vip_requests: $fsErr');
    }

    // 2. Record pending transaction in Supabase payments table
    try {
      if (user != null) {
        await Supabase.instance.client.from('payments').insert({
          'user_id': userId,
          'order_id': orderId,
          'amount': amount,
          'currency': 'IQD',
          'provider': provider.toLowerCase(),
          'status': 'pending',
          'payment_method': provider,
          'metadata': {
            'plan': plan.value,
            'plan_id': planIdStr,
            'plan_days': planDays,
            'email': userEmail,
            'user_name': userName,
          },
        });
      }
    } catch (_) {
      try {
        await Supabase.instance.client.from('payment_transactions').insert({
          'user_id': userId,
          'user_email': userEmail,
          'plan_id': planIdStr,
          'amount_iqd': amount,
          'payment_method': provider,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    final planTitle = plan == SubscriptionPlanType.premiumYearly
        ? 'پلانی ٩ مانگ (٤٠،٠٠٠ د.ع)'
        : (plan == SubscriptionPlanType.premiumQuarterly
            ? 'پلانی ٣ مانگ (١٢،٠٠٠ د.ع)'
            : 'پلانی ١ مانگ (٥،٠٠٠ د.ع)');

    final priceFormatted = plan == SubscriptionPlanType.premiumYearly
        ? '٤٠,٠٠٠'
        : (plan == SubscriptionPlanType.premiumQuarterly ? '١٢,٠٠٠' : '٥,٠٠٠');

    final msg = '''سڵاو بەڕێزم 👑
دەمەوێت بەشداری پرێمیۆم / VIP لە ZankoAI چالاک بکەم:

📌 زانیاری داواکاری:
• پلان: $planTitle
• بڕی پارە: $priceFormatted دیناری عێراقی
• دەروازەی پارەدان: $provider
• ناوی خوێندکار: $userName
• ئیمەیڵ: $userEmail
• ئایدی هەژمار: $userId
• کۆدی داواکاری: $orderId

(وێنەی وەسڵی پارەدانەکەم لە خوارەوە هاوپێچ کردووە 🧾👇)''';

    final waUrl = 'https://wa.me/9647509987345?text=${Uri.encodeComponent(msg)}';

    return SubscriptionCheckoutModel(
      checkoutId: orderId,
      checkoutUrl: waUrl,
      qrPayload: 'zanko_pay:$orderId:$amount:IQD:$provider',
      provider: provider,
      plan: plan,
      amount: amount,
      currency: 'IQD',
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    );
  }

  /// Cancels recurring subscription at period end
  Future<Map<String, dynamic>> cancelSubscription({String? reason}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/subscription/cancel',
      data: {'reason': ?reason},
    );

    final body = response.data ?? {};
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  /// Restores subscription through direct server-to-server provider verification.
  /// Flutter claims of payment are never trusted.
  Future<UserSubscriptionModel> restoreSubscription() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/subscription/restore',
    );
    final body = response.data ?? {};
    final data = body['data'] as Map<String, dynamic>? ?? body;
    return UserSubscriptionModel.fromJson(data);
  }

  /// Fetches authoritative user usage summary from /usage/status
  Future<UserUsageSummaryModel?> getUsageStatus() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/usage/status');
      final body = response.data ?? {};
      final data = body['data'] as Map<String, dynamic>? ?? body;
      return UserUsageSummaryModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Securely launches the provider's external hosted checkout URL
  static Future<bool> launchCheckoutUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  /// Retrieves subscription and billing history from /subscription/history
  Future<Map<String, dynamic>> getHistory() async {
    final response = await _dio.get<Map<String, dynamic>>('/subscription/history');
    final body = response.data ?? {};
    return body['data'] as Map<String, dynamic>? ?? body;
  }
}
