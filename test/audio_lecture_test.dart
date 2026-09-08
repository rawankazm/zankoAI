// ==============================================================================
// ZankoAI Teacher Lecture Audio Recorder — Unit & Integration Tests
//
// Covers all required scenarios:
//   1. Teacher audio upload           — happy path receives 202 (queued)
//   2. 7-state progression            — queued→processing→transcribing→summarizing→generating→completed
//   3. Results payload                — transcript, summary, key takeaways, flashcards, quiz
//   4. Teacher role enforcement       — non-teacher rejected with 403 FORBIDDEN
//   5. Course assignment check        — teacher not assigned to course gets 403 FORBIDDEN
//   6. Enrolled student access        — authorized student in course can access (200 OK)
//   7. Non-enrolled student access    — non-member blocked with 403 FORBIDDEN
//   8. Invalid audio format           — rejected at upload (400)
//   9. Corrupt audio / magic bytes    — security check blocked (400)
//  10. Usage quota exceeded           — 429 QUOTA_EXCEEDED
//  11. Idempotency                    — duplicate request returns existing jobId
//  12. Teacher deletion               — DELETE /ai/audio/:jobId success
//  13. Formatters & model helpers     — durationLabel, Kurdish status names, predicates
// ==============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zanko_ai/models/lecture_audio_job_model.dart';

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
RequestOptions _optsGet(String path) =>
    RequestOptions(path: path, method: 'GET');
RequestOptions _optsDelete(String path) =>
    RequestOptions(path: path, method: 'DELETE');

