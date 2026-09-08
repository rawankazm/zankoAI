import 'package:uuid/uuid.dart';
import '../core/network/api_client.dart';

/// Secure production AI Service communicating through the DigitalOcean backend.
/// Never holds or transmits sensitive Gemini/OpenAI API keys on mobile clients.
class ProductionAiService {
  final ApiClient _client;
  static const _uuid = Uuid();

  ProductionAiService({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  static final ProductionAiService instance = ProductionAiService();

  /// Sends a chat message to the server-side AI Gateway with automatic idempotency protection.
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    String? conversationId,
    String? systemInstruction,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    final response = await _client.post<Map<String, dynamic>>(
      '/ai/chat',
      data: {
        'message': message,
        'conversation_id': ?conversationId,
        'system_instruction': ?systemInstruction,
      },
      idempotencyKey: key,
    );
    return response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
  }

  /// Lists past student conversations.
  Future<List<Map<String, dynamic>>> listConversations() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/ai/conversations',
    );
    final data = response.data?['data'];
    final items = data is List<dynamic>
        ? data
        : (data is Map ? (data['items'] as List<dynamic>? ?? []) : []);
    return items.whereType<Map<String, dynamic>>().toList();
  }

  /// Generates dynamic study flashcards from text or topic via the backend AI engine.
  Future<List<Map<String, dynamic>>> generateFlashcards({
    required String content,
    int count = 5,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    final response = await _client.post<Map<String, dynamic>>(
      '/ai/generate-flashcards',
      data: {'content': content, 'count': count},
      idempotencyKey: key,
    );
    final data = response.data?['data'] as List<dynamic>? ?? [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// Generates exam questions from material.
  Future<Map<String, dynamic>> generateQuiz({
    required String content,
    int questionCount = 10,
    String difficulty = 'medium',
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    final response = await _client.post<Map<String, dynamic>>(
      '/ai/generate-quiz',
      data: {
        'content': content,
        'question_count': questionCount,
        'difficulty': difficulty,
      },
      idempotencyKey: key,
    );
    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }
}
