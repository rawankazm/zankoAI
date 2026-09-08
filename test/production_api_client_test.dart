import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/core/network/api_client.dart';
import 'package:zanko_ai/core/network/api_error.dart';
import 'package:zanko_ai/core/network/api_state.dart';

void main() {
  group('1. ApiClient Header & Metadata Interception', () {
    test('attaches client platform and version headers', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        expect(options.headers['X-Client-Platform'], 'Flutter');
        expect(options.headers['X-Client-Version'], '2.0.0');
        return ResponseBody.fromString(
          jsonEncode({'status': 'ok'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final client = ApiClient(customDio: dio);
      final response = await client.get<Map<String, dynamic>>('/health');
      expect(response.statusCode, 200);
      expect(response.data!['status'], 'ok');
    });
  });

  group('2. 401 Session Auto-Refresh and Replay', () {
    test(
      'intercepts 401, refreshes token via callback, and re適es request with new bearer',
      () async {
        int requestCount = 0;
        bool refreshCalled = false;
        String currentToken = 'expired_jwt_token_123';

        final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
        dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
          requestCount++;
          if (requestCount == 1) {
            // First attempt: expired token returns 401
            expect(
              options.headers['Authorization'],
              'Bearer expired_jwt_token_123',
            );
            return ResponseBody.fromString(
              jsonEncode({'error': 'Token expired', 'code': 'UNAUTHORIZED'}),
              401,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          } else {
            // Replayed attempt: refreshed token returns 200
            expect(
              options.headers['Authorization'],
              'Bearer renewed_jwt_token_456',
            );
            return ResponseBody.fromString(
              jsonEncode({
                'data': {'user_id': 'usr_verified_99'},
              }),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
        });

        final client = ApiClient(
          customDio: dio,
          tokenRefresher: () async {
            refreshCalled = true;
            currentToken = 'renewed_jwt_token_456';
            return currentToken;
          },
        );

        // Inject initial token into default headers for the test
        dio.options.headers['Authorization'] = 'Bearer $currentToken';

        final response = await client.get<Map<String, dynamic>>(
          '/auth/profile',
        );
        expect(
          refreshCalled,
          isTrue,
          reason: 'Refresh session callback must be invoked on 401',
        );
        expect(
          requestCount,
          2,
          reason: 'Request must be replayed once after token refresh',
        );
        expect(response.statusCode, 200);
        expect(response.data!['data']['user_id'], 'usr_verified_99');
      },
    );
  });

  group('3. Strict Status Code Mapping to Typed ApiExceptions', () {
    void setupStatusMock(
      Dio dio,
      int statusCode, [
      Map<String, dynamic>? body,
      Map<String, List<String>>? headers,
    ]) {
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode(
            body ??
                {'error': 'Error for $statusCode', 'code': 'ERR_$statusCode'},
          ),
          statusCode,
          headers:
              headers ??
              {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
        );
      });
    }

    test('maps 400 to BadRequestException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      setupStatusMock(dio, 400);
      final client = ApiClient(customDio: dio);

      expect(
        () => client.get('/test'),
        throwsA(
          isA<BadRequestException>().having(
            (e) => e.statusCode,
            'statusCode',
            400,
          ),
        ),
      );
    });

    test('maps 403 to ForbiddenException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      setupStatusMock(dio, 403);
      final client = ApiClient(customDio: dio);

      expect(
        () => client.get('/test'),
        throwsA(
          isA<ForbiddenException>().having(
            (e) => e.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });

    test('maps 404 to NotFoundException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      setupStatusMock(dio, 404);
      final client = ApiClient(customDio: dio);

      expect(
        () => client.get('/test'),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('maps 409 to ConflictException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      setupStatusMock(dio, 409);
      final client = ApiClient(customDio: dio);

      expect(
        () => client.get('/test'),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.statusCode,
            'statusCode',
            409,
          ),
        ),
      );
    });

    test('maps 429 quota to QuotaExceededException with Retry-After', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      setupStatusMock(
        dio,
        429,
        {'error': 'Daily AI quota exceeded', 'code': 'QUOTA_EXCEEDED'},
        {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'retry-after': ['60'],
        },
      );
      final client = ApiClient(customDio: dio);

      expect(
        () => client.get('/test'),
        throwsA(
          isA<QuotaExceededException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 60),
              ),
        ),
      );
    });

    test('maps 500 to ServerException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
      setupStatusMock(dio, 500);
      final client = ApiClient(customDio: dio);

      expect(
        () => client.get('/test'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });

  group('4. Zero-Leakage Security Interceptor', () {
    test(
      'strictly blocks request containing Supabase service_role key',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
        final client = ApiClient(customDio: dio);

        expect(
          () => client.post(
            '/test',
            data: {'key': 'service_role_secret_key_1234'},
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      },
    );

    test(
      'strictly blocks request containing Google Gemini API key (AIzaSy...) in query or payload',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
        final client = ApiClient(customDio: dio);

        expect(
          () => client.get(
            '/test?api_key=AIzaSyA0123456789012345678901234567890',
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      },
    );

    test(
      'strictly blocks request containing OpenAI key (sk-...) in headers or payload',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
        final client = ApiClient(customDio: dio);

        expect(
          () => client.post(
            '/test',
            data: {'openai': 'sk-proj1234567890123456789012345678901234'},
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      },
    );

    test(
      'strictly blocks request containing payment provider secrets (FIB_CLIENT_SECRET)',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
        final client = ApiClient(customDio: dio);

        expect(
          () => client.post(
            '/test',
            data: {'leak': 'FIB_CLIENT_SECRET=super_secret_pay_key'},
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      },
    );
  });

  group('5. Safe Retry Policy & Non-Retry Guarantees', () {
    test(
      'NEVER blindly retries payment checkout requests on network error',
      () async {
        int attempts = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
        dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
          attempts++;
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
            message: 'Connection timed out to payment gateway',
          );
        });

        final client = ApiClient(customDio: dio);

        try {
          await client.post('/payments/checkout', data: {'amount': 25000});
        } catch (_) {}

        expect(
          attempts,
          1,
          reason:
              'Payment requests must NEVER be retried blindly to avoid duplicate charges',
        );
      },
    );

    test(
      'NEVER retries non-idempotent AI generation jobs without Idempotency-Key',
      () async {
        int attempts = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
        dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
          attempts++;
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
            message: 'Timeout contacting AI provider',
          );
        });

        final client = ApiClient(customDio: dio);

        try {
          await client.post('/ai/chat', data: {'prompt': 'Calculate exam'});
        } catch (_) {}

        expect(
          attempts,
          1,
          reason: 'AI jobs without Idempotency-Key must not be retried',
        );
      },
    );

    test(
      'safely retries idempotent GET requests on transient 503 error up to 2 times',
      () async {
        int attempts = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://api.zankoai.com/api/v1'));
        dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
          attempts++;
          if (attempts < 3) {
            return ResponseBody.fromString(
              jsonEncode({'error': 'Service temporarily unavailable'}),
              503,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({'data': 'success_after_recovery'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final client = ApiClient(customDio: dio);
        final response = await client.get<Map<String, dynamic>>('/courses');

        expect(
          attempts,
          3,
          reason: 'Idempotent GET request must retry transient 503 errors',
        );
        expect(response.statusCode, 200);
        expect(response.data!['data'], 'success_after_recovery');
      },
    );
  });

  group('6. ResourceState / ApiState Functional Transitions', () {
    test('initial state flags and helpers', () {
      const state = ResourceState<String>.initial();
      expect(state.isInitial, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.dataOrNull, isNull);
    });

    test('loading state progress tracking', () {
      const state = ResourceState<String>.loading(progress: 0.65);
      expect(state.isLoading, isTrue);
      expect((state as LoadingState).progress, 0.65);
    });

    test('success state data retrieval', () {
      const state = ResourceState<int>.success(42);
      expect(state.isSuccess, isTrue);
      expect(state.dataOrNull, 42);
      expect(state.errorMessage, isNull);
    });

    test('error state message and error mapping', () {
      final error = ApiError(
        statusCode: 404,
        message: 'بابەتەکە نەدۆزرایەوە',
        errorCode: 'NOT_FOUND',
        timestamp: DateTime.now(),
      );
      final state = ResourceState<int>.error(error);
      expect(state.isError, isTrue);
      expect(state.errorMessage, 'بابەتەکە نەدۆزرایەوە');
      expect(state.errorOrNull?.statusCode, 404);
    });

    test('pattern matching via when()', () {
      const state = ResourceState<String>.success('Zanko AI');
      final result = state.when(
        initial: () => 'init',
        loading: (_) => 'loading',
        success: (data) => 'data: $data',
        error: (err) => 'err: ${err.message}',
      );
      expect(result, 'data: Zanko AI');
    });
  });
}

/// Lightweight mock adapter to simulate HTTP responses without native sockets
class _MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) _handler;

  _MockHttpClientAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
