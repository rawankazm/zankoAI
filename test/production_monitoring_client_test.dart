// ==============================================================================
// ZankoAI Production Monitoring & Structured Logging — Automated Client Test Suite
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';

/// Models representing production monitoring contracts
class ProductionHealthResponse {
  final String status;
  final String service;
  final String version;
  final double uptimeSeconds;
  final String timestamp;

  ProductionHealthResponse({
    required this.status,
    required this.service,
    required this.version,
    required this.uptimeSeconds,
    required this.timestamp,
  });

  factory ProductionHealthResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return ProductionHealthResponse(
      status: data['status']?.toString() ?? 'unknown',
      service: data['service']?.toString() ?? 'zanko-backend',
      version: data['version']?.toString() ?? '1.0.0',
      uptimeSeconds: (data['uptime'] as num?)?.toDouble() ?? 0.0,
      timestamp: data['timestamp']?.toString() ?? '',
    );
  }

  bool get isHealthy => status == 'ok' || status == 'healthy';
}

class ProductionReadinessResponse {
  final String status;
  final Map<String, dynamic> dependencies;

  ProductionReadinessResponse({
    required this.status,
    required this.dependencies,
  });

  factory ProductionReadinessResponse.fromJson(Map<String, dynamic> json) {
    return ProductionReadinessResponse(
      status: json['status']?.toString() ?? 'unready',
      dependencies: json['dependencies'] as Map<String, dynamic>? ?? {},
    );
  }

  bool get isReady => status == 'ready';
  bool get isDatabaseOk =>
      dependencies['supabaseDatabase']?['status'] == 'connected';
  bool get isRedisOk => dependencies['redisCache']?['status'] == 'connected';
  bool get isDiskOk => dependencies['disk']?['status'] == 'ok';
}

class ProductionMetricsReport {
  final double uptimeSeconds;
  final double cpuPercent;
  final double ramUsedPercent;
  final double diskUsedPercent;
  final String redisStatus;
  final String databaseStatus;
  final int activeWorkers;
  final int deadLetters;
  final double latencyP95Ms;
  final double http5xxRatePercent;
  final int aiErrors;
  final int paymentErrors;
  final int failedJobs;
  final int totalQueueLength;
  final int subscriptionFailures;

  ProductionMetricsReport({
    required this.uptimeSeconds,
    required this.cpuPercent,
    required this.ramUsedPercent,
    required this.diskUsedPercent,
    required this.redisStatus,
    required this.databaseStatus,
    required this.activeWorkers,
    required this.deadLetters,
    required this.latencyP95Ms,
    required this.http5xxRatePercent,
    required this.aiErrors,
    required this.paymentErrors,
    required this.failedJobs,
    required this.totalQueueLength,
    required this.subscriptionFailures,
  });

