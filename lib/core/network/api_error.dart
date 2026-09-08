import 'package:dio/dio.dart';

/// Standardized API Error model representing backend and transport failures.
class ApiError {
  final int statusCode;
  final String message;
  final String? errorCode;
  final dynamic details;
  final DateTime timestamp;

  const ApiError({
    required this.statusCode,
    required this.message,
    this.errorCode,
    this.details,
    required this.timestamp,
  });

  factory ApiError.fromJson(Map<String, dynamic> json, int statusCode) {
    return ApiError(
      statusCode: statusCode,
      message:
          json['message']?.toString() ??
          json['error']?.toString() ??
          _defaultMessageForStatus(statusCode),
      errorCode: json['code']?.toString() ?? json['errorCode']?.toString(),
      details: json['details'] ?? json['data'],
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  factory ApiError.fromDioException(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode ?? 0;

    if (response?.data is Map<String, dynamic>) {
      return ApiError.fromJson(
        response!.data as Map<String, dynamic>,
        statusCode,
      );
    }

    String message;
    String? code;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message =
            'داواکارییەکە کاتی بەسەرچوو، تکایە هێڵی ئینتەرنێتەکەت بپشکنە.';
        code = 'TIMEOUT';
        break;
      case DioExceptionType.connectionError:
        message =
            'پەیوەندی بە سێرڤەرەوە پچڕا، تکایە دڵنیابە لە هەبوونی ئینتەرنێت.';
        code = 'NETWORK_ERROR';
        break;
      case DioExceptionType.badResponse:
        message = _defaultMessageForStatus(statusCode);
        code = 'HTTP_$statusCode';
        break;
      case DioExceptionType.cancel:
        message = 'داواکارییەکە هەڵوەشێنرایەوە.';
        code = 'REQUEST_CANCELLED';
        break;
      default:
        message = error.message ?? 'هەڵەیەکی نەزانراو لە پەیوەندیکردن ڕوویدا.';
        code = 'UNKNOWN_ERROR';
        break;
    }

    return ApiError(
      statusCode: statusCode,
      message: message,
      errorCode: code,
      details: response?.data,
      timestamp: DateTime.now(),
    );
  }

  static String _defaultMessageForStatus(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'داواکاری نادروستە، تکایە زانیارییەکان بپشکنە.';
      case 401:
        return 'دانیشتنەکەت بەسەرچووە، تکایە دووبارە بچۆ ژوورەوە.';
      case 403:
        return 'دەسەڵاتی ئەنجامدانی ئەم کردارەت نییە.';
      case 404:
        return 'ئەو زانیارییەی داوات کردووە نەدۆزرایەوە.';
      case 409:
        return 'ناکۆکی لە زانیارییەکاندا هەیە (داتای دووبارە).';
      case 429:
        return 'ژمارەی داواکارییەکان لە سنوور تێپەڕیوە، کەمێکی تر هەوڵبدەرەوە.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'سێرڤەر لەم کاتەدا بەردەست نییە، کەمێکی تر هەوڵبدەرەوە.';
      default:
        return 'هەڵەیەک لە سێرڤەرەوە گەڕایەوە ($statusCode).';
    }
  }

  @override
  String toString() =>
      'ApiError(status: $statusCode, code: $errorCode, message: $message)';
}

/// Strongly typed domain exception base class.
abstract class ApiException implements Exception {
  final ApiError error;
  const ApiException(this.error);

  int get statusCode => error.statusCode;
  String get message => error.message;
  String? get errorCode => error.errorCode;

  @override
  String toString() => error.toString();
}

class BadRequestException extends ApiException {
  const BadRequestException(super.error);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.error);
}

class ForbiddenException extends ApiException {
  const ForbiddenException(super.error);
}

class NotFoundException extends ApiException {
  const NotFoundException(super.error);
}

class ConflictException extends ApiException {
  const ConflictException(super.error);
}

class QuotaExceededException extends ApiException {
  final Duration? retryAfter;
  const QuotaExceededException(super.error, {this.retryAfter});
}

class RateLimitException extends ApiException {
  final Duration? retryAfter;
  const RateLimitException(super.error, {this.retryAfter});
}

class ServerException extends ApiException {
  const ServerException(super.error);
}

class NetworkConnectionException extends ApiException {
  const NetworkConnectionException(super.error);
}

class TimeoutException extends ApiException {
  const TimeoutException(super.error);
}

class SecurityViolationException extends ApiException {
  SecurityViolationException(String reason)
    : super(
        ApiError(
          statusCode: 400,
          message: 'ڕێگری لە دزەکردنی نهێنییەکان کرا: $reason',
          errorCode: 'SECURITY_LEAK_PREVENTED',
          timestamp: DateTime.now(),
        ),
      );
}
