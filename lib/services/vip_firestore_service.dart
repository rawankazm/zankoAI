import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// Fully decoupled from legacy Firebase (tomartv-67cda).
/// All operations now run natively and authoritatively against Supabase PostgreSQL.
class VipFirestoreService {
  /// Pure helper: maps plan identifier or price to duration in days
  static int calculatePlanDays({
    String? plan,
    num? price,
    int? durationDays,
    String? expiryIso,
  }) {
    if (durationDays != null && durationDays > 0) return durationDays;

    final p = (plan ?? '').trim().toLowerCase();
    if (p == '9_months' ||
        p == '9months' ||
        p == '9_month' ||
        p == '9m' ||
        p == 'annual' ||
        p == 'academic_year') {
      return 270; // 9 months
    }
    if (p == '3_months' ||
        p == '3months' ||
        p == '3_month' ||
        p == '3m' ||
        p == 'semester' ||
        p == 'quarterly') {
      return 90; // 3 months
    }
    if (p == '1_year' || p == 'yearly' || p == '12_months') {
      return 365; // 1 year
    }
    if (p == '1_month' || p == '1month' || p == 'monthly') {
      return 30; // 1 month
    }

    // Fallback based on IQD price
    if (price != null) {
      final pr = price.toInt();
      if (pr >= 35000) return 270; // 40,000 IQD -> 9 months
      if (pr >= 10000) return 90; // 12,000 IQD -> 3 months
      if (pr > 0) return 30; // 5,000 IQD -> 1 month
    }

    return 30;
  }

  /// Disconnected from Firebase Auth — returns null with zero network calls
  static Future<Map<String, String>?> getFirebaseAuthToken({
    required String userEmail,
    String? userId,
  }) async {
    return null;
  }

  /// Disconnected: User data is authoritatively stored in Supabase PostgreSQL
  static Future<void> syncUserToFirestore(UserModel user) async {
    // No-op: Supabase is the primary backend
  }

  /// Fetches payment configuration (FastPay, FIB, ZainCash accounts & pricing)
  static Future<Map<String, dynamic>?> getPaymentConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('zanko_cached_payment_config');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        return jsonDecode(cachedJson) as Map<String, dynamic>;
      }
    } catch (_) {}

    return {
      'fastpay_number': '0750 000 0000',
      'fib_number': '0750 000 0000',
      'zaincash_number': '0780 000 0000',
      'price_1m': 5000,
      'price_3m': 12000,
      'price_9m': 40000,
      'admin_whatsapp': '+9647500000000',
    };
  }

  /// Saves payment configuration locally in device storage
  static Future<bool> savePaymentConfig({
    String? whatsapp,
    String? telegram,
    String? fib,
    String? fastpay,
    String? zaincash,
    int? price1m,
    int? price3m,
    int? price9m,
    Map<String, dynamic>? config,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> mapToSave = {};
      if (config != null) {
        mapToSave.addAll(config);
      }
      if (whatsapp != null) mapToSave['admin_whatsapp'] = whatsapp;
      if (telegram != null) mapToSave['admin_telegram'] = telegram;
      if (fib != null) mapToSave['fib_number'] = fib;
      if (fastpay != null) mapToSave['fastpay_number'] = fastpay;
      if (zaincash != null) mapToSave['zaincash_number'] = zaincash;
      if (price1m != null) mapToSave['price_1m'] = price1m;
      if (price3m != null) mapToSave['price_3m'] = price3m;
      if (price9m != null) mapToSave['price_9m'] = price9m;

      await prefs.setString(
        'zanko_cached_payment_config',
        jsonEncode(mapToSave),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Submits VIP upgrade request directly to Supabase
  static Future<bool> submitVipRequest({
    required String userId,
    String? userEmail,
    String? userName,
    String? plan,
    String? planId,
    String? paymentMethod,
    String? senderPhone,
    String? transactionCode,
    String? transactionId,
    String? screenshotUrl,
    int? durationDays,
    int? priceIqd,
    num? amountIqd,
  }) async {
    try {
      final effectivePlan = plan ?? planId ?? '1_month';
      final effectiveMethod = paymentMethod ?? 'WhatsApp';
      final effectiveCode = transactionCode ?? transactionId ?? 'DIRECT';
      final effectivePrice = priceIqd ?? amountIqd?.toInt() ?? 5000;
      final client = Supabase.instance.client;
      await client.from('notifications').insert({
        'user_id': userId,
        'title': 'داواکاری نوێکردنەوەی VIP ($effectivePlan)',
        'body':
            'شێواز: $effectiveMethod | ناو: ${userName ?? 'خوێندکار'} | ئیمەیڵ: ${userEmail ?? ''} | ژمارە: ${senderPhone ?? '-'} | کۆد: $effectiveCode | بڕ: $effectivePrice دینار',
        'type': 'system_notification',
        'is_read': true,
        'data': {
          'is_vip_request': true,
          'action': 'VIP_REQUEST',
          'status': 'pending',
          'user_id': userId,
          'user_name': userName,
          'user_email': userEmail,
          'sender_phone': senderPhone,
          'plan': effectivePlan,
          'price_iqd': effectivePrice,
          'payment_method': effectiveMethod,
          'transaction_code': effectiveCode,
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      try {
        final uniqueOrderId =
            'VIP-${DateTime.now().millisecondsSinceEpoch}-${userId.length > 4 ? userId.substring(0, 4) : userId}';
        await client.from('payments').insert({
          'user_id': userId,
          'order_id': uniqueOrderId,
          'transaction_id': effectiveCode,
          'amount': effectivePrice,
          'currency': 'IQD',
          'provider': effectiveMethod.toLowerCase(),
          'status': 'pending',
          'plan': effectivePlan,
          'metadata': {
            'plan': effectivePlan,
            'email': userEmail,
            'user_name': userName,
            'phone': senderPhone,
            'code': effectiveCode,
          },
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (pe) {
        debugPrint('[VipFirestoreService] payments insert notice: $pe');
      }
      return true;
    } catch (e) {
      debugPrint('[VipFirestoreService] Supabase submit request notice: $e');
      return true;
    }
  }

  /// Checks VIP status directly from Supabase profiles table
  static Future<bool> checkAndSyncVipStatus({
    required String userId,
    required String userEmail,
  }) async {
    try {
      if (userId.isEmpty) return false;
      final res = await Supabase.instance.client
          .from('profiles')
          .select('is_vip, plan, vip_status, vip_expiry')
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        final isVip =
            res['is_vip'] == true ||
            (res['plan']?.toString().toLowerCase() == 'premium');
        return isVip;
      }
    } catch (e) {
      debugPrint('[VipFirestoreService] Supabase VIP status check notice: $e');
    }
    return false;
  }

  /// Updates FCM device token in Supabase profiles table
  static Future<void> updateUserFcmToken({
    required String userId,
    String? email,
    required String fcmToken,
  }) async {
    try {
      if (userId.isNotEmpty && fcmToken.isNotEmpty) {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': fcmToken})
            .eq('id', userId);
      }
    } catch (_) {}
  }
}
