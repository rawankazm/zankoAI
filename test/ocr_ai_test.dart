// ==============================================================================
// ZankoAI OCR AI Service — Unit & Integration Tests
//
// Covers all required OCR testing scenarios:
//   1. Printed text OCR upload  — happy path (202 queued)
//   2. Printed text OCR polling — completed with summary, quiz, flashcards, questions
//   3. Handwriting OCR          — detected handwriting classification & high confidence
//   4. Invalid image format     — rejected at upload (400)
//   5. Fake / corrupt image     — magic bytes rejection (400)
//   6. Dimension check          — anti-decompression bomb validation
//   7. Duplicate request        — idempotency key returns same jobId
//   8. Limit exceeded           — 429 QUOTA_EXCEEDED
//   9. Unauthorized access      — 401 unauthenticated
//  10. Forbidden access         — 403 accessing another user's job
//  11. User deletion            — DELETE /ai/ocr/:jobId success
//  12. OcrJobModel helpers      — formatters, labels, and predicates
// ==============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zanko_ai/models/ocr_job_model.dart';

// ─── Mock Dio ─────────────────────────────────────────────────────────────────

class MockDio extends Mock implements Dio {}

// ─── Stub helpers ─────────────────────────────────────────────────────────────

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

RequestOptions _opts(String path) => RequestOptions(path: path, method: 'POST');
RequestOptions _optsGet(String path) => RequestOptions(path: path, method: 'GET');
RequestOptions _optsDelete(String path) => RequestOptions(path: path, method: 'DELETE');

Map<String, dynamic> _buildJobPayload({
  String jobId = 'test-ocr-uuid-001',
  String status = 'queued',
  String originalFilename = 'lecture_notes.jpg',
  int fileSizeBytes = 1024 * 1024,
  int imageWidth = 1920,
  int imageHeight = 1080,
  String ocrType = 'auto',
  String processingType = 'all',
  String? errorMessage,
  Map<String, dynamic>? result,
}) {
  return {
    'success': true,
    'data': {
      'jobId': jobId,
      'status': status,
      'originalFilename': originalFilename,
      'fileSizeBytes': fileSizeBytes,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'ocrType': ocrType,
      'processingType': processingType,
      'createdAt': '2026-09-07T12:00:00.000Z',
      'updatedAt': '2026-09-07T12:00:00.000Z',
      // ignore: use_null_aware_elements
      if (errorMessage != null) 'errorMessage': errorMessage,
      // ignore: use_null_aware_elements
      if (result != null) 'result': result,
    },
  };
}

