// ==============================================================================
// ZankoAI Flashcard Model (SM-2 Spaced-Repetition Ready)
// ==============================================================================

class FlashcardModel {
  final String id;
  final String front;
  final String back;
  final String deckName;
  final String? courseId;
  final String source;
  final String difficulty;
  final int box;
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime? nextReviewAt;

  FlashcardModel({
    required this.id,
    required this.front,
    required this.back,
    this.deckName = 'General',
    this.courseId,
    this.source = 'manual',
    this.difficulty = 'medium',
    this.box = 1,
    this.easeFactor = 2.50,
    this.intervalDays = 1,
    this.repetitions = 0,
    this.nextReviewAt,
  });

  bool get isDue =>
      nextReviewAt == null || DateTime.now().isAfter(nextReviewAt!);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'front': front,
      'back': back,
      'deck_name': deckName,
      'course_id': courseId,
      'source_type': source,
      'difficulty': difficulty,
      'box': box,
      'ease_factor': easeFactor,
      'interval_days': intervalDays,
      'repetitions': repetitions,
      'next_review_at': nextReviewAt?.toIso8601String(),
    };
  }

  factory FlashcardModel.fromMap(Map<String, dynamic> map) {
    // Support nested flashcard_progress join or direct progress fields
    final progressMap = map['flashcard_progress'] is Map<String, dynamic>
        ? map['flashcard_progress'] as Map<String, dynamic>
        : (map['flashcard_progress'] is List &&
              (map['flashcard_progress'] as List).isNotEmpty)
        ? (map['flashcard_progress'] as List).first as Map<String, dynamic>
        : map;

    return FlashcardModel(
      id: (map['id'] ?? '').toString(),
      front: (map['front_text'] ?? map['front'] ?? '').toString(),
      back: (map['back_text'] ?? map['back'] ?? '').toString(),
      deckName: (map['deck_name'] ?? map['deckName'] ?? 'General').toString(),
      courseId: map['course_id']?.toString(),
      source: (map['source_type'] ?? map['source'] ?? 'manual').toString(),
      difficulty: (map['difficulty'] ?? 'medium').toString(),
      box: (progressMap['box'] as num?)?.toInt() ?? 1,
      easeFactor: (progressMap['ease_factor'] as num?)?.toDouble() ?? 2.50,
      intervalDays: (progressMap['interval_days'] as num?)?.toInt() ?? 1,
      repetitions: (progressMap['repetitions'] as num?)?.toInt() ?? 0,
      nextReviewAt: progressMap['next_review_at'] != null
          ? DateTime.tryParse(progressMap['next_review_at'].toString())
          : null,
    );
  }

  factory FlashcardModel.fromJson(Map<String, dynamic> json) =>
      FlashcardModel.fromMap(json);
}
