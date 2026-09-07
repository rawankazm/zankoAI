// ==============================================================================
// ZankoAI Lecture Audio Recording — Flutter Data Models
// ==============================================================================

enum AudioJobStatus {
  queued,
  processing,
  transcribing,
  summarizing,
  generating,
  completed,
  failed;

  static AudioJobStatus fromString(String value) {
    return AudioJobStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AudioJobStatus.queued,
    );
  }

  String get displayNameKu {
    switch (this) {
      case AudioJobStatus.queued:
        return 'لە نۆرەدایە';
      case AudioJobStatus.processing:
        return 'خەریکی ئامادەکردنە';
      case AudioJobStatus.transcribing:
        return 'دەرهێنانی دەق لە دەنگ';
      case AudioJobStatus.summarizing:
        return 'کورتکردنەوەی وانە';
      case AudioJobStatus.generating:
        return 'دروستکردنی کویز و فلاشکارت';
      case AudioJobStatus.completed:
        return 'تەواوبوو';
      case AudioJobStatus.failed:
        return 'سەرکەوتوو نەبوو';
    }
  }
}

// ─── Study Materials ──────────────────────────────────────────────────────────

class AudioFlashcard {
  final String id;
  final String front;
  final String back;

  const AudioFlashcard({
    required this.id,
    required this.front,
    required this.back,
  });

  factory AudioFlashcard.fromJson(Map<String, dynamic> json) {
    return AudioFlashcard(
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

class AudioQuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String explanation;

  const AudioQuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory AudioQuizQuestion.fromJson(Map<String, dynamic> json) {
    return AudioQuizQuestion(
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

class AudioQuiz {
  final String title;
  final List<AudioQuizQuestion> questions;

  const AudioQuiz({
    required this.title,
    required this.questions,
  });

  factory AudioQuiz.fromJson(Map<String, dynamic> json) {
    return AudioQuiz(
      title: json['title'] as String? ?? 'Lecture Quiz',
      questions: (json['questions'] as List<dynamic>?)
              ?.map((q) => AudioQuizQuestion.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'questions': questions.map((q) => q.toJson()).toList(),
      };
}

// ─── Result Model ─────────────────────────────────────────────────────────────

class LectureAudioResultModel {
  final String transcript;
  final String summary;
  final List<String> keyTakeaways;
  final List<AudioFlashcard> flashcards;
  final AudioQuiz? quiz;
  final String languageDetected;

  const LectureAudioResultModel({
    required this.transcript,
    required this.summary,
    required this.keyTakeaways,
    required this.flashcards,
    this.quiz,
    required this.languageDetected,
  });

  factory LectureAudioResultModel.fromJson(Map<String, dynamic> json) {
    return LectureAudioResultModel(
      transcript: json['transcript'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      keyTakeaways: (json['keyTakeaways'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      flashcards: (json['flashcards'] as List<dynamic>?)
              ?.map((f) => AudioFlashcard.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      quiz: json['quiz'] != null && json['quiz'] is Map<String, dynamic>
          ? AudioQuiz.fromJson(json['quiz'] as Map<String, dynamic>)
          : null,
      languageDetected: json['languageDetected'] as String? ?? 'ku',
    );
  }
}

// ─── Main Job Model ───────────────────────────────────────────────────────────

class LectureAudioJobModel {
  final String jobId;
  final AudioJobStatus status;
  final String courseId;
  final String? lectureId;
  final String title;
  final int fileSizeBytes;
  final int durationSeconds;
  final String audioFormat;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? errorMessage;
  final LectureAudioResultModel? result;

  const LectureAudioJobModel({
    required this.jobId,
    required this.status,
    required this.courseId,
    this.lectureId,
    required this.title,
    required this.fileSizeBytes,
    required this.durationSeconds,
    required this.audioFormat,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    this.errorMessage,
    this.result,
  });

  factory LectureAudioJobModel.fromJson(Map<String, dynamic> json) {
    return LectureAudioJobModel(
      jobId: json['jobId'] as String? ?? '',
      status: AudioJobStatus.fromString(json['status'] as String? ?? 'queued'),
      courseId: json['courseId'] as String? ?? '',
      lectureId: json['lectureId'] as String?,
      title: json['title'] as String? ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      audioFormat: json['audioFormat'] as String? ?? 'audio/mp4',
      isPublished: json['isPublished'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      errorMessage: json['errorMessage'] as String?,
      result: json['result'] != null
          ? LectureAudioResultModel.fromJson(json['result'] as Map<String, dynamic>)
          : null,
    );
  }

  // ─── Status Predicates ──────────────────────────────────────────────────────

  bool get isQueued => status == AudioJobStatus.queued;
  bool get isProcessing => status == AudioJobStatus.processing;
  bool get isTranscribing => status == AudioJobStatus.transcribing;
  bool get isSummarizing => status == AudioJobStatus.summarizing;
  bool get isGenerating => status == AudioJobStatus.generating;
  bool get isCompleted => status == AudioJobStatus.completed;
  bool get isFailed => status == AudioJobStatus.failed;
  bool get isInProgress => !isCompleted && !isFailed;

  String get fileSizeLabel {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get durationLabel {
    if (durationSeconds <= 0) return '00:00';
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }
}
