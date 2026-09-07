// ==============================================================================
// ZankoAI Quiz & Flashcard Client Service
// ==============================================================================

import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/quiz_model.dart';
import '../models/flashcard_model.dart';

class QuizService {
  final Dio? _customDio;
  QuizService({Dio? dio}) : _customDio = dio;
  QuizService._() : _customDio = null;
  static final QuizService instance = QuizService._();

  Dio get _dio => _customDio ?? ApiClient().dio;

  /// Creates a new quiz manually or generates it from AI sources (PDF, OCR, Lecture, Topic).
  Future<QuizModel> createQuiz({
    required String title,
    String? courseId,
    String? description,
    String sourceType = 'manual',
    String? sourceId,
    String difficulty = 'medium',
    int timeLimitMinutes = 30,
    double passingScore = 50.0,
    bool isPublished = true,
    List<Map<String, dynamic>>? questions,
    Map<String, dynamic>? aiGeneration,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'course_id': ?courseId,
      'description': ?description,
      'source_type': sourceType,
      'source_id': ?sourceId,
      'difficulty': difficulty,
      'time_limit_minutes': timeLimitMinutes,
      'passing_score': passingScore,
      'is_published': isPublished,
      'questions': ?questions,
      'ai_generation': ?aiGeneration,
    };

    final response = await _dio.post<Map<String, dynamic>>('/quizzes', data: payload);
    final data = response.data!['data'] as Map<String, dynamic>;
    return QuizModel.fromJson(data);
  }

  /// Fetches quiz details.
  /// Anti-cheating guarantee: Correct answers and explanations are omitted
  /// for students until after submission.
  Future<QuizModel> getQuiz(String quizId) async {
    final response = await _dio.get<Map<String, dynamic>>('/quizzes/$quizId');
    final data = response.data!['data'] as Map<String, dynamic>;
    return QuizModel.fromJson(data);
  }

  /// Starts or resumes a quiz attempt.
  /// Returns attemptId and sanitized questions (without correct answers).
  Future<Map<String, dynamic>> startQuiz(String quizId) async {
    final response = await _dio.post<Map<String, dynamic>>('/quizzes/$quizId/start');
    return response.data!['data'] as Map<String, dynamic>;
  }

  /// Submits student answers.
  /// Scores are calculated strictly server-side (never trusting client inputs).
  Future<QuizSubmissionResultModel> submitQuiz({
    required String quizId,
    required String attemptId,
    required List<Map<String, String>> answers,
    int timeSpentSeconds = 0,
  }) async {
    final payload = {
      'attempt_id': attemptId,
      'time_spent_seconds': timeSpentSeconds,
      'answers': answers,
    };

    final response = await _dio.post<Map<String, dynamic>>('/quizzes/$quizId/submit', data: payload);
    final data = response.data!['data'] as Map<String, dynamic>;
    return QuizSubmissionResultModel.fromJson(data);
  }

  /// Lists quizzes for a course.
  Future<List<QuizModel>> listCourseQuizzes(String courseId) async {
    final response = await _dio.get<Map<String, dynamic>>('/courses/$courseId/quizzes');
    final items = response.data!['data']['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => QuizModel.fromJson(e))
        .toList();
  }

  // ─── Flashcards & Spaced Repetition ─────────────────────────────────────────

  /// Lists flashcards with optional course filter.
  Future<List<FlashcardModel>> listFlashcards({String? courseId}) async {
    final queryParams = <String, dynamic>{
      'course_id': ?courseId,
    };
    final response = await _dio.get<Map<String, dynamic>>('/flashcards', queryParameters: queryParams);
    final items = response.data!['data']['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => FlashcardModel.fromJson(e))
        .toList();
  }

  /// Fetches flashcards currently due for review under SM-2 spaced repetition.
  Future<List<FlashcardModel>> getDueFlashcards({String? courseId}) async {
    final queryParams = <String, dynamic>{
      'course_id': ?courseId,
    };
    final response = await _dio.get<Map<String, dynamic>>('/flashcards/due', queryParameters: queryParams);
    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => FlashcardModel.fromJson(e))
        .toList();
  }

  /// Records an SM-2 review rating (0 to 5) for a flashcard.
  Future<Map<String, dynamic>> reviewFlashcard(String cardId, int rating) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/flashcards/$cardId/review',
      data: {'rating': rating},
    );
    return response.data!['data'] as Map<String, dynamic>;
  }
}
