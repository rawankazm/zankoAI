import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/pdf_job_model.dart';

// ==============================================================================
// ZankoAI PDF AI Processing Service
// ==============================================================================

/// Service for submitting PDFs to the backend AI processing pipeline
/// and polling for results.
///
/// All requests are authenticated via the [ApiClient] Dio interceptor
/// which injects the Supabase JWT automatically.
class PdfAiService {
  PdfAiService._();
  static final PdfAiService instance = PdfAiService._();

  Dio get _dio => ApiClient().dio;

  // ─── Submit PDF Job ─────────────────────────────────────────────────────────

  /// Upload a PDF and enqueue it for AI processing.
  ///
  /// [file] — on mobile/desktop. Use [bytes] + [filename] on web.
  /// [processingType] — 'all', 'summarize', 'quiz', 'flashcards', or 'questions'.
  /// [idempotencyKey] — optional UUID to safely retry on network failures.
  ///
  /// Returns a [PdfJobModel] with status='queued' and a [jobId] to poll.
  Future<PdfJobModel> submitPdfJob({
    File? file,
    Uint8List? bytes,
    String? filename,
    PdfProcessingType processingType = PdfProcessingType.all,
    String? idempotencyKey,
  }) async {
    assert(
      file != null || (bytes != null && filename != null),
      'Either file (mobile/desktop) or bytes+filename (web) must be provided.',
    );

    // Build multipart form data — respects kIsWeb constraint
    late FormData formData;

    if (kIsWeb) {
      // Web: use bytes + filename
      formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes!,
          filename: filename ?? 'document.pdf',
          contentType: DioMediaType('application', 'pdf'),
        ),
        'processingType': processingType.name,
      });
    } else {
      // Mobile / Desktop: use File path
      final f = file!;
      formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          f.path,
          filename: filename ?? f.path.split(Platform.pathSeparator).last,
          contentType: DioMediaType('application', 'pdf'),
        ),
        'processingType': processingType.name,
      });
    }

    final headers = <String, dynamic>{'Content-Type': 'multipart/form-data'};

    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/ai/pdf',
      data: formData,
      options: Options(
        headers: headers,
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );

    _assertSuccess(response);
    final data = response.data!['data'] as Map<String, dynamic>;
    return PdfJobModel.fromJson(data);
  }

  // ─── Get Job Status ─────────────────────────────────────────────────────────

  /// Fetch the current status and result (if completed) of a PDF job.
  ///
  /// Safe to call frequently — no quota is consumed on GET requests.
  Future<PdfJobModel> getPdfJobStatus(String jobId) async {
    final response = await _dio.get<Map<String, dynamic>>('/ai/pdf/$jobId');
    _assertSuccess(response);
    final data = response.data!['data'] as Map<String, dynamic>;
    return PdfJobModel.fromJson(data);
  }

  // ─── Poll Until Complete ─────────────────────────────────────────────────────

  /// Poll a PDF job until it completes or fails.
  ///
  /// [interval] — how long to wait between polls (default: 3 seconds).
  /// [maxAttempts] — maximum number of polls before giving up (default: 60 = 3 min).
  /// [onStatusUpdate] — optional callback invoked on each poll with the latest job.
  ///
  /// Throws a [TimeoutException] if [maxAttempts] is exceeded.
  Future<PdfJobModel> pollUntilComplete(
    String jobId, {
    Duration interval = const Duration(seconds: 3),
    int maxAttempts = 60,
    void Function(PdfJobModel job)? onStatusUpdate,
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final job = await getPdfJobStatus(jobId);
      onStatusUpdate?.call(job);

      if (job.isCompleted || job.isFailed) {
        return job;
      }

      await Future.delayed(interval);
    }

    throw TimeoutException(
      'PDF job $jobId did not complete within ${maxAttempts * interval.inSeconds} seconds.',
      Duration(seconds: maxAttempts * interval.inSeconds),
    );
  }

  // ─── Ask Question ───────────────────────────────────────────────────────────

  /// Ask a natural language question about a completed PDF.
  ///
  /// Consumes [ai_chat] quota (not pdf quota).
  /// The PDF must have status='completed'.
  ///
  /// Returns the AI's answer as a plain string.
  Future<String> askQuestion({
    required String jobId,
    required String question,
    String? idempotencyKey,
  }) async {
    final headers = <String, dynamic>{};
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/ai/pdf/$jobId/ask',
      data: {'question': question},
      options: Options(headers: headers.isEmpty ? null : headers),
    );

    _assertSuccess(response);
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['answer'] as String? ?? '';
  }

  // ─── Convenience: Submit + Poll ─────────────────────────────────────────────

  /// Convenience method: submit a PDF and poll until complete.
  ///
  /// Useful for small files where you want a single async call.
  Future<PdfJobModel> submitAndWait({
    File? file,
    Uint8List? bytes,
    String? filename,
    PdfProcessingType processingType = PdfProcessingType.all,
    String? idempotencyKey,
    Duration pollInterval = const Duration(seconds: 3),
    int maxPollAttempts = 80,
    void Function(PdfJobModel job)? onStatusUpdate,
  }) async {
    final job = await submitPdfJob(
      file: file,
      bytes: bytes,
      filename: filename,
      processingType: processingType,
      idempotencyKey: idempotencyKey,
    );

    return pollUntilComplete(
      job.jobId,
      interval: pollInterval,
      maxAttempts: maxPollAttempts,
      onStatusUpdate: onStatusUpdate,
    );
  }

  // ─── Internal ───────────────────────────────────────────────────────────────

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
