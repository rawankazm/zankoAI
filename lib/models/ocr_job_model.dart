// ==============================================================================
// ZankoAI OCR AI Processing — Flutter Data Models
// ==============================================================================

enum OcrJobStatus {
  queued,
  processing,
  completed,
  failed;

  static OcrJobStatus fromString(String value) {
    return OcrJobStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OcrJobStatus.queued,
    );
  }
}

enum OcrType {
  auto,
  printed,
  handwriting;

  static OcrType fromString(String value) {
    return OcrType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OcrType.auto,
    );
  }
}

enum OcrProcessingType {
  extractOnly,
  all,
  summarize,
  quiz,
  flashcards,
  questions;

  static OcrProcessingType fromString(String value) {
    switch (value) {
      case 'extract_only':
        return OcrProcessingType.extractOnly;
      case 'summarize':
        return OcrProcessingType.summarize;
      case 'quiz':
        return OcrProcessingType.quiz;
      case 'flashcards':
        return OcrProcessingType.flashcards;
      case 'questions':
        return OcrProcessingType.questions;
      default:
        return OcrProcessingType.all;
    }
  }

  String toApiValue() {
    switch (this) {
      case OcrProcessingType.extractOnly:
        return 'extract_only';
      case OcrProcessingType.summarize:
        return 'summarize';
      case OcrProcessingType.quiz:
        return 'quiz';
      case OcrProcessingType.flashcards:
        return 'flashcards';
      case OcrProcessingType.questions:
        return 'questions';
      case OcrProcessingType.all:
        return 'all';
    }
  }
}

enum DetectedTextType {
  handwriting,
  printed,
  mixed;

  static DetectedTextType fromString(String value) {
    return DetectedTextType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DetectedTextType.mixed,
    );
  }
}

// ─── Result Components ────────────────────────────────────────────────────────

class OcrQuestion {
  final String id;
  final String question;
  final String answer;

  const OcrQuestion({
    required this.id,
    required this.question,
    required this.answer,
  });

  factory OcrQuestion.fromJson(Map<String, dynamic> json) {
    return OcrQuestion(
      id: json['id']?.toString() ?? '',
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'answer': answer,
      };
}

class OcrQuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String explanation;

  const OcrQuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory OcrQuizQuestion.fromJson(Map<String, dynamic> json) {
    return OcrQuizQuestion(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      correctAnswer: (json['correctAnswer'] as num?)?.toInt() ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correctAnswer': correctAnswer,
        'explanation': explanation,
      };
}

class OcrQuiz {
  final String title;
  final List<OcrQuizQuestion> questions;

  const OcrQuiz({
    required this.title,
    required this.questions,
  });

  factory OcrQuiz.fromJson(Map<String, dynamic> json) {
    return OcrQuiz(
      title: json['title'] as String? ?? 'OCR Academic Quiz',
      questions: (json['questions'] as List<dynamic>?)
              ?.map((q) => OcrQuizQuestion.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'questions': questions.map((q) => q.toJson()).toList(),
      };
}

class OcrFlashcard {
  final String id;
  final String front;
  final String back;

  const OcrFlashcard({
    required this.id,
    required this.front,
    required this.back,
  });

  factory OcrFlashcard.fromJson(Map<String, dynamic> json) {
    return OcrFlashcard(
      id: json['id']?.toString() ?? '',
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'front': front,
        'back': back,
      };
}

// ─── OCR Result Model ─────────────────────────────────────────────────────────

class OcrJobResultModel {
  final String extractedText;
  final DetectedTextType detectedTextType;
  final double confidenceScore;
  final int extractedTextLength;
  final String? summary;
  final List<OcrQuestion>? questions;
  final OcrQuiz? quiz;
  final List<OcrFlashcard>? flashcards;
  final String ocrProvider;

  const OcrJobResultModel({
    required this.extractedText,
    required this.detectedTextType,
    required this.confidenceScore,
    required this.extractedTextLength,
    this.summary,
    this.questions,
    this.quiz,
    this.flashcards,
    required this.ocrProvider,
  });

  factory OcrJobResultModel.fromJson(Map<String, dynamic> json) {
    return OcrJobResultModel(
      extractedText: json['extractedText'] as String? ?? '',
      detectedTextType: DetectedTextType.fromString(
        json['detectedTextType'] as String? ?? 'mixed',
      ),
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.95,
      extractedTextLength: (json['extractedTextLength'] as num?)?.toInt() ?? 0,
      summary: json['summary'] as String?,
      questions: (json['questions'] as List<dynamic>?)
          ?.map((q) => OcrQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      quiz: json['quiz'] != null && json['quiz'] is Map<String, dynamic>
          ? OcrQuiz.fromJson(json['quiz'] as Map<String, dynamic>)
          : null,
      flashcards: (json['flashcards'] as List<dynamic>?)
          ?.map((f) => OcrFlashcard.fromJson(f as Map<String, dynamic>))
          .toList(),
      ocrProvider: json['ocrProvider'] as String? ?? 'google',
    );
  }
}

// ─── OCR Job Model ────────────────────────────────────────────────────────────

class OcrJobModel {
  final String jobId;
  final OcrJobStatus status;
  final String originalFilename;
  final int fileSizeBytes;
  final int imageWidth;
  final int imageHeight;
  final OcrType ocrType;
  final OcrProcessingType processingType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? errorMessage;
  final OcrJobResultModel? result;

  const OcrJobModel({
    required this.jobId,
    required this.status,
    required this.originalFilename,
    required this.fileSizeBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.ocrType,
    required this.processingType,
    required this.createdAt,
    required this.updatedAt,
    this.errorMessage,
    this.result,
  });

  factory OcrJobModel.fromJson(Map<String, dynamic> json) {
    return OcrJobModel(
      jobId: json['jobId'] as String? ?? '',
      status: OcrJobStatus.fromString(json['status'] as String? ?? 'queued'),
      originalFilename: json['originalFilename'] as String? ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      imageWidth: (json['imageWidth'] as num?)?.toInt() ?? 0,
      imageHeight: (json['imageHeight'] as num?)?.toInt() ?? 0,
      ocrType: OcrType.fromString(json['ocrType'] as String? ?? 'auto'),
      processingType: OcrProcessingType.fromString(
        json['processingType'] as String? ?? 'all',
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      errorMessage: json['errorMessage'] as String?,
      result: json['result'] != null
          ? OcrJobResultModel.fromJson(json['result'] as Map<String, dynamic>)
          : null,
    );
  }

  // ─── Status helpers ─────────────────────────────────────────────────────────

  bool get isQueued => status == OcrJobStatus.queued;
  bool get isProcessing => status == OcrJobStatus.processing;
  bool get isCompleted => status == OcrJobStatus.completed;
  bool get isFailed => status == OcrJobStatus.failed;
  bool get isHandwriting => result?.detectedTextType == DetectedTextType.handwriting;

  String get fileSizeLabel {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get dimensionsLabel {
    if (imageWidth <= 0 || imageHeight <= 0) return '';
    return '${imageWidth}x$imageHeight px';
  }
}
