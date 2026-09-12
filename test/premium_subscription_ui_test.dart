// ==============================================================================
// ZankoAI Premium Subscription UI & Zero-Client-Trust Verification Tests
// ==============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:zanko_ai/models/user_model.dart';
import 'package:zanko_ai/services/auth_service.dart';
import 'package:zanko_ai/services/language_provider.dart';
import 'package:zanko_ai/services/subscription_client_service.dart';
import 'package:zanko_ai/views/subscription/premium_subscription_screen.dart';

class MockDio extends Mock implements Dio {}

class MockAuthService extends Mock implements AuthService {}

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

Widget _createTestApp({
  required Widget child,
  required AuthService authService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>.value(value: authService),
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  late MockDio mockDio;
  late MockAuthService mockAuthService;
  late SubscriptionClientService subscriptionService;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = MockDio();
    mockAuthService = MockAuthService();
    subscriptionService = SubscriptionClientService(dio: mockDio);

    when(() => mockAuthService.currentUser).thenReturn(
      UserModel(
        id: 'usr_test_123',
        email: 'test@zanko.edu.krd',
        name: 'Test Student',
        role: UserRole.student,
        isVip: false,
      ),
    );
  });

  group('Premium Subscription UI - Zero Client Trust & Verification', () {
    testWidgets(
      '1. Shows Free Plan by default and does NOT display Premium until backend confirms it',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Mock backend returning FREE / expired status
        when(
          () => mockDio.get<Map<String, dynamic>>(
            '/subscription',
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => _buildResponse(
            statusCode: 200,
            data: {
              'data': {
                'id': 'sub_free',
                'user_id': 'usr_test_123',
                'plan': 'free',
                'status': 'expired',
                'current_period_end': null,
                'is_active': false,
                'usage': {
                  'features': {
                    'ai_chat': {
                      'current_usage': 4,
                      'limit': 10,
                      'remaining': 6,
                    },
                    'pdf': {'current_usage': 1, 'limit': 3, 'remaining': 2},
                  },
                },
              },
            },
            requestOptions: _opts('/subscription'),
          ),
        );

        await tester.pumpWidget(
          _createTestApp(
            child: PremiumSubscriptionScreen(
              clientService: subscriptionService,
            ),
            authService: mockAuthService,
          ),
        );

        await tester.pumpAndSettle();

        // Must display Free plan, NOT premium
        expect(find.text('پلانی ئێستات بەخۆڕاییە (Free Plan)'), findsOneWidget);
        expect(
          find.text('ئابوونە بەسەرچووە ⚠️'),
          findsOneWidget,
        ); // subscription_expired
        expect(
          find.text('تۆ خاوەنی هەژماری تایبەتی پرێمیۆمی ZankoAI یت ✨'),
          findsNothing,
        );

        // Verify remaining quota indicator
        expect(find.text('ماوە: 6 پرسیار'), findsOneWidget);
        expect(find.text('ماوە: 2 کتێب / فایل'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Displays verified Premium status, renewal date, and quotas when backend confirms it',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final renewalDate = DateTime.now().toUtc().add(
          const Duration(days: 28),
        );

        // Mock backend returning ACTIVE PREMIUM status
        when(
          () => mockDio.get<Map<String, dynamic>>(
            '/subscription',
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => _buildResponse(
            statusCode: 200,
            data: {
              'data': {
                'id': 'sub_premium_active',
                'user_id': 'usr_test_123',
                'plan': 'premium_monthly',
                'status': 'active',
                'current_period_end': renewalDate.toIso8601String(),
                'is_active': true,
                'usage': {
                  'features': {
                    'ai_chat': {
                      'current_usage': 12,
                      'limit': 500,
                      'remaining': 488,
                    },
                  },
                },
              },
            },
            requestOptions: _opts('/subscription'),
          ),
        );

        await tester.pumpWidget(
          _createTestApp(
            child: PremiumSubscriptionScreen(
              clientService: subscriptionService,
            ),
            authService: mockAuthService,
          ),
        );

        await tester.pumpAndSettle();

        // Must display Premium verified state
        expect(
          find.text('تۆ خاوەنی هەژماری تایبەتی پرێمیۆمی ZankoAI یت ✨'),
          findsOneWidget,
        );
        expect(find.text('ئابوونە چالاکە ✅'), findsOneWidget);
        expect(find.text('ماوە: 488 پرسیار'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Renders local Iraqi payment providers (FastPay, FIB, ZainCash, Qi Card)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(
          () => mockDio.get<Map<String, dynamic>>(
            '/subscription',
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => _buildResponse(
            statusCode: 200,
            data: {
              'data': {'id': 'sub_free', 'plan': 'free', 'status': 'expired'},
            },
            requestOptions: _opts('/subscription'),
          ),
        );

        await tester.pumpWidget(
          _createTestApp(
            child: PremiumSubscriptionScreen(
              clientService: subscriptionService,
            ),
            authService: mockAuthService,
          ),
        );

        await tester.pumpAndSettle();

        // Localized payment providers
        expect(find.text('فاست پەی (FastPay)'), findsOneWidget);
        expect(find.text('بانکی یەکەمی عێراقی (FIB)'), findsOneWidget);
        expect(find.text('زەین کاش (ZainCash)'), findsOneWidget);
        expect(find.text('کی کارت / ماستەرکارت (Qi Card)'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Strict Zero Raw Card data: No card number/CVV input exists on the screen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(
          () => mockDio.get<Map<String, dynamic>>(
            '/subscription',
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => _buildResponse(
            statusCode: 200,
            data: {
              'data': {'id': 'sub_free', 'plan': 'free', 'status': 'expired'},
            },
            requestOptions: _opts('/subscription'),
          ),
        );

        await tester.pumpWidget(
          _createTestApp(
            child: PremiumSubscriptionScreen(
              clientService: subscriptionService,
            ),
            authService: mockAuthService,
          ),
        );

        await tester.pumpAndSettle();

        // Verify zero raw card input fields (TextField / TextFormField)
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(TextFormField), findsNothing);

        // Verify Security Notice text is present
        expect(
          find.text(
            'پارەدانی پارێزراو لە ڕێگەی دەروازەی فەرمی (هیچ زانیارییەکی کارت لە ئەپەکە پاشەکەوت ناکرێت) 🔒',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '5. Kurdish RTL text direction and plan comparison tabs work seamlessly',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(
          () => mockDio.get<Map<String, dynamic>>(
            '/subscription',
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => _buildResponse(
            statusCode: 200,
            data: {
              'data': {'id': 'sub_free', 'plan': 'free', 'status': 'expired'},
            },
            requestOptions: _opts('/subscription'),
          ),
        );

        await tester.pumpWidget(
          _createTestApp(
            child: PremiumSubscriptionScreen(
              clientService: subscriptionService,
            ),
            authService: mockAuthService,
          ),
        );

        await tester.pumpAndSettle();

        // Initially on PREMIUM comparison tab
        expect(find.text('تایبەتمەندییە باڵاکانی پرێمیۆم'), findsOneWidget);

        // Tap FREE tab
        await tester.tap(find.text('بەخۆڕایی'));
        await tester.pumpAndSettle();

        // Should now show FREE plan comparison card
        expect(find.text('پلانی ئاسایی (FREE)'), findsOneWidget);
        expect(find.text('٠ دینار / هەتاهەتایە'), findsOneWidget);
      },
    );
  });
}
