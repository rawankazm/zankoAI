import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/homework_solution_model.dart';

// ==============================================================================
// ZankoAI AI Homework Solver Client Service
// ==============================================================================

/// Client service for students and teachers to submit homework problems
/// (text and/or image) and receive concise educational solutions, step-by-step
/// reasoning, common mistakes identified, hints, and related concepts.
class HomeworkService {
  HomeworkService._();
  static final HomeworkService instance = HomeworkService._();

  Dio get _dio => ApiClient().dio;

  /// Solves a homework problem with structured educational feedback.
  ///
  /// [text] — Problem description or question statement.
  /// [imageFile] — Optional image file on mobile/desktop.
  /// [imageBytes] — Optional image bytes on web.
  /// [filename] — Optional filename for the image.
  /// [subject] — Academic subject (e.g. Mathematics, Physics, Biology, etc.).
  /// [course] — Optional course name.
  /// [difficulty] — 'easy', 'medium', 'hard', or 'advanced' (default: 'medium').
  /// [language] — Language hint ('ku', 'ar', 'en'). Default 'ku'.
  /// [idempotencyKey] — Optional UUID to prevent double-charging quota on network retry.
  Future<HomeworkSolutionModel> solveHomework({
    String? text,
    File? imageFile,
    Uint8List? imageBytes,
    String? filename,
    required String subject,
    String? course,
    String difficulty = 'medium',
    String language = 'ku',
    String? idempotencyKey,
  }) async {
    final fields = <String, dynamic>{
      'subject': subject,
      'difficulty': difficulty,
      'language': language,
      // ignore: use_null_aware_elements
      if (text != null && text.isNotEmpty) 'text': text,
      // ignore: use_null_aware_elements
      if (course != null && course.isNotEmpty) 'course': course,
    };

    final hasImage = (kIsWeb && imageBytes != null) || (!kIsWeb && imageFile != null);
    dynamic bodyData;

    if (hasImage) {
      if (kIsWeb) {
        final mime = _resolveImageMime(filename ?? 'homework.jpg');
        bodyData = FormData.fromMap({
          ...fields,
          'image': MultipartFile.fromBytes(
            imageBytes!,
            filename: filename ?? 'homework.jpg',
            contentType: DioMediaType.parse(mime),
          ),
        });
      } else {
        final f = imageFile!;
        final actualFilename =
            filename ?? f.path.split(Platform.pathSeparator).last;
        final mime = _resolveImageMime(actualFilename);
        bodyData = FormData.fromMap({
          ...fields,
          'image': await MultipartFile.fromFile(
            f.path,
            filename: actualFilename,
            contentType: DioMediaType.parse(mime),
          ),
        });
      }
    } else {
      bodyData = fields;
    }

    final headers = <String, dynamic>{
      // ignore: use_null_aware_elements
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai/homework',
        data: bodyData,
        options: Options(
          headers: headers,
          contentType: hasImage ? 'multipart/form-data' : 'application/json',
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );

      _assertSuccess(response);
      final data = response.data!['data'] as Map<String, dynamic>;
      return HomeworkSolutionModel.fromJson(data);
    } on DioException catch (dioErr) {
      final errData = dioErr.response?.data;
      if (errData is Map && errData['message'] != null) {
        throw Exception(errData['message']);
      }
      if (dioErr.response?.statusCode == 429) {
        throw Exception(
            'بەشی ڕۆژانەی پرسیارەکانت (Homework) تەواو بووە. تکایە پاشتر تاقی بکەرەوە.');
      }
      throw Exception('هەڵەی پەیوەندی بە سێرڤەر: ${dioErr.message}');
    }
  }

  void _assertSuccess(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null || body['success'] != true || body['data'] == null) {
      final msg = body?['message'] as String? ?? 'هەڵەی نەزانراو لە سێرڤەر';
      throw Exception(msg);
    }
  }

  String _resolveImageMime(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
