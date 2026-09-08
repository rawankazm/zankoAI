import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/models/subscription_model.dart';
import 'package:zanko_ai/services/services.dart';

void main() {
  group('1. UserService API Integration', () {
    test('fetches user profile successfully', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        expect(options.path, '/auth/profile');
        expect(options.method, 'GET');
        return ResponseBody.fromString(
          jsonEncode({
            'data': {
              'id': 'usr_101',
              'email': 'student@zanko.edu.krd',
              'full_name': 'Kardo Ahmad',
              'role': 'student',
              'is_vip': true,
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final client = ApiClient(customDio: dio);
      final service = UserService(client: client);
      final profile = await service.getProfile();

      expect(profile.id, 'usr_101');
      expect(profile.fullName, 'Kardo Ahmad');
      expect(profile.isVip, isTrue);
    });

    test('fetches AI usage quota and limits', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        expect(options.path, '/usage/status');
        return ResponseBody.fromString(
          jsonEncode({
            'data': {
              'requests_today': 12,
              'daily_limit': 100,
              'tokens_used': 45000,
              'is_vip': true,
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final client = ApiClient(customDio: dio);
      final service = UserService(client: client);
      final usage = await service.getUsageQuota();

      expect(usage['requests_today'], 12);
      expect(usage['daily_limit'], 100);
      expect(usage['is_vip'], isTrue);
    });
  });

  group('2. CourseService & Academic Integration', () {
    test('lists courses and enrolls student', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        if (options.method == 'GET' && options.path == '/courses') {
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'items': [
                  {'id': 'crs_01', 'title': 'Data Structures', 'code': 'CS201'},
                  {
                    'id': 'crs_02',
                    'title': 'Artificial Intelligence',
                    'code': 'CS301',
                  },
                ],
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        } else if (options.method == 'POST' &&
            options.path == '/courses/crs_01/enroll') {
          return ResponseBody.fromString(
            jsonEncode({'success': true, 'message': 'Enrolled'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      final client = ApiClient(customDio: dio);
      final service = CourseService(client: client);

      final courses = await service.listCourses();
      expect(courses.length, 2);
      expect(courses[0]['title'], 'Data Structures');

      final enrolled = await service.enrollCourse('crs_01');
      expect(enrolled, isTrue);
    });
  });

  group('3. LectureService & Presigned Upload Flow', () {
    test('requests upload ticket and obtains signed URL', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        if (options.path == '/storage/upload-ticket') {
          expect(options.data['filename'], 'lecture_05.pdf');
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'ticket_id': 'tkt_998',
                'upload_url': 'https://s3.digitalocean.com/zanko/upload',
                'file_path': 'courses/crs_1/lecture_05.pdf',
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        } else if (options.path == '/storage/signed-url') {
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'signed_url':
                    'https://s3.digitalocean.com/zanko/signed_view.pdf?token=abc',
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      final client = ApiClient(customDio: dio);
      final service = LectureService(client: client);

      final ticket = await service.requestUploadTicket(
        category: 'lecture_notes',
        filename: 'lecture_05.pdf',
        contentType: 'application/pdf',
        sizeBytes: 102400,
      );
      expect(ticket['ticket_id'], 'tkt_998');

      final url = await service.getSignedUrl(
        bucket: 'zanko_materials',
        filePath: 'courses/crs_1/lecture_05.pdf',
      );
      expect(url, contains('signed_view.pdf'));
    });
  });

  group('4. FlashcardService & Spaced Repetition', () {
    test('lists due cards and submits SM-2 rating', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        if (options.path == '/flashcards/due') {
          return ResponseBody.fromString(
            jsonEncode({
              'data': [
                {
                  'id': 'crd_01',
                  'question': 'What is Big O of Binary Search?',
                  'answer': 'O(log n)',
                  'box': 2,
                },
              ],
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        } else if (options.path == '/flashcards/crd_01/review') {
          expect(options.data['rating'], 5);
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'next_review': '2026-09-15T00:00:00Z',
                'interval_days': 7,
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      final client = ApiClient(customDio: dio);
      final service = FlashcardService(client: client);

      final dueCards = await service.getDueFlashcards();
      expect(dueCards.length, 1);
      expect(dueCards.first.question, 'What is Big O of Binary Search?');

      final review = await service.reviewFlashcard('crd_01', 5);
      expect(review['interval_days'], 7);
    });
  });

  group('5. ProductionAiService with Idempotency Protection', () {
    test('sends chat message through backend with Idempotency-Key', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        expect(options.path, '/ai/chat');
        expect(
          options.headers['Idempotency-Key'],
          isNotNull,
          reason:
              'AI chat must inject an Idempotency-Key header to prevent duplicate execution',
        );
        expect(options.data['message'], 'Explain QuickSort in Kurdish');
        return ResponseBody.fromString(
          jsonEncode({
            'data': {
              'response': 'کویک سۆرت یەکێکە لە ئەلگۆریتمە خێراکان...',
              'conversation_id': 'conv_55',
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final client = ApiClient(customDio: dio);
      final service = ProductionAiService(client: client);

      final result = await service.sendChatMessage(
        message: 'Explain QuickSort in Kurdish',
      );
      expect(result['response'], contains('کویک سۆرت'));
      expect(result['conversation_id'], 'conv_55');
    });
  });

  group('6. SubscriptionService & PaymentService', () {
    test('fetches active subscription and creates checkout', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        if (options.path == '/subscription') {
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'id': 'sub_88',
                'user_id': 'usr_101',
                'plan_type': 'PREMIUM_MONTHLY',
                'status': 'ACTIVE',
                'is_active': true,
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        } else if (options.path == '/subscription/checkout') {
          expect(options.data['provider'], 'fib');
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'checkout_id': 'chk_fib_101',
                'payment_url': 'https://fib.iq/checkout/101',
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      final client = ApiClient(customDio: dio);
      final subService = SubscriptionService(client: client);

      final sub = await subService.getSubscription();
      expect(sub.isActive, isTrue);
      expect(sub.planType, SubscriptionPlanType.premiumMonthly);

      final checkout = await subService.createCheckout(
        planType: SubscriptionPlanType.premiumMonthly,
        provider: 'fib',
      );
      expect(checkout['checkout_id'], 'chk_fib_101');
    });

    test(
      'payment service initiates checkout without storing secrets',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
        dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
          expect(options.path, '/payments/checkout');
          expect(options.data['amount'], 10000.0);
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'id': 'pay_999',
                'status': 'PENDING',
                'amount': 10000.0,
                'currency': 'IQD',
                'provider': 'fib',
                'created_at': '2026-09-08T00:00:00Z',
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final client = ApiClient(customDio: dio);
        final payService = PaymentService(client: client);

        final payment = await payService.createCheckout(
          planType: 'PREMIUM_MONTHLY',
          provider: 'fib',
          amount: 10000.0,
        );
        expect(payment.id, 'pay_999');
        expect(payment.amount, 10000.0);
        expect(payment.provider, 'fib');
      },
    );
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) _handler;
  _MockHttpClientAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _handler(options);

  @override
  void close({bool force = false}) {}
}
