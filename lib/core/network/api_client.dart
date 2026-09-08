import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';
import 'api_error.dart';

/// Token refresh callback contract for testability and decoupling.
typedef AuthSessionRefresher = Future<String?> Function();

/// Production-ready API Client for ZankoAI Flutter app connecting to
/// the DigitalOcean Backend and Supabase Auth.
class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._internal();

  final Dio dio;
  final AuthSessionRefresher? _customTokenRefresher;

  ApiClient({
    Dio? customDio,
    String? baseUrl,
    AuthSessionRefresher? tokenRefresher,
  }) : dio =
           customDio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? AppEnv.backendBaseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               sendTimeout: const Duration(seconds: 30),
               headers: {
                 'Content-Type': 'application/json',
                 'Accept': 'application/json',
               },
             ),
           ),
       _customTokenRefresher = tokenRefresher {
    _setupInterceptors();
  }

  ApiClient._internal()
    : dio = Dio(
        BaseOptions(
          baseUrl: AppEnv.backendBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ),
      _customTokenRefresher = null {
    _setupInterceptors();
  }

  /// Sets up all required security, authentication, retry, and error mapping interceptors.
  void _setupInterceptors() {
    dio.interceptors.clear();

    // 1. Zero Leakage Security Interceptor (Prevents sending server-only secrets)
    dio.interceptors.add(_createSecurityInterceptor());

    // 2. Auth Interceptor (Attaches Supabase access token and client metadata)
    dio.interceptors.add(_createAuthInterceptor());

    // 3. Safe Retry Interceptor (Exponential backoff without blind payment/AI retries)
    dio.interceptors.add(_createSafeRetryInterceptor());

    // 4. Token Refresh Interceptor (Handles 401 with seamless session refresh)
    dio.interceptors.add(_createTokenRefreshInterceptor());

    // 5. Error Mapping Interceptor (Translates Dio exceptions to typed ApiExceptions)
    dio.interceptors.add(_createErrorMappingInterceptor());
  }

  // ─── 1. Zero Leakage Security Interceptor ─────────────────────────────────
  InterceptorsWrapper _createSecurityInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final forbiddenPatterns = [
          RegExp(r'service_role', caseSensitive: false),
          RegExp(r'AIza[A-Za-z0-9_\-]{20,}'),
          RegExp(r'sk-[A-Za-z0-9_\-]{20,}'),
          RegExp(r'FIB_CLIENT_SECRET', caseSensitive: false),
          RegExp(r'ZAINCASH_SECRET', caseSensitive: false),
        ];

        final inspectable = [
          options.path,
          options.uri.toString(),
          options.headers.toString(),
          options.queryParameters.toString(),
          if (options.data != null) options.data.toString(),
        ].join(' ');

        for (final pattern in forbiddenPatterns) {
          if (pattern.hasMatch(inspectable)) {
            debugPrint(
              '🚨 [SECURITY ALARM] Prohibited server secret detected in outgoing request to ${options.path}',
            );
            return handler.reject(
              DioException(
                requestOptions: options,
                error: SecurityViolationException(
                  'Sensitive credentials (service_role, AI API keys, payment secrets) must never be transmitted by Flutter client.',
                ),
                type: DioExceptionType.cancel,
              ),
            );
          }
        }

        return handler.next(options);
      },
    );
  }

  // ─── 2. Auth Interceptor ──────────────────────────────────────────────────
  InterceptorsWrapper _createAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        // Attach Supabase Session JWT
        try {
          final session = Supabase.instance.client.auth.currentSession;
          if (session?.accessToken != null) {
            options.headers['Authorization'] = 'Bearer ${session!.accessToken}';
          }
        } catch (_) {
          // Supabase might not be initialized in isolated unit tests
        }

        // Standard client platform headers
        options.headers['X-Client-Platform'] = 'Flutter';
        options.headers['X-Client-Version'] = '2.0.0';

        return handler.next(options);
      },
    );
  }

  // ─── 3. Safe Retry Interceptor ────────────────────────────────────────────
  InterceptorsWrapper _createSafeRetryInterceptor() {
    return InterceptorsWrapper(
      onError: (DioException error, handler) async {
        if (error.error is SecurityViolationException ||
            error.type == DioExceptionType.cancel) {
          return handler.next(error);
        }

        final options = error.requestOptions;
        final retryCount = (options.extra['retry_count'] as int?) ?? 0;
        final maxRetries = 2;

        // RULE 1: Never blindly retry payment requests under any circumstances!
        final isPaymentEndpoint =
            options.path.contains('/payments') ||
            options.uri.path.contains('/payments');
        if (isPaymentEndpoint) {
          debugPrint(
            '🛡️ [SafeRetry] Blind retry strictly prohibited on payment endpoint: ${options.path}',
          );
          return handler.next(error);
        }

        // RULE 2: Never blindly retry AI generation jobs without an explicit Idempotency-Key
        final isAiJob =
            options.path.contains('/ai/') || options.uri.path.contains('/ai/');
        final hasIdempotencyKey =
            options.headers.containsKey('Idempotency-Key') ||
            options.headers.containsKey('X-Idempotency-Key');
        if (isAiJob &&
            !hasIdempotencyKey &&
            options.method.toUpperCase() == 'POST') {
          debugPrint(
            '🛡️ [SafeRetry] AI generation job without Idempotency-Key will not be retried: ${options.path}',
          );
          return handler.next(error);
        }

        // RULE 3: Only retry on transient failures (network errors, timeouts, 502/503/504)
        final isTransient =
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError ||
            (error.response?.statusCode != null &&
                [502, 503, 504].contains(error.response!.statusCode));

        final isSafeMethod =
            ['GET', 'HEAD', 'OPTIONS'].contains(options.method.toUpperCase()) ||
            hasIdempotencyKey;

        if (isTransient && isSafeMethod && retryCount < maxRetries) {
          options.extra['retry_count'] = retryCount + 1;
          final delayMs =
              (retryCount + 1) * 600; // 600ms, 1200ms exponential backoff
          debugPrint(
            '🔄 [SafeRetry] Retrying safe request (${options.method} ${options.path}) attempt ${retryCount + 1} after ${delayMs}ms',
          );
          await Future.delayed(Duration(milliseconds: delayMs));

          try {
            final response = await dio.fetch(options);
            return handler.resolve(response);
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        }

        return handler.next(error);
      },
    );
  }

  // ─── 4. Token Refresh Interceptor (401 Handling) ──────────────────────────
  InterceptorsWrapper _createTokenRefreshInterceptor() {
    return InterceptorsWrapper(
      onError: (DioException error, handler) async {
        final statusCode = error.response?.statusCode;
        final options = error.requestOptions;
        final alreadyRefreshed = options.extra['token_refreshed'] == true;

        if (statusCode == 401 && !alreadyRefreshed) {
          options.extra['token_refreshed'] = true;
          debugPrint(
            '🔑 [AuthRefresh] 401 encountered on ${options.path}. Attempting session refresh...',
          );

          try {
            String? newAccessToken;
            if (_customTokenRefresher != null) {
              newAccessToken = await _customTokenRefresher();
            } else {
              try {
                final response = await Supabase.instance.client.auth
                    .refreshSession();
                newAccessToken = response.session?.accessToken;
              } catch (refreshErr) {
                debugPrint(
                  '⚠️ [AuthRefresh] Supabase session refresh failed: $refreshErr',
                );
              }
            }

            if (newAccessToken != null && newAccessToken.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $newAccessToken';
              debugPrint(
                '✅ [AuthRefresh] Session renewed. Replaying original request: ${options.path}',
              );
              final replayedResponse = await dio.fetch(options);
              return handler.resolve(replayedResponse);
            }
          } catch (e) {
            debugPrint('❌ [AuthRefresh] Token refresh replay error: $e');
          }
        }

        return handler.next(error);
      },
    );
  }

  // ─── 5. Error Mapping Interceptor ─────────────────────────────────────────
  InterceptorsWrapper _createErrorMappingInterceptor() {
    return InterceptorsWrapper(
      onError: (DioException error, handler) {
        if (error.error is ApiException) {
          return handler.next(error);
        }

        final apiError = ApiError.fromDioException(error);
        final statusCode = error.response?.statusCode ?? 0;
        ApiException mappedException;

        // Parse Retry-After duration if returned by 429
        Duration? retryAfter;
        final retryAfterHeader = error.response?.headers.value('retry-after');
        if (retryAfterHeader != null) {
          final seconds = int.tryParse(retryAfterHeader);
          if (seconds != null) {
            retryAfter = Duration(seconds: seconds);
          }
        }

        switch (statusCode) {
          case 400:
            mappedException = BadRequestException(apiError);
            break;
          case 401:
            mappedException = UnauthorizedException(apiError);
            break;
          case 403:
            mappedException = ForbiddenException(apiError);
            break;
          case 404:
            mappedException = NotFoundException(apiError);
            break;
          case 409:
            mappedException = ConflictException(apiError);
            break;
          case 429:
            final isQuota =
                apiError.errorCode?.contains('QUOTA') == true ||
                apiError.message.contains('quota');
            mappedException = isQuota
                ? QuotaExceededException(apiError, retryAfter: retryAfter)
                : RateLimitException(apiError, retryAfter: retryAfter);
            break;
          case 500:
          case 502:
          case 503:
          case 504:
            mappedException = ServerException(apiError);
            break;
          default:
            if (error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.sendTimeout) {
              mappedException = TimeoutException(apiError);
            } else if (error.type == DioExceptionType.connectionError) {
              mappedException = NetworkConnectionException(apiError);
            } else {
              mappedException = BadRequestException(apiError);
            }
        }

        return handler.next(
          DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: mappedException,
          ),
        );
      },
    );
  }

  // ─── HTTP Helper Methods with Idempotency Support ─────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : e;
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    String? idempotencyKey,
  }) async {
    try {
      final effectiveOptions = options ?? Options();
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
        effectiveOptions.headers = {
          ...?effectiveOptions.headers,
          'Idempotency-Key': idempotencyKey,
        };
      }

      return await dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: effectiveOptions,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : e;
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : e;
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : e;
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : e;
    }
  }
}
