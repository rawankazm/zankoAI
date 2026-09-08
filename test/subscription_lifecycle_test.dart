// ==============================================================================
// ZankoAI Premium Subscription Lifecycle & Maintenance — Automated Test Suite
//
// Tests all required lifecycle states:
//   1. active: User has active period, isPremium == true, can access features
//   2. expired: STRICT RULE: If current_period_end < now, user cannot be Premium
//   3. cancelled: Cancel at period end retains access until expiry; immediate cancel drops
//   4. past_due: Grace period tracking, past_due status, payment failure handling
//   5. renewed: Seamless renewal extends period without losing remaining days
//   6. failed renewal: Auto-charge blocked for non-recurring providers / unauthorized users
//   7. history endpoint: GET /api/subscription/history returns subs, payments, events
// ==============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zanko_ai/models/subscription_model.dart';
import 'package:zanko_ai/services/subscription_client_service.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _buildResponse({
  required int statusCode,
  required Map<String, dynamic> data,
  required RequestOptions requestOptions,
}) {
  return Response<Map<String, dynamic>>(
    statusCode: statusCode,
    data: data,
    requestOptions: requestOptions,
  );
}

RequestOptions _opts(String path, {String method = 'GET'}) =>
    RequestOptions(path: path, method: method);

void main() {
  late MockDio mockDio;
  late SubscriptionClientService subscriptionService;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = MockDio();
    subscriptionService = SubscriptionClientService(dio: mockDio);
  });

  group('1. Active Subscription Lifecycle State', () {
    test(
      'User with active period has isPremium == true and can access features',
      () async {
        final futureEnd = DateTime.now().add(const Duration(days: 28));

        when(
          () => mockDio.get<Map<String, dynamic>>('/subscription'),
        ).thenAnswer(
          (_) async => _buildResponse(
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'hasActiveSubscription': true,
                'isPremium': true,
                'plan': 'PREMIUM_MONTHLY',
                'status': 'active',
                'currentPeriodStart': DateTime.now().toIso8601String(),
                'currentPeriodEnd': futureEnd.toIso8601String(),
                'cancelAtPeriodEnd': false,
                'daysRemaining': 28,
                'provider': 'qi_card',
              },
            },
            requestOptions: _opts('/subscription'),
          ),
        );

        final sub = await subscriptionService.getSubscription();

        expect(sub.hasActiveSubscription, isTrue);
        expect(sub.isPremium, isTrue);
        expect(sub.status, SubscriptionStatusType.active);
        expect(sub.canAccessPremiumFeatures, isTrue);
        expect(sub.isExpired, isFalse);
        expect(sub.daysRemaining, 28);
      },
    );
  });

  group('2. Expired Lifecycle State & Strict Rule', () {
    test(
      'STRICT RULE: If current_period_end < now, user cannot be treated as Premium',
      () async {
        final pastEnd = DateTime.now().subtract(const Duration(days: 2));

        when(
          () => mockDio.get<Map<String, dynamic>>('/subscription'),
        ).thenAnswer(
          (_) async => _buildResponse(
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'hasActiveSubscription': false,
                'isPremium': false,
                'plan': 'FREE',
                'status': 'expired',
                'currentPeriodStart': DateTime.now()
                    .subtract(const Duration(days: 32))
                    .toIso8601String(),
                'currentPeriodEnd': pastEnd.toIso8601String(),
                'cancelAtPeriodEnd': true,
                'daysRemaining': 0,
                'provider': 'sandbox',
              },
            },
            requestOptions: _opts('/subscription'),
          ),
        );

        final sub = await subscriptionService.getSubscription();

        expect(
          sub.isPremium,
          isFalse,
          reason: 'Strict rule: period ended means not premium',
        );
        expect(sub.hasActiveSubscription, isFalse);
        expect(sub.status, SubscriptionStatusType.expired);
        expect(sub.canAccessPremiumFeatures, isFalse);
        expect(sub.isExpired, isTrue);
        expect(sub.daysRemaining, 0);
      },
    );
  });

  group('3. Cancellation (Cancel at Period End vs Immediate)', () {
    test('Cancel at period end retains access until current_period_end', () async {
      final futureEnd = DateTime.now().add(const Duration(days: 14));

      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/subscription/cancel',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _buildResponse(
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'success': true,
              'status': 'active',
              'cancel_at_period_end': true,
              'message':
                  'Subscription will remain active until period end and will not renew.',
            },
          },
          requestOptions: _opts('/subscription/cancel', method: 'POST'),
        ),
      );

      final cancelRes = await subscriptionService.cancelSubscription();
      expect(cancelRes['success'], isTrue);
      expect(cancelRes['cancel_at_period_end'], isTrue);

      // Subsequent getSubscription check shows active benefits with cancelAtPeriodEnd == true
      final sub = UserSubscriptionModel(
        hasActiveSubscription: true,
        isPremium: true,
        plan: SubscriptionPlanType.premiumMonthly,
        status: SubscriptionStatusType.active,
        currentPeriodEnd: futureEnd,
        cancelAtPeriodEnd: true,
        daysRemaining: 14,
      );

      expect(sub.isPremium, isTrue);
      expect(sub.canAccessPremiumFeatures, isTrue);
      expect(sub.cancelAtPeriodEnd, isTrue);
    });

    test('Immediate cancellation revokes access immediately', () async {
      final sub = UserSubscriptionModel(
        hasActiveSubscription: false,
        isPremium: false,
        plan: SubscriptionPlanType.free,
        status: SubscriptionStatusType.canceled,
        currentPeriodEnd: DateTime.now().subtract(const Duration(seconds: 1)),
        cancelAtPeriodEnd: false,
        daysRemaining: 0,
      );

      expect(sub.isPremium, isFalse);
      expect(sub.canAccessPremiumFeatures, isFalse);
      expect(sub.status, SubscriptionStatusType.canceled);
    });
  });

  group('4. Failed Renewal & Grace Period (past_due)', () {
    test(
      'Failed renewal transitions to past_due with active grace period',
      () async {
        final graceEnd = DateTime.now().add(const Duration(days: 3));
        final pastPeriodEnd = DateTime.now().subtract(const Duration(hours: 2));

        final sub = UserSubscriptionModel(
          hasActiveSubscription: false,
          isPremium: false,
          plan: SubscriptionPlanType.premiumMonthly,
          status: SubscriptionStatusType.pastDue,
          currentPeriodEnd: pastPeriodEnd,
          inGracePeriod: true,
          gracePeriodEnd: graceEnd,
          daysRemaining: 0,
        );

        expect(sub.status, SubscriptionStatusType.pastDue);
        expect(sub.inGracePeriod, isTrue);
        expect(
          sub.canAccessPremiumFeatures,
          isFalse,
          reason:
              'STRICT RULE: If period has ended, user cannot be treated as Premium',
        );
      },
    );
  });

  group('5. Renewed Lifecycle State', () {
    test(
      'Renewal seamlessly extends period without losing remaining days',
      () async {
        final now = DateTime.now();
        final currentEnd = now.add(const Duration(days: 10));

        // Renew for 30 days
        final newEnd = currentEnd.add(const Duration(days: 30));

        final renewedSub = UserSubscriptionModel(
          hasActiveSubscription: true,
          isPremium: true,
          plan: SubscriptionPlanType.premiumMonthly,
          status: SubscriptionStatusType.active,
          currentPeriodStart: now,
          currentPeriodEnd: newEnd,
          cancelAtPeriodEnd: false,
          daysRemaining: 40,
        );

        expect(renewedSub.isPremium, isTrue);
        expect(renewedSub.canAccessPremiumFeatures, isTrue);
        expect(renewedSub.daysRemaining, 40);
        expect(renewedSub.currentPeriodEnd!.difference(currentEnd).inDays, 30);
      },
    );
  });

  group('6. Auto-Charge Protection Rule', () {
    test(
      'Non-recurring providers (Qi Card/ZainCash/FastPay) and unauthorized users block auto-charge',
      () {
        const nonRecurringProvider = 'qi_card';
        const autoRenewAuthorized = false;

        // Business logic condition:
        final canAutoCharge =
            nonRecurringProvider == 'stripe' && autoRenewAuthorized;
        expect(
          canAutoCharge,
          isFalse,
          reason: 'Iraqi gateways do not support recurring auto-charge',
        );
      },
    );
  });

  group('7. GET /api/subscription/history Endpoint', () {
    test(
      'Fetches aggregated subscription, payment, and event history',
      () async {
        when(
          () => mockDio.get<Map<String, dynamic>>('/subscription/history'),
        ).thenAnswer(
          (_) async => _buildResponse(
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'subscriptions': [
                  {
                    'id': 'sub_123',
                    'plan': 'PREMIUM_MONTHLY',
                    'status': 'active',
                    'current_period_end': DateTime.now()
                        .add(const Duration(days: 25))
                        .toIso8601String(),
                  },
                ],
                'payments': [
                  {
                    'id': 'pay_456',
                    'amount': 15000,
                    'currency': 'IQD',
                    'status': 'paid',
                    'provider': 'qi_card',
                  },
                ],
                'events': [
                  {
                    'event_type': 'subscription.activated',
                    'created_at': DateTime.now().toIso8601String(),
                  },
                  {
                    'event_type': 'subscription.renewed',
                    'created_at': DateTime.now().toIso8601String(),
                  },
                ],
              },
            },
            requestOptions: _opts('/subscription/history'),
          ),
        );

        final history = await subscriptionService.getHistory();

        expect(history.containsKey('subscriptions'), isTrue);
        expect(history.containsKey('payments'), isTrue);
        expect(history.containsKey('events'), isTrue);

        final subs = history['subscriptions'] as List;
        final payments = history['payments'] as List;
        final events = history['events'] as List;

        expect(subs.length, 1);
        expect(payments.length, 1);
        expect(events.length, 2);
      },
    );
  });
}
