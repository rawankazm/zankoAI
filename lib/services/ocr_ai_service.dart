import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/ocr_job_model.dart';

// ==============================================================================
// ZankoAI OCR AI Processing Service
// ==============================================================================

/// Service for submitting images to the backend AI OCR pipeline, polling
/// for transcription and AI study aids, and deleting OCR data.
///
/// Authenticated via the [ApiClient] Dio interceptor which injects the
/// Supabase JWT automatically.
class OcrAiService {
  OcrAiService._();
  static final OcrAiService instance = OcrAiService._();

  Dio get _dio => ApiClient().dio;

  // ─── Submit OCR Job ─────────────────────────────────────────────────────────

  /// Upload an image (printed or handwritten) and enqueue it for OCR and AI processing.
  ///
  /// [file] — on mobile/desktop. Use [bytes] + [filename] on web.
  /// [ocrType] — 'auto', 'printed', or 'handwriting'.
  /// [processingType] — 'all', 'extract_only', 'summarize', 'quiz', 'flashcards', or 'questions'.
  /// [idempotencyKey] — optional UUID to safely retry on network failures.
  ///
  /// Returns an [OcrJobModel] with status='queued' and a [jobId] to poll.
  Future<OcrJobModel> submitOcrJob({
    File? file,
    Uint8List? bytes,
    String? filename,
    OcrType ocrType = OcrType.auto,
    OcrProcessingType processingType = OcrProcessingType.all,
    String? idempotencyKey,
  }) async {
    assert(
      file != null || (bytes != null && filename != null),
      'Either file (mobile/desktop) or bytes+filename (web) must be provided.',
    );

    late FormData formData;
    final mimeType = _resolveImageMime(filename ?? file?.path ?? 'image.jpg');

    if (kIsWeb) {
      formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes!,
          filename: filename ?? 'document.jpg',
          contentType: DioMediaType.parse(mimeType),
        ),
        'ocrType': ocrType.name,
        'processingType': processingType.toApiValue(),
      });
    } else {
      final f = file!;
      final actualFilename = filename ?? f.path.split(Platform.pathSeparator).last;
      formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          f.path,
          filename: actualFilename,
          contentType: DioMediaType.parse(_resolveImageMime(actualFilename)),
        ),
        'ocrType': ocrType.name,
        'processingType': processingType.toApiValue(),
      });
    }

    final headers = <String, dynamic>{
      'Content-Type': 'multipart/form-data',
    };

    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/ai/ocr',
      data: formData,
      options: Options(
        headers: headers,
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );

    _assertSuccess(response);
    final data = response.data!['data'] as Map<String, dynamic>;
    return OcrJobModel.fromJson(data);
  }

  // ─── Get Job Status ─────────────────────────────────────────────────────────

  /// Fetch the current status and results of an OCR job.
  ///
  /// Safe to call frequently — no quota is consumed on GET requests.
  Future<OcrJobModel> getOcrJobStatus(String jobId) async {
    final response = await _dio.get<Map<String, dynamic>>('/ai/ocr/$jobId');
    _assertSuccess(response);
    final data = response.data!['data'] as Map<String, dynamic>;
    return OcrJobModel.fromJson(data);
  }

  // ─── Poll Until Complete ─────────────────────────────────────────────────────

  /// Poll an OCR job until it reaches 'completed' or 'failed'.
  ///
  /// [interval] — duration between polls (default: 2 seconds).
  /// [maxAttempts] — maximum number of polls (default: 60 = 2 min).
  /// [onStatusUpdate] — optional callback invoked on each poll.
  Future<OcrJobModel> pollUntilComplete(
    String jobId, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 60,
    void Function(OcrJobModel job)? onStatusUpdate,
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final job = await getOcrJobStatus(jobId);
      onStatusUpdate?.call(job);

      if (job.isCompleted || job.isFailed) {
        return job;
      }

      await Future.delayed(interval);
    }

    throw TimeoutException(
      'OCR job $jobId did not complete within ${maxAttempts * interval.inSeconds} seconds.',
      Duration(seconds: maxAttempts * interval.inSeconds),
    );
  }

  // ─── Delete OCR Job ─────────────────────────────────────────────────────────

  /// Permanently deletes an OCR job, its AI results, and its image from storage.
  Future<bool> deleteOcrJob(String jobId) async {
    final response = await _dio.delete<Map<String, dynamic>>('/ai/ocr/$jobId');
    _assertSuccess(response);
    return response.data?['success'] == true;
  }

  // ─── Convenience: Submit + Poll ─────────────────────────────────────────────

  /// Convenience method: submit an image and poll until complete.
  Future<OcrJobModel> submitAndWait({
    File? file,
    Uint8List? bytes,
    String? filename,
    OcrType ocrType = OcrType.auto,
    OcrProcessingType processingType = OcrProcessingType.all,
    String? idempotencyKey,
    Duration pollInterval = const Duration(seconds: 2),
    int maxPollAttempts = 60,
    void Function(OcrJobModel job)? onStatusUpdate,
  }) async {
    final job = await submitOcrJob(
      file: file,
      bytes: bytes,
      filename: filename,
      ocrType: ocrType,
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

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _resolveImageMime(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _assertSuccess(Response response) {
    final body = response.data as Map<String, dynamic>?;
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300 ||
        body?['success'] != true) {
      final msg = body?['error']?['message'] as String? ??
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