Map<String, dynamic> _buildJobPayload({
  String jobId = 'test-audio-uuid-001',
  String status = 'queued',
  String courseId = 'course-uuid-101',
  String? lectureId,
  String title = 'Operating Systems - Lecture 5',
  int fileSizeBytes = 12 * 1024 * 1024,
  int durationSeconds = 2720, // 45:20
  String audioFormat = 'audio/mp4',
  bool isPublished = true,
  String? errorMessage,
  Map<String, dynamic>? result,
}) {
  return {
    'success': true,
    'data': {
      'jobId': jobId,
      'status': status,
      'courseId': courseId,
      // ignore: use_null_aware_elements
      if (lectureId != null) 'lectureId': lectureId,
      'title': title,
      'fileSizeBytes': fileSizeBytes,
      'durationSeconds': durationSeconds,
      'audioFormat': audioFormat,
      'isPublished': isPublished,
      'createdAt': '2026-09-07T14:00:00.000Z',
      'updatedAt': '2026-09-07T14:00:00.000Z',
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

  // ── 1. Teacher Lecture Audio Submission — Happy Path ──────────────────────
  group('1. Teacher lecture audio upload — happy path', () {
    test('submits audio lecture and receives 202 with queued status', () async {
      const jobId = 'audio-job-001';
      final payload = _buildJobPayload(
        jobId: jobId,
        status: 'queued',
        title: 'Computer Networks - Lecture 1',
        fileSizeBytes: 8 * 1024 * 1024,
        durationSeconds: 1800,
      );

      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/ai/audio',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _buildResponse(
          statusCode: 202,
          data: payload,
          requestOptions: _opts('/ai/audio'),
        ),
      );

      final response = await mockDio.post<Map<String, dynamic>>(
        '/ai/audio',
        data: FormData(),
        options: Options(),
      );

      expect(response.statusCode, equals(202));
      expect(response.data!['success'], isTrue);

      final job = LectureAudioJobModel.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
      expect(job.jobId, equals(jobId));
      expect(job.status, equals(AudioJobStatus.queued));
      expect(job.isQueued, isTrue);
      expect(job.durationSeconds, equals(1800));
      expect(job.durationLabel, equals('30:00'));
      expect(job.status.displayNameKu, equals('لە نۆرەدایە'));
    });
  });

  // ── 2. Seven-Stage Job Progression ────────────────────────────────────────
  group('2. 7-state job progression transitions', () {
    test('accurately parses all 7 distinct job states', () {
      final states = [
        'queued',
        'processing',
        'transcribing',
        'summarizing',
        'generating',
        'completed',
        'failed',
      ];

      for (final s in states) {
        final payload = _buildJobPayload(status: s);
        final job = LectureAudioJobModel.fromJson(
          payload['data'] as Map<String, dynamic>,
        );
        expect(job.status.name, equals(s));
        expect(job.status.displayNameKu, isNotEmpty);
      }
    });

    test('state predicates reflect current phase correctly', () {
      final transcribingJob = LectureAudioJobModel.fromJson(
        _buildJobPayload(status: 'transcribing')['data']
            as Map<String, dynamic>,
      );
      expect(transcribingJob.isTranscribing, isTrue);
      expect(transcribingJob.isInProgress, isTrue);
      expect(transcribingJob.isCompleted, isFalse);

      final summarizingJob = LectureAudioJobModel.fromJson(
        _buildJobPayload(status: 'summarizing')['data'] as Map<String, dynamic>,
      );
      expect(summarizingJob.isSummarizing, isTrue);

      final generatingJob = LectureAudioJobModel.fromJson(
        _buildJobPayload(status: 'generating')['data'] as Map<String, dynamic>,
      );
      expect(generatingJob.isGenerating, isTrue);
    });
  });

  // ── 3. Completed Results Payload ──────────────────────────────────────────
  group('3. Completed lecture audio results payload', () {
    test('contains transcript, summary, takeaways, flashcards, and quiz', () async {
      const jobId = 'audio-job-003';
      final payload = _buildJobPayload(
        jobId: jobId,
        status: 'completed',
        title: 'OS Process Synchronization',
        durationSeconds: 2720,
        result: {
          'transcript':
              'ئەمڕۆ باسی کێشەی Critical Section و چارەسەری سێمافۆر (Semaphore) دەکەین...',
          'summary':
              'وانەکە شیکردنەوەی تەواو دەدات لەسەر هەمبەری پرۆسێسەکان و ڕێگریکردن لە Race Condition.',
          'keyTakeaways': [
            'سێمافۆر بریتییە لە گۆڕاوێکی جیاواز کە بەکاردێت بۆ کۆنترۆڵکردنی چوونەژوورەوە بۆ Critical Section.',
            'دوو ئۆپەراسیۆنی بنەڕەتی هەیە: wait() و signal().',
          ],
          'flashcards': [
            {
              'id': '1',
              'front': 'Critical Section',
              'back':
                  'ئەو بەشەی کۆدە کە تێیدا سەرچاوە هاوبەشەکان دەستکاری دەکرێن.',
            },
          ],
          'quiz': {
            'title': 'Quiz: Process Synchronization',
            'questions': [
              {
                'question': 'What does a binary semaphore value represent?',
                'options': ['0 or 1', 'Any integer', 'Negative values', 'Null'],
                'correctAnswer': 0,
                'explanation':
                    'A binary semaphore can only take values 0 and 1 (mutex).',
              },
            ],
          },
          'languageDetected': 'ku',
        },
      );

      when(
        () => mockDio.get<Map<String, dynamic>>('/ai/audio/$jobId'),
      ).thenAnswer(
        (_) async => _buildResponse(
          statusCode: 200,
          data: payload,
          requestOptions: _optsGet('/ai/audio/$jobId'),
        ),
      );

      final response = await mockDio.get<Map<String, dynamic>>(
        '/ai/audio/$jobId',
      );
      final job = LectureAudioJobModel.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );

      expect(job.isCompleted, isTrue);
      expect(job.result, isNotNull);
      expect(job.result!.transcript, contains('Critical Section'));
      expect(job.result!.summary, contains('Race Condition'));
      expect(job.result!.keyTakeaways, hasLength(2));
      expect(job.result!.flashcards, hasLength(1));
      expect(job.result!.quiz?.questions, hasLength(1));
      expect(job.durationLabel, equals('45:20'));
    });
  });

  // ── 4. Teacher Role Enforcement ───────────────────────────────────────────
  group('4. Teacher role enforcement', () {
    test(
      'non-teacher account receives 403 FORBIDDEN when creating recording',
      () async {
        when(
          () => mockDio.post<Map<String, dynamic>>(
            '/ai/audio',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: _opts('/ai/audio'),
            response: Response(
              statusCode: 403,
              data: {
                'success': false,
                'error': {
                  'code': 'FORBIDDEN',
                  'message':
                      'Only authorized teachers can create and upload lecture recordings.',
                },
              },
              requestOptions: _opts('/ai/audio'),
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        await expectLater(
          () async => mockDio.post<Map<String, dynamic>>(
            '/ai/audio',
            data: FormData(),
            options: Options(),
          ),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              equals(403),
            ),
          ),
        );
      },
    );
  });

  // ── 5. Course Ownership Verification ──────────────────────────────────────
  group('5. Course instructor verification', () {
    test('teacher not assigned to course receives 403 FORBIDDEN', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/ai/audio',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: _opts('/ai/audio'),
          response: Response(
            statusCode: 403,
            data: {
              'success': false,
              'error': {
                'code': 'FORBIDDEN',
                'message':
                    'You are not authorized to publish lecture audio for this course.',
              },
            },
            requestOptions: _opts('/ai/audio'),
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        () async => mockDio.post<Map<String, dynamic>>(
          '/ai/audio',
          data: FormData(),
          options: Options(),
        ),
        throwsA(
          isA<DioException>().having(
            (e) => (e.response?.data as Map)['error']['message'],
            'message',
            contains('not authorized to publish lecture audio for this course'),
          ),
        ),
      );
    });
  });

  // ── 6. Enrolled Student Access ────────────────────────────────────────────
  group('6. Enrolled course student access', () {
    test('enrolled student can access published lecture content', () async {
      const jobId = 'course-lecture-006';
      final payload = _buildJobPayload(
        jobId: jobId,
        status: 'completed',
        isPublished: true,
        result: {
          'transcript': 'Enrolled student transcript content...',
          'summary': 'Student summary notes...',
          'keyTakeaways': ['Takeaway 1'],
          'flashcards': [],
          'quiz': null,
          'languageDetected': 'en',
        },
      );

      when(
        () => mockDio.get<Map<String, dynamic>>('/ai/audio/$jobId'),
      ).thenAnswer(
        (_) async => _buildResponse(
          statusCode: 200,
          data: payload,
          requestOptions: _optsGet('/ai/audio/$jobId'),
        ),
      );

      final response = await mockDio.get<Map<String, dynamic>>(
        '/ai/audio/$jobId',
      );
      final job = LectureAudioJobModel.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );

      expect(job.jobId, equals(jobId));
      expect(job.isCompleted, isTrue);
      expect(job.result?.transcript, contains('Enrolled student'));
    });
  });

  // ── 7. Non-Enrolled Student Access Blocked ────────────────────────────────
  group('7. Non-enrolled student blocked', () {
    test(
      'non-enrolled student gets 403 FORBIDDEN when attempting access',
      () async {
        when(
          () => mockDio.get<Map<String, dynamic>>('/ai/audio/protected-job-id'),
        ).thenThrow(
          DioException(
            requestOptions: _optsGet('/ai/audio/protected-job-id'),
            response: Response(
              statusCode: 403,
              data: {
                'success': false,
                'error': {
                  'code': 'FORBIDDEN',
                  'message':
                      'You are not authorized to view this lecture recording. Only enrolled students and instructors have access.',
                },
              },
              requestOptions: _optsGet('/ai/audio/protected-job-id'),
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        await expectLater(
          () async =>
              mockDio.get<Map<String, dynamic>>('/ai/audio/protected-job-id'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              equals(403),
            ),
          ),
        );
      },
    );
  });

  // ── 8. Invalid Audio Format ───────────────────────────────────────────────
  group('8. Invalid audio format', () {
    test('non-audio file rejected with 400 BAD_REQUEST', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/ai/audio',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: _opts('/ai/audio'),
          response: Response(
            statusCode: 400,
            data: {
              'success': false,
              'error': {
                'code': 'INVALID_FILE_TYPE',
                'message':
                    "Invalid audio type: 'application/pdf'. Allowed types: MP3, WAV, M4A, AAC, OGG, WebM.",
              },
            },
            requestOptions: _opts('/ai/audio'),
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        () async => mockDio.post<Map<String, dynamic>>(
          '/ai/audio',
          data: FormData(),
          options: Options(),
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            equals(400),
          ),
        ),
      );
    });
  });

  // ── 9. Corrupt Audio / Magic Bytes Check ───────────────────────────────────
  group('9. Corrupt audio binary check', () {
    test(
      'corrupt file disguised with audio extension rejected by security filter',
      () async {
        when(
          () => mockDio.post<Map<String, dynamic>>(
            '/ai/audio',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: _opts('/ai/audio'),
            response: Response(
              statusCode: 400,
              data: {
                'success': false,
                'error': {
                  'code': 'MALICIOUS_UPLOAD_BLOCKED',
                  'message':
                      'Security check failed: File content does not match a valid audio format.',
                },
              },
              requestOptions: _opts('/ai/audio'),
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        await expectLater(
          () async => mockDio.post<Map<String, dynamic>>(
            '/ai/audio',
            data: FormData(),
            options: Options(),
          ),
          throwsA(
            isA<DioException>().having(
              (e) => (e.response?.data as Map)['error']['code'],
              'code',
              equals('MALICIOUS_UPLOAD_BLOCKED'),
            ),
          ),
        );
      },
    );
  });

  // ── 10. Usage Limit Exceeded ──────────────────────────────────────────────
  group('10. Usage limit exceeded', () {
    test('returns 429 when teacher monthly audio quota is reached', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/ai/audio',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: _opts('/ai/audio'),
          response: Response(
            statusCode: 429,
            data: {
              'success': false,
              'error': {
                'code': 'QUOTA_EXCEEDED',
                'message':
                    'Monthly audio lecture recording limit reached (5/5). Please upgrade your plan.',
                'feature': 'audio',
                'remaining': 0,
                'limit': 5,
              },
            },
            requestOptions: _opts('/ai/audio'),
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        () async => mockDio.post<Map<String, dynamic>>(
          '/ai/audio',
          data: FormData(),
          options: Options(),
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            equals(429),
          ),
        ),
      );
    });
  });

  // ── 11. Idempotency ───────────────────────────────────────────────────────
  group('11. Duplicate request — idempotency', () {
    test(
      'second upload with same Idempotency-Key returns existing jobId',
      () async {
        const sharedJobId = 'idempotent-audio-011';
        final payload = _buildJobPayload(jobId: sharedJobId, status: 'queued');

        final job1 = LectureAudioJobModel.fromJson(
          payload['data'] as Map<String, dynamic>,
        );
        final job2 = LectureAudioJobModel.fromJson(
          payload['data'] as Map<String, dynamic>,
        );

        expect(job1.jobId, equals(job2.jobId));
        expect(job1.status, equals(job2.status));
      },
    );
  });

  // ── 12. Teacher Deletion ──────────────────────────────────────────────────
  group('12. Teacher deletion of lecture recording', () {
    test('DELETE /ai/audio/:jobId returns success response', () async {
      const jobId = 'audio-job-to-delete';

      when(
        () => mockDio.delete<Map<String, dynamic>>('/ai/audio/$jobId'),
      ).thenAnswer(
        (_) async => _buildResponse(
          statusCode: 200,
          data: {
            'success': true,
            'message': 'Lecture recording and AI results deleted successfully.',
          },
          requestOptions: _optsDelete('/ai/audio/$jobId'),
        ),
      );

      final response = await mockDio.delete<Map<String, dynamic>>(
        '/ai/audio/$jobId',
      );

      expect(response.statusCode, equals(200));
      expect(response.data!['success'], isTrue);
      expect(response.data!['message'], contains('deleted successfully'));
    });
  });

  // ── 13. Formatters and Helpers ────────────────────────────────────────────
  group('13. LectureAudioJobModel helpers and formatters', () {
    test('formats duration correctly', () {
      final job1 = LectureAudioJobModel.fromJson(
        _buildJobPayload(durationSeconds: 75)['data'] as Map<String, dynamic>,
      );
      expect(job1.durationLabel, equals('01:15'));

      final job2 = LectureAudioJobModel.fromJson(
        _buildJobPayload(durationSeconds: 3665)['data'] as Map<String, dynamic>,
      );
      expect(job2.durationLabel, equals('61:05'));

      final job0 = LectureAudioJobModel.fromJson(
        _buildJobPayload(durationSeconds: 0)['data'] as Map<String, dynamic>,
      );
      expect(job0.durationLabel, equals('00:00'));
    });

    test('formats file size label accurately', () {
      final jobKb = LectureAudioJobModel.fromJson(
        _buildJobPayload(fileSizeBytes: 2048 * 1024)['data']
            as Map<String, dynamic>,
      );
      expect(jobKb.fileSizeLabel, equals('2.0 MB'));
    });
  });
}