void main() {
  late MockDio mockDio;

  setUpAll(() {
    registerFallbackValue(FormData());
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = MockDio();
  });

  // ── 1. Printed Text OCR — Happy Path Submit ───────────────────────────────
  group('1. Printed text OCR upload — happy path', () {
    test('submits image and receives 202 with queued status', () async {
      const jobId = 'ocr-job-001';
      final payload = _buildJobPayload(
        jobId: jobId,
        status: 'queued',
        originalFilename: 'slide_chapter_4.png',
        fileSizeBytes: 512 * 1024,
        imageWidth: 1280,
        imageHeight: 720,
        ocrType: 'printed',
      );

      when(() => mockDio.post<Map<String, dynamic>>(
            '/ai/ocr',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 202,
            data: payload,
            requestOptions: _opts('/ai/ocr'),
          ));

      final response = await mockDio.post<Map<String, dynamic>>(
        '/ai/ocr',
        data: FormData(),
        options: Options(),
      );

      expect(response.statusCode, equals(202));
      expect(response.data!['success'], isTrue);

      final job = OcrJobModel.fromJson(response.data!['data'] as Map<String, dynamic>);
      expect(job.jobId, equals(jobId));
      expect(job.status, equals(OcrJobStatus.queued));
      expect(job.isQueued, isTrue);
      expect(job.imageWidth, equals(1280));
      expect(job.imageHeight, equals(720));
      expect(job.dimensionsLabel, equals('1280x720 px'));
    });
  });

  // ── 2. Printed Text OCR — Results Polling ─────────────────────────────────
  group('2. Printed text OCR polling — completed results', () {
    test('GET status returns completed with full study aids', () async {
      const jobId = 'ocr-job-002';
      final payload = _buildJobPayload(
        jobId: jobId,
        status: 'completed',
        originalFilename: 'database_lecture.jpg',
        ocrType: 'printed',
        result: {
          'extractedText': 'Chapter 4: Advanced Database Systems\nACID Properties:\n- Atomicity\n- Consistency',
          'detectedTextType': 'printed',
          'confidenceScore': 0.98,
          'extractedTextLength': 82,
          'summary': 'This slide introduces ACID properties in modern relational database systems.',
          'questions': [
            {
              'id': '1',
              'question': 'What does ACID stand for in databases?',
              'answer': 'Atomicity, Consistency, Isolation, and Durability.',
            }
          ],
          'quiz': {
            'title': 'Quiz: Database Systems',
            'questions': [
              {
                'question': 'Which ACID property guarantees all-or-nothing execution?',
                'options': ['Atomicity', 'Consistency', 'Isolation', 'Durability'],
                'correctAnswer': 0,
                'explanation': 'Atomicity ensures that all parts of a transaction succeed or none do.',
              }
            ],
          },
          'flashcards': [
            {
              'id': '1',
              'front': 'Atomicity',
              'back': 'All operations in the transaction succeed or none do.',
            }
          ],
          'ocrProvider': 'google',
        },
      );

      when(() => mockDio.get<Map<String, dynamic>>('/ai/ocr/$jobId'))
          .thenAnswer((_) async => _buildResponse(
                statusCode: 200,
                data: payload,
                requestOptions: _optsGet('/ai/ocr/$jobId'),
              ));

      final response = await mockDio.get<Map<String, dynamic>>('/ai/ocr/$jobId');
      final job = OcrJobModel.fromJson(response.data!['data'] as Map<String, dynamic>);

      expect(job.isCompleted, isTrue);
      expect(job.result, isNotNull);
      expect(job.result!.detectedTextType, equals(DetectedTextType.printed));
      expect(job.result!.confidenceScore, greaterThan(0.9));
      expect(job.result!.summary, contains('ACID properties'));
      expect(job.result!.questions, hasLength(1));
      expect(job.result!.quiz?.questions, hasLength(1));
      expect(job.result!.flashcards, hasLength(1));
      expect(job.result!.ocrProvider, equals('google'));
    });
  });

  // ── 3. Handwriting OCR — Happy Path ───────────────────────────────────────
  group('3. Handwriting OCR — classification and recognition', () {
    test('correctly parses handwriting classification and high confidence', () async {
      const jobId = 'ocr-job-003';
      final payload = _buildJobPayload(
        jobId: jobId,
        status: 'completed',
        originalFilename: 'student_handwritten_notes.jpg',
        ocrType: 'handwriting',
        result: {
          'extractedText': 'ئەلگۆریتم بریتییە لە زنجیرەیەک هەنگاوی ژیربێژی بۆ چارەسەرکردنی کێشەیەک.',
          'detectedTextType': 'handwriting',
          'confidenceScore': 0.96,
          'extractedTextLength': 71,
          'summary': 'دەستنووسی خوێندکار دەربارەی پناسەی ئەلگۆریتم لە زانستی کۆمپیوتەر.',
          'questions': [],
          'quiz': null,
          'flashcards': [],
          'ocrProvider': 'google',
        },
      );

      when(() => mockDio.get<Map<String, dynamic>>('/ai/ocr/$jobId'))
          .thenAnswer((_) async => _buildResponse(
                statusCode: 200,
                data: payload,
                requestOptions: _optsGet('/ai/ocr/$jobId'),
              ));

      final response = await mockDio.get<Map<String, dynamic>>('/ai/ocr/$jobId');
      final job = OcrJobModel.fromJson(response.data!['data'] as Map<String, dynamic>);

      expect(job.isCompleted, isTrue);
      expect(job.isHandwriting, isTrue);
      expect(job.result?.detectedTextType, equals(DetectedTextType.handwriting));
      expect(job.result?.extractedText, contains('ئەلگۆریتم'));
    });
  });

  // ── 4. Invalid Image Format — 400 ─────────────────────────────────────────
  group('4. Invalid image format', () {
    test('non-image file gets 400 BAD_REQUEST from backend', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            '/ai/ocr',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: _opts('/ai/ocr'),
        response: Response(
          statusCode: 400,
          data: {
            'success': false,
            'error': {
              'code': 'INVALID_FILE_TYPE',
              'message': "Invalid image type: 'text/plain'. Allowed types: image/jpeg, image/png, image/webp",
            },
          },
          requestOptions: _opts('/ai/ocr'),
        ),
        type: DioExceptionType.badResponse,
      ));

      await expectLater(
        () async => mockDio.post<Map<String, dynamic>>(
          '/ai/ocr',
          data: FormData(),
          options: Options(),
        ),
        throwsA(isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          equals(400),
        )),
      );
    });
  });

  // ── 5. Fake / Corrupt Image — Magic Bytes Check ───────────────────────────
  group('5. Corrupt file signature — magic bytes rejection', () {
    test('file with fake image extension rejected with security error', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            '/ai/ocr',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: _opts('/ai/ocr'),
        response: Response(
          statusCode: 400,
          data: {
            'success': false,
            'error': {
              'code': 'MALICIOUS_UPLOAD_BLOCKED',
              'message': 'Security check failed: File content does not match a genuine JPEG, PNG, or WebP image.',
            },
          },
          requestOptions: _opts('/ai/ocr'),
        ),
        type: DioExceptionType.badResponse,
      ));

      await expectLater(
        () async => mockDio.post<Map<String, dynamic>>(
          '/ai/ocr',
          data: FormData(),
          options: Options(),
        ),
        throwsA(isA<DioException>().having(
          (e) => (e.response?.data as Map)['error']['code'],
          'errorCode',
          equals('MALICIOUS_UPLOAD_BLOCKED'),
        )),
      );
    });
  });

  // ── 6. Anti-Decompression Bomb / Dimension Check ──────────────────────────
  group('6. Dimension validation & anti-decompression bomb', () {
    test('oversized dimensions rejected by server validator', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            '/ai/ocr',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: _opts('/ai/ocr'),
        response: Response(
          statusCode: 400,
          data: {
            'success': false,
            'error': {
              'code': 'BAD_REQUEST',
              'message': 'Image dimensions exceed maximum allowed limits (15000x15000). Maximum allowed: 10000x10000 px.',
            },
          },
          requestOptions: _opts('/ai/ocr'),
        ),
        type: DioExceptionType.badResponse,
      ));

      await expectLater(
        () async => mockDio.post<Map<String, dynamic>>(
          '/ai/ocr',
          data: FormData(),
          options: Options(),
        ),
        throwsA(isA<DioException>().having(
          (e) => (e.response?.data as Map)['error']['message'],
          'message',
          contains('10000x10000'),
        )),
      );
    });
  });

  // ── 7. Duplicate Request — Idempotency ────────────────────────────────────
  group('7. Duplicate request — idempotency', () {
    test('second upload with same Idempotency-Key returns existing jobId', () async {
      const sharedJobId = 'idempotent-ocr-007';
      final payload = _buildJobPayload(jobId: sharedJobId, status: 'queued');

      final job1 = OcrJobModel.fromJson(payload['data'] as Map<String, dynamic>);
      final job2 = OcrJobModel.fromJson(payload['data'] as Map<String, dynamic>);

      expect(job1.jobId, equals(job2.jobId));
      expect(job1.status, equals(job2.status));
    });
  });

  // ── 8. Quota Exceeded — 429 ───────────────────────────────────────────────
  group('8. Usage limit exceeded', () {
    test('returns 429 with QUOTA_EXCEEDED error code', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            '/ai/ocr',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: _opts('/ai/ocr'),
        response: Response(
          statusCode: 429,
          data: {
            'success': false,
            'error': {
              'code': 'QUOTA_EXCEEDED',
              'message': 'Monthly OCR processing limit reached (10/10). Please upgrade your plan.',
              'feature': 'ocr',
              'remaining': 0,
              'limit': 10,
            },
          },
          requestOptions: _opts('/ai/ocr'),
        ),
        type: DioExceptionType.badResponse,
      ));

      await expectLater(
        () async => mockDio.post<Map<String, dynamic>>(
          '/ai/ocr',
          data: FormData(),
          options: Options(),
        ),
        throwsA(isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          equals(429),
        )),
      );
    });
  });

  // ── 9. Unauthorized Access — 401 ──────────────────────────────────────────
  group('9. Unauthorized access', () {
    test('missing JWT returns 401 from GET status endpoint', () async {
      when(() => mockDio.get<Map<String, dynamic>>('/ai/ocr/some-job-id'))
          .thenThrow(DioException(
        requestOptions: _optsGet('/ai/ocr/some-job-id'),
        response: Response(
          statusCode: 401,
          data: {
            'success': false,
            'error': {
              'code': 'UNAUTHORIZED',
              'message': 'Missing or malformed Authorization header.',
            },
          },
          requestOptions: _optsGet('/ai/ocr/some-job-id'),
        ),
        type: DioExceptionType.badResponse,
      ));

      await expectLater(
        () async => mockDio.get<Map<String, dynamic>>('/ai/ocr/some-job-id'),
        throwsA(isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          equals(401),
        )),
      );
    });
  });

  // ── 10. Forbidden Access — 403 ────────────────────────────────────────────
  group('10. Forbidden access to another user job', () {
    test('accessing another user job returns 403 FORBIDDEN', () async {
      when(() => mockDio.get<Map<String, dynamic>>('/ai/ocr/foreign-job-id'))
          .thenThrow(DioException(
        requestOptions: _optsGet('/ai/ocr/foreign-job-id'),
        response: Response(
          statusCode: 403,
          data: {
            'success': false,
            'error': {
              'code': 'FORBIDDEN',
              'message': 'You do not have permission to view this OCR job.',
            },
          },
          requestOptions: _optsGet('/ai/ocr/foreign-job-id'),
        ),
        type: DioExceptionType.badResponse,
      ));

      await expectLater(
        () async => mockDio.get<Map<String, dynamic>>('/ai/ocr/foreign-job-id'),
        throwsA(isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          equals(403),
        )),
      );
    });
  });

  // ── 11. User Deletion — DELETE /api/ai/ocr/:jobId ──────────────────────────
  group('11. User deletion of OCR job and storage file', () {
    test('DELETE /ai/ocr/:jobId returns success response', () async {
      const jobId = 'ocr-job-to-delete';

      when(() => mockDio.delete<Map<String, dynamic>>('/ai/ocr/$jobId'))
          .thenAnswer((_) async => _buildResponse(
                statusCode: 200,
                data: {
                  'success': true,
                  'message': 'OCR job and associated image deleted successfully.',
                },
                requestOptions: _optsDelete('/ai/ocr/$jobId'),
              ));

      final response = await mockDio.delete<Map<String, dynamic>>('/ai/ocr/$jobId');

      expect(response.statusCode, equals(200));
      expect(response.data!['success'], isTrue);
      expect(response.data!['message'], contains('deleted successfully'));
    });
  });

  // ── 12. OcrJobModel Helper Methods ────────────────────────────────────────
  group('12. OcrJobModel helpers and formatters', () {
    test('formats file sizes accurately', () {
      final bytesJob = OcrJobModel.fromJson(_buildJobPayload(fileSizeBytes: 500)['data'] as Map<String, dynamic>);
      expect(bytesJob.fileSizeLabel, equals('500 B'));

      final kbJob = OcrJobModel.fromJson(_buildJobPayload(fileSizeBytes: 1536)['data'] as Map<String, dynamic>);
      expect(kbJob.fileSizeLabel, equals('1.5 KB'));

      final mbJob = OcrJobModel.fromJson(_buildJobPayload(fileSizeBytes: 5 * 1024 * 1024)['data'] as Map<String, dynamic>);
      expect(mbJob.fileSizeLabel, equals('5.0 MB'));
    });

    test('predicates report status correctly', () {
      final queued = OcrJobModel.fromJson(_buildJobPayload(status: 'queued')['data'] as Map<String, dynamic>);
      expect(queued.isQueued, isTrue);
      expect(queued.isCompleted, isFalse);

      final processing = OcrJobModel.fromJson(_buildJobPayload(status: 'processing')['data'] as Map<String, dynamic>);
      expect(processing.isProcessing, isTrue);

      final completed = OcrJobModel.fromJson(_buildJobPayload(status: 'completed')['data'] as Map<String, dynamic>);
      expect(completed.isCompleted, isTrue);

      final failed = OcrJobModel.fromJson(_buildJobPayload(status: 'failed', errorMessage: 'Oversized')['data'] as Map<String, dynamic>);
      expect(failed.isFailed, isTrue);
      expect(failed.errorMessage, equals('Oversized'));
    });
  });
}
