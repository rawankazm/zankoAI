import '../core/network/api_client.dart';
import '../models/flashcard_model.dart';

/// Dedicated production service for Flashcards and SM-2 Spaced Repetition.
class FlashcardService {
  final ApiClient _client;

  FlashcardService({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  static final FlashcardService instance = FlashcardService();

  /// Lists flashcards with optional course and deck filter.
  Future<List<FlashcardModel>> listFlashcards({String? courseId}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/flashcards',
      queryParameters: {'course_id': ?courseId},
    );
    final data = response.data?['data'];
    final items = data is Map
        ? (data['items'] as List<dynamic>? ?? [])
        : (data as List<dynamic>? ?? []);
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => FlashcardModel.fromJson(e))
        .toList();
  }

  /// Fetches flashcards currently due for review under SM-2 spaced repetition.
  Future<List<FlashcardModel>> getDueFlashcards({String? courseId}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/flashcards/due',
      queryParameters: {'course_id': ?courseId},
    );
    final data = response.data?['data'];
    final items = data is List<dynamic>
        ? data
        : (data is Map ? (data['items'] as List<dynamic>? ?? []) : []);
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => FlashcardModel.fromJson(e))
        .toList();
  }

  /// Records an SM-2 review rating (0 to 5) for a flashcard.
  Future<Map<String, dynamic>> reviewFlashcard(
    String cardId,
    int rating,
  ) async {
    assert(rating >= 0 && rating <= 5, 'Rating must be between 0 and 5');
    final response = await _client.post<Map<String, dynamic>>(
      '/flashcards/$cardId/review',
      data: {'rating': rating},
    );
    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// Creates a new flashcard.
  Future<FlashcardModel> createFlashcard({
    required String front,
    required String back,
    String? courseId,
    String? deckName,
    List<String>? tags,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/flashcards',
      data: {
        'front': front,
        'back': back,
        'course_id': ?courseId,
        'deck_name': ?deckName,
        'tags': ?tags,
      },
    );
    final data = response.data?['data'] as Map<String, dynamic>;
    return FlashcardModel.fromJson(data);
  }
}
