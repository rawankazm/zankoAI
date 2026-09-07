// ==============================================================================
// ZankoAI PDF AI Processing — Flutter Data Models
// ==============================================================================

enum PdfJobStatus {
  queued,
  processing,
  completed,
  failed;

  static PdfJobStatus fromString(String value) {
    return PdfJobStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PdfJobStatus.queued,
    );
  }
}

enum PdfProcessingType {
  all,
  summarize,
  quiz,
  flashcards,
  questions;

  static PdfProcessingType fromString(String value) {
    return PdfProcessingType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PdfProcessingType.all,
    );
  }
}

// ─── Nested Result Models ─────────────────────────────────────────────────────

class PdfQuestion {
  final String question;
  final String answer;
  final String type; // 'short_answer' | 'discussion'

  const PdfQuestion({
    required this.question,
    required this.answer,
    required this.type,
  });

  factory PdfQuestion.fromJson(Map<String, dynamic> json) {
    return PdfQuestion(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      type: json['type'] as String? ?? 'short_answer',
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'type': type,
      };
}

class PdfQuizItem {
  final String questionText;
  final String type; // 'multiple_choice' | 'true_false'
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  const PdfQuizItem({
    required this.questionText,
    required this.type,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory PdfQuizItem.fromJson(Map<String, dynamic> json) {
    return PdfQuizItem(
      questionText: json['questionText'] as String? ?? '',
      type: json['type'] as String? ?? 'multiple_choice',
      options: List<String>.from(json['options'] as List? ?? []),
      correctAnswer: json['correctAnswer'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'questionText': questionText,
        'type': type,
        'options': options,
        'correctAnswer': correctAnswer,
        'explanation': explanation,
      };
}

class PdfQuiz {
  final String title;
  final List<PdfQuizItem> questions;

  const PdfQuiz({required this.title, required this.questions});

  factory PdfQuiz.fromJson(Map<String, dynamic> json) {
    return PdfQuiz(
      title: json['title'] as String? ?? 'Quiz',
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((q) => PdfQuizItem.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'questions': questions.map((q) => q.toJson()).toList(),
      };
}

class PdfFlashcard {
  final String front;
  final String back;

  const PdfFlashcard({required this.front, required this.back});

  factory PdfFlashcard.fromJson(Map<String, dynamic> json) {
    return PdfFlashcard(
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'front': front, 'back': back};
}

// ─── Main Result Container ────────────────────────────────────────────────────

class PdfJobResult {
  final String? summary;
  final List<PdfQuestion>? questions;
  final PdfQuiz? quiz;
  final List<PdfFlashcard>? flashcards;
  final int extractedTextLength;

  const PdfJobResult({
    this.summary,
    this.questions,
    this.quiz,
    this.flashcards,
    required this.extractedTextLength,
  });

  factory PdfJobResult.fromJson(Map<String, dynamic> json) {
    return PdfJobResult(
      summary: json['summary'] as String?,
      questions: (json['questions'] as List<dynamic>?)
          ?.map((q) => PdfQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      quiz: json['quiz'] != null && (json['quiz'] as Map).isNotEmpty
          ? PdfQuiz.fromJson(json['quiz'] as Map<String, dynamic>)
          : null,
      flashcards: (json['flashcards'] as List<dynamic>?)
          ?.map((f) => PdfFlashcard.fromJson(f as Map<String, dynamic>))
          .toList(),
      extractedTextLength: json['extractedTextLength'] as int? ?? 0,
    );
  }
}

// ─── Main Job Model ───────────────────────────────────────────────────────────

class PdfJobModel {
  final String jobId;
  final PdfJobStatus status;
  final String originalFilename;
  final int fileSizeBytes;
  final int pageCount;
  final PdfProcessingType processingType;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PdfJobResult? result;
  final Map<String, dynamic>? usage;

  const PdfJobModel({
    required this.jobId,
    required this.status,
    required this.originalFilename,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.processingType,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
    this.result,
    this.usage,
  });

  factory PdfJobModel.fromJson(Map<String, dynamic> json) {
    final resultJson = json['result'] as Map<String, dynamic>?;
    return PdfJobModel(
      jobId: json['jobId'] as String,
      status: PdfJobStatus.fromString(json['status'] as String? ?? 'queued'),
      originalFilename: json['originalFilename'] as String? ?? '',
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      pageCount: json['pageCount'] as int? ?? 0,
      processingType:
          PdfProcessingType.fromString(json['processingType'] as String? ?? 'all'),
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      result: resultJson != null ? PdfJobResult.fromJson(resultJson) : null,
      usage: json['usage'] as Map<String, dynamic>?,
    );
  }

  bool get isCompleted => status == PdfJobStatus.completed;
  bool get isFailed => status == PdfJobStatus.failed;
  bool get isPending =>
      status == PdfJobStatus.queued || status == PdfJobStatus.processing;

  /// Human-readable file size (e.g. "2.3 MB")
  String get fileSizeLabel {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