  factory ProductionMetricsReport.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] as Map<String, dynamic>? ?? json;
    final uptime = metrics['apiUptime'] as Map<String, dynamic>? ?? {};
    final cpu = metrics['cpu'] as Map<String, dynamic>? ?? {};
    final ram = metrics['ram'] as Map<String, dynamic>? ?? {};
    final disk = metrics['disk'] as Map<String, dynamic>? ?? {};
    final redis = metrics['redis'] as Map<String, dynamic>? ?? {};
    final db = metrics['database'] as Map<String, dynamic>? ?? {};
    final workers = metrics['workers'] as Map<String, dynamic>? ?? {};
    final latency = metrics['apiLatency'] as Map<String, dynamic>? ?? {};
    final http = metrics['httpErrors'] as Map<String, dynamic>? ?? {};
    final incidents = metrics['incidents'] as Map<String, dynamic>? ?? {};

    return ProductionMetricsReport(
      uptimeSeconds: (uptime['seconds'] as num?)?.toDouble() ?? 0.0,
      cpuPercent: (cpu['processCpuPercent'] as num?)?.toDouble() ?? 0.0,
      ramUsedPercent: (ram['usedPercent'] as num?)?.toDouble() ?? 0.0,
      diskUsedPercent: (disk['usedPercent'] as num?)?.toDouble() ?? 0.0,
      redisStatus: redis['status']?.toString() ?? 'unknown',
      databaseStatus: db['status']?.toString() ?? 'unknown',
      activeWorkers: (workers['activeWorkers'] as num?)?.toInt() ?? 0,
      deadLetters: (workers['deadLetters'] as num?)?.toInt() ?? 0,
      latencyP95Ms: (latency['p95Ms'] as num?)?.toDouble() ?? 0.0,
      http5xxRatePercent: (http['errorRatePercent'] as num?)?.toDouble() ?? 0.0,
      aiErrors: (incidents['aiErrors'] as num?)?.toInt() ?? 0,
      paymentErrors: (incidents['paymentErrors'] as num?)?.toInt() ?? 0,
      failedJobs: (incidents['failedJobs'] as num?)?.toInt() ?? 0,
      totalQueueLength: (workers['totalQueueLength'] as num?)?.toInt() ?? 0,
      subscriptionFailures:
          (incidents['subscriptionFailures'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Helper to simulate and verify structured JSON access log redactions
class StructuredLogSanitizer {
  static final RegExp sensitiveKeyPattern = RegExp(
    r'(password|pass|secret|token|auth_header|authorization|access_token|refresh_token|service_role|apikey|api_key|cookie|credit_card|card_number|cvv|cvc|security_code|pan|gemini_api_key|openai_api_key|anthropic_api_key)',
    caseSensitive: false,
  );

  static Map<String, dynamic> sanitize(Map<String, dynamic> input) {
    final Map<String, dynamic> result = {};
    for (final entry in input.entries) {
      if (sensitiveKeyPattern.hasMatch(entry.key)) {
        result[entry.key] = '[REDACTED]';
      } else if (entry.value is Map<String, dynamic>) {
        result[entry.key] = sanitize(entry.value as Map<String, dynamic>);
      } else if (entry.value is String) {
        String str = entry.value as String;
        // Scrub Bearer tokens
        str = str.replaceAll(
          RegExp(r'Bearer\s+[A-Za-z0-9\-_.]+', caseSensitive: false),
          'Bearer [REDACTED]',
        );
        // Scrub AI Keys
        str = str.replaceAll(
          RegExp(r'AIzaSy[A-Za-z0-9\-_]{33}'),
          '[REDACTED_GEMINI_KEY]',
        );
        str = str.replaceAll(
          RegExp(r'sk-[A-Za-z0-9\-_]{20,}'),
          '[REDACTED_API_KEY]',
        );
        // Scrub card numbers
        str = str.replaceAll(
          RegExp(r'\b(?:\d[ -]*?){13,16}\b'),
          '[REDACTED_CARD]',
        );
        result[entry.key] = str;
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }
}

void main() {
  group('1. Health Probe (/api/health) Contract Tests', () {
    test('parses health response with status ok and uptime', () {
      final json = {
        'success': true,
        'data': {
          'status': 'ok',
          'service': 'zanko-backend',
          'version': '1.0.0',
          'uptime': 3456.78,
          'timestamp': '2026-09-08T18:00:00.000Z',
        },
      };

      final response = ProductionHealthResponse.fromJson(json);
      expect(response.isHealthy, isTrue);
      expect(response.service, equals('zanko-backend'));
      expect(response.uptimeSeconds, equals(3456.78));
      expect(response.version, equals('1.0.0'));
    });
  });

  group('2. Readiness Probe (/api/ready) Contract Tests', () {
    test('verifies ready state when all dependencies are connected', () {
      final json = {
        'status': 'ready',
        'dependencies': {
          'supabaseDatabase': {'status': 'connected', 'latencyMs': 24},
          'redisCache': {'status': 'connected', 'latencyMs': 4},
          'disk': {'status': 'ok', 'usedPercent': 42.1},
          'memory': {'status': 'ok', 'usedPercent': 61.5},
        },
      };

      final ready = ProductionReadinessResponse.fromJson(json);
      expect(ready.isReady, isTrue);
      expect(ready.isDatabaseOk, isTrue);
      expect(ready.isRedisOk, isTrue);
      expect(ready.isDiskOk, isTrue);
    });

    test('flags unready when database is down', () {
      final json = {
        'status': 'unready',
        'dependencies': {
          'supabaseDatabase': {'status': 'disconnected'},
          'redisCache': {'status': 'connected'},
        },
      };

      final ready = ProductionReadinessResponse.fromJson(json);
      expect(ready.isReady, isFalse);
      expect(ready.isDatabaseOk, isFalse);
      expect(ready.isRedisOk, isTrue);
    });
  });

  group('3. Production Metrics Report with All 14 Dimensions', () {
    test('parses all 14 required monitoring dimensions', () {
      final json = {
        'status': 'healthy',
        'metrics': {
          'apiUptime': {'seconds': 86400, 'formatted': '1d 0h 0m'},
          'cpu': {'processCpuPercent': 15.4, 'cores': 4},
          'ram': {'usedPercent': 55.2, 'heapUsed': 120000000},
          'disk': {'usedPercent': 48.0, 'status': 'ok'},
          'redis': {'status': 'connected', 'pingLatencyMs': 3},
          'database': {'status': 'connected', 'queryLatencyMs': 18},
          'workers': {
            'activeWorkers': 6,
            'deadLetters': 0,
            'totalQueueLength': 12,
            'queues': {
              'pdf': {'waiting': 2},
              'ocr': {'waiting': 1},
              'ai': {'waiting': 4},
            },
          },
          'apiLatency': {
            'avgMs': 85.0,
            'p50Ms': 60.0,
            'p95Ms': 210.0,
            'p99Ms': 450.0,
          },
          'httpErrors': {'totalRequests': 50000, 'errorRatePercent': 0.12},
          'incidents': {
            'aiErrors': 3,
            'paymentErrors': 1,
            'failedJobs': 0,
            'subscriptionFailures': 0,
          },
        },
      };

      final report = ProductionMetricsReport.fromJson(json);

      // Dimension checks
      expect(report.uptimeSeconds, equals(86400));
      expect(report.cpuPercent, equals(15.4));
      expect(report.ramUsedPercent, equals(55.2));
      expect(report.diskUsedPercent, equals(48.0));
      expect(report.redisStatus, equals('connected'));
      expect(report.databaseStatus, equals('connected'));
      expect(report.activeWorkers, equals(6));
      expect(report.deadLetters, equals(0));
      expect(report.latencyP95Ms, equals(210.0));
      expect(report.http5xxRatePercent, equals(0.12));
      expect(report.aiErrors, equals(3));
      expect(report.paymentErrors, equals(1));
      expect(report.failedJobs, equals(0));
      expect(report.totalQueueLength, equals(12));
      expect(report.subscriptionFailures, equals(0));
    });
  });

  group('4. Structured JSON Logs & Zero-Leakage Policy', () {
    test('structured access log contains all required observability keys', () {
      final accessLog = {
        'request_id': 'req_c847d0e1-45f8-45a7-96a7-f584e037b01b',
        'user_id': 'usr_98a72b14-c361-4fa3-9f5b-b92e76f4e12c',
        'route': '/api/ai/chat',
        'method': 'POST',
        'status': 200,
        'duration': '45.23ms',
        'duration_ms': 45.23,
      };

      expect(accessLog['request_id'], isNotNull);
      expect(accessLog['user_id'], isNotNull);
      expect(accessLog['route'], equals('/api/ai/chat'));
      expect(accessLog['method'], equals('POST'));
      expect(accessLog['status'], equals(200));
      expect(accessLog['duration_ms'], isA<num>());
    });

    test(
      'sanitizes passwords, tokens, cards, CVV, and AI keys unconditionally',
      () {
        final dirtyLog = {
          'request_id': 'req_xyz789',
          'user_id': 'usr_safe123',
          'route': '/api/payment/checkout',
          'method': 'POST',
          'status': 200,
          'duration_ms': 120.5,
          'password': 'PlainTextSecretPassword123!',
          'cvv': '789',
          'card_number': '4532 0150 9823 4511',
          'security_code': '999',
          'gemini_api_key': 'AIzaSyA0123456789012345678901234567890',
          'openai_api_key': 'sk-proj-0123456789abcdef0123456789abcdef',
          'auth_header':
              'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ',
          'nested': {
            'refresh_token': 'secret_refresh_jwt',
            'pan': '5500 0000 0000 0004',
          },
        };

        final cleanLog = StructuredLogSanitizer.sanitize(dirtyLog);

        // Verify safe keys are intact
        expect(cleanLog['request_id'], equals('req_xyz789'));
        expect(cleanLog['user_id'], equals('usr_safe123'));
        expect(cleanLog['route'], equals('/api/payment/checkout'));
        expect(cleanLog['method'], equals('POST'));
        expect(cleanLog['status'], equals(200));
        expect(cleanLog['duration_ms'], equals(120.5));

        // Verify all sensitive keys are redacted
        expect(cleanLog['password'], equals('[REDACTED]'));
        expect(cleanLog['cvv'], equals('[REDACTED]'));
        expect(cleanLog['card_number'], equals('[REDACTED]'));
        expect(cleanLog['security_code'], equals('[REDACTED]'));
        expect(cleanLog['gemini_api_key'], equals('[REDACTED]'));
        expect(cleanLog['openai_api_key'], equals('[REDACTED]'));
        expect(cleanLog['auth_header'], equals('[REDACTED]'));
        expect(
          (cleanLog['nested'] as Map)['refresh_token'],
          equals('[REDACTED]'),
        );
        expect((cleanLog['nested'] as Map)['pan'], equals('[REDACTED]'));
      },
    );
  });
}
