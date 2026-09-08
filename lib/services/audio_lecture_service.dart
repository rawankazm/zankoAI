import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/lecture_audio_job_model.dart';

// ==============================================================================
// ZankoAI Teacher Lecture Audio Recording Service
// ==============================================================================

/// Service for teachers to upload/record lecture audio, monitor async
/// transcription, summarization, flashcards, and quizzes, and manage recordings.
///
/// Authenticated via the [ApiClient] Dio interceptor which injects the
/// Supabase JWT automatically.
class AudioLectureService {
  AudioLectureService._();
  static final AudioLectureService instance = AudioLectureService._();

  Dio get _dio => ApiClient().dio;

  // ─── Submit Lecture Audio Job ───────────────────────────────────────────────

  /// Submits an audio recording of a lecture for background AI processing.
  /// Only authorized teachers of the course can invoke this.
  ///
  /// [file] — on mobile/desktop. Use [bytes] + [filename] on web.
  /// [courseId] — UUID of the course the lecture belongs to.
  /// [title] — Title of the lecture.
  /// [lectureId] — Optional UUID to link to an existing lecture row.
  /// [language] — Language hint (e.g. 'ku', 'ar', 'en').
  /// [durationSeconds] — Recorded duration in seconds.
  /// [idempotencyKey] — Optional UUID to prevent double charges on network retry.
  Future<LectureAudioJobModel> submitAudioLecture({
    File? file,
    Uint8List? bytes,
    String? filename,
    required String courseId,
    required String title,
    String? lectureId,
    String? language = 'ku',
    int durationSeconds = 0,
    String? idempotencyKey,
  }) async {
    assert(
      file != null || (bytes != null && filename != null),
      'Either file (mobile/desktop) or bytes+filename (web) must be provided.',
    );

    late FormData formData;
    final mimeType = _resolveAudioMime(filename ?? file?.path ?? 'lecture.m4a');

    final fields = <String, dynamic>{
      'courseId': courseId,
      'title': title,
      'language': language ?? 'ku',
      'durationSeconds': durationSeconds.toString(),
      // ignore: use_null_aware_elements
      if (lectureId != null) 'lectureId': lectureId,
    };

    if (kIsWeb) {
      formData = FormData.fromMap({
        ...fields,
        'file': MultipartFile.fromBytes(
          bytes!,
          filename: filename ?? 'lecture.m4a',
          contentType: DioMediaType.parse(mimeType),
        ),
      });
    } else {
      final f = file!;
      final actualFilename =
          filename ?? f.path.split(Platform.pathSeparator).last;
      formData = FormData.fromMap({
        ...fields,
        'file': await MultipartFile.fromFile(
          f.path,
          filename: actualFilename,
          contentType: DioMediaType.parse(_resolveAudioMime(actualFilename)),
        ),
      });
    }

    final headers = <String, dynamic>{'Content-Type': 'multipart/form-data'};

    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/ai/audio',
      data: formData,
      options: Options(
        headers: headers,
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 90),
      ),
    );

    _assertSuccess(response);
    final data = response.data!['data'] as Map<String, dynamic>;
    return LectureAudioJobModel.fromJson(data);
  }

  // ─── Get Job Status ─────────────────────────────────────────────────────────

  /// Fetch the current status and results of a lecture audio job.
  /// Strictly checks course membership server-side.
  Future<LectureAudioJobModel> getAudioJobStatus(String jobId) async {
    final response = await _dio.get<Map<String, dynamic>>('/ai/audio/$jobId');
    _assertSuccess(response);
    final data = response.data!['data'] as Map<String, dynamic>;
    return LectureAudioJobModel.fromJson(data);
  }

  // ─── Poll Until Complete ─────────────────────────────────────────────────────

  /// Polls a lecture audio job through all 7 states until completed or failed.
  ///
  /// [interval] — Duration between polls (default: 3 seconds).
  /// [maxAttempts] — Maximum number of attempts (default: 100 = 5 minutes).
  /// [onStatusUpdate] — Callback invoked on each state change.
  Future<LectureAudioJobModel> pollUntilComplete(
    String jobId, {
    Duration interval = const Duration(seconds: 3),
    int maxAttempts = 100,
    void Function(LectureAudioJobModel job)? onStatusUpdate,
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final job = await getAudioJobStatus(jobId);
      onStatusUpdate?.call(job);

      if (job.isCompleted || job.isFailed) {
        return job;
      }

      await Future.delayed(interval);
    }

    throw TimeoutException(
      'Lecture audio job $jobId did not complete within ${maxAttempts * interval.inSeconds} seconds.',
      Duration(seconds: maxAttempts * interval.inSeconds),
    );
  }

  // ─── Delete Audio Job ───────────────────────────────────────────────────────

  /// Deletes the recording and its generated materials.
  /// Only the recording teacher or an admin can perform this.
  Future<bool> deleteAudioJob(String jobId) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/ai/audio/$jobId',
    );
    _assertSuccess(response);
    return response.data?['success'] == true;
  }

  // ─── Convenience: Submit + Poll ─────────────────────────────────────────────

  Future<LectureAudioJobModel> submitAndWait({
    File? file,
    Uint8List? bytes,
    String? filename,
    required String courseId,
    required String title,
    String? lectureId,
    String? language = 'ku',
    int durationSeconds = 0,
    String? idempotencyKey,
    Duration pollInterval = const Duration(seconds: 3),
    int maxPollAttempts = 100,
    void Function(LectureAudioJobModel job)? onStatusUpdate,
  }) async {
    final job = await submitAudioLecture(
      file: file,
      bytes: bytes,
      filename: filename,
      courseId: courseId,
      title: title,
      lectureId: lectureId,
      language: language,
      durationSeconds: durationSeconds,
      idempotencyKey: idempotencyKey,
    );

    return pollUntilComplete(
      job.jobId,
      interval: pollInterval,
      maxAttempts: maxPollAttempts,
      onStatusUpdate: onStatusUpdate,
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _resolveAudioMime(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.webm')) return 'audio/webm';
    if (lower.endsWith('.flac')) return 'audio/flac';
    return 'audio/mp4'; // Default for m4a
  }

  void _assertSuccess(Response response) {
    final body = response.data as Map<String, dynamic>?;
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300 ||
        body?['success'] != true) {
      final msg =
          body?['error']?['message'] as String? ??
          body?['message'] as String? ??
          'Request failed (${response.statusCode})';
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: msg,
      );
    }
  }
}
