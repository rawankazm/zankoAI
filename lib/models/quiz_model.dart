// ==============================================================================
// ZankoAI Quiz & Question Models
// ==============================================================================

enum QuestionType {
  multipleChoice,
  trueFalse,
  shortAnswer,
  fillInBlank,
  essay;

  static QuestionType fromString(String? val) {
    if (val == null) return QuestionType.multipleChoice;
    final normalized = val.toLowerCase().trim().replaceAll('_', '');
    if (normalized == 'truefalse' || normalized == 'tf')
      return QuestionType.trueFalse;
    if (normalized == 'shortanswer') return QuestionType.shortAnswer;
    if (normalized == 'fillinblank') return QuestionType.fillInBlank;
    if (normalized == 'essay') return QuestionType.essay;
    return QuestionType.multipleChoice;
  }

  String toSnakeCase() {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.trueFalse:
        return 'true_false';
      case QuestionType.shortAnswer:
        return 'short_answer';
      case QuestionType.fillInBlank:
        return 'fill_in_blank';
      case QuestionType.essay:
        return 'essay';
    }
  }
}

class QuestionModel {
  final String id;
  final String questionText;
  final QuestionType type;
  final List<String>? options; // Null or empty for short_answer
  final String
  correctAnswer; // Empty string if sanitized during active exam taking!
  final String? explanation; // Null if sanitized during active exam taking!
  final String difficulty;
  final double points;
  final int orderIndex;

  QuestionModel({
    required this.id,
    required this.questionText,
    required this.type,
    this.options,
    this.correctAnswer = '',
    this.explanation,
    this.difficulty = 'medium',
    this.points = 1.0,
    this.orderIndex = 0,
  });

  bool get hasAnswer => correctAnswer.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionText': questionText,
      'type': type.toString().split('.').last,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'difficulty': difficulty,
      'points': points,
      'orderIndex': orderIndex,
    };
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    final rawType = map['question_type'] ?? map['type'];
    final rawOptions = map['options'];
    List<String>? parsedOptions;
    if (rawOptions is List) {
      parsedOptions = rawOptions.map((e) => e.toString()).toList();
    }

    return QuestionModel(
      id: (map['id'] ?? '').toString(),
      questionText: (map['question_text'] ?? map['questionText'] ?? '')
          .toString(),
      type: QuestionType.fromString(rawType?.toString()),
      options: parsedOptions,
      correctAnswer: (map['correct_answer'] ?? map['correctAnswer'] ?? '')
          .toString(),
      explanation: map['explanation']?.toString(),
      difficulty: (map['difficulty'] ?? 'medium').toString(),
      points: (map['points'] as num?)?.toDouble() ?? 1.0,
      orderIndex:
          (map['order_index'] ?? map['orderIndex'] as num?)?.toInt() ?? 0,
    );
  }

  factory QuestionModel.fromJson(Map<String, dynamic> json) =>
      QuestionModel.fromMap(json);
}

class QuizModel {
  final String id;
  final String title;
  final String courseName;
  final String? courseId;
  final String? creatorId;
  final String? description;
  final String sourceType;
  final String difficulty;
  final List<QuestionModel> questions;
  final int durationMinutes;
  final bool isExam;
  final double passingScorePercentage;
  final bool isPublished;
  final int questionCount;

  QuizModel({
    required this.id,
    required this.title,
    this.courseName = '',
    this.courseId,
    this.creatorId,
    this.description,
    this.sourceType = 'manual',
    this.difficulty = 'medium',
    required this.questions,
    this.durationMinutes = 10,
    this.isExam = false,
    this.passingScorePercentage = 50.0,
    this.isPublished = true,
    int? questionCount,
  }) : questionCount = questionCount ?? questions.length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'courseName': courseName,
      'course_id': courseId,
      'creator_id': creatorId,
      'description': description,
      'source_type': sourceType,
      'difficulty': difficulty,
      'questions': questions.map((q) => q.toMap()).toList(),
      'durationMinutes': durationMinutes,
      'isExam': isExam,
      'passingScorePercentage': passingScorePercentage,
      'is_published': isPublished,
      'question_count': questionCount,
    };
  }

  factory QuizModel.fromMap(Map<String, dynamic> map) {
    final rawQuestions = map['questions'];
    List<QuestionModel> parsedQuestions = [];
    if (rawQuestions is List) {
      parsedQuestions = rawQuestions
          .whereType<Map<String, dynamic>>()
          .map((q) => QuestionModel.fromMap(q))
          .toList();
    }

    final rawPassingScore =
        map['passing_score'] ?? map['passingScorePercentage'] ?? 50.0;
    final rawDuration =
        map['time_limit_minutes'] ?? map['durationMinutes'] ?? 10;

    return QuizModel(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      courseName: (map['course_name'] ?? map['courseName'] ?? '').toString(),
      courseId: map['course_id']?.toString(),
      creatorId: map['creator_id']?.toString(),
      description: map['description']?.toString(),
      sourceType: (map['source_type'] ?? 'manual').toString(),
      difficulty: (map['difficulty'] ?? 'medium').toString(),
      questions: parsedQuestions,
      durationMinutes: (rawDuration as num?)?.toInt() ?? 10,
      isExam: map['isExam'] ?? (map['is_exam'] ?? false),
      passingScorePercentage: (rawPassingScore as num?)?.toDouble() ?? 50.0,
      isPublished: map['is_published'] ?? true,
      questionCount:
          (map['question_count'] as num?)?.toInt() ?? parsedQuestions.length,
    );
  }

  factory QuizModel.fromJson(Map<String, dynamic> json) =>
      QuizModel.fromMap(json);
}

// ─── Quiz Attempt Models ──────────────────────────────────────────────────────

class EvaluatedAnswerModel {
  final String questionId;
  final String questionText;
  final QuestionType questionType;
  final String selectedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final double pointsAwarded;
  final double maxPoints;
  final String? explanation;

  EvaluatedAnswerModel({
    required this.questionId,
    required this.questionText,
    required this.questionType,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.pointsAwarded,
    required this.maxPoints,
    this.explanation,
  });

  factory EvaluatedAnswerModel.fromJson(Map<String, dynamic> json) {
    return EvaluatedAnswerModel(
      questionId: (json['question_id'] ?? '').toString(),
      questionText: (json['question_text'] ?? '').toString(),
      questionType: QuestionType.fromString(json['question_type']?.toString()),
      selectedAnswer: (json['selected_answer'] ?? '').toString(),
      correctAnswer: (json['correct_answer'] ?? '').toString(),
      isCorrect: json['is_correct'] == true,
      pointsAwarded: (json['points_awarded'] as num?)?.toDouble() ?? 0.0,
      maxPoints: (json['max_points'] as num?)?.toDouble() ?? 1.0,
      explanation: json['explanation']?.toString(),
    );
  }
}

class QuizSubmissionResultModel {
  final String attemptId;
  final String quizId;
  final String userId;
  final double score;
  final double totalPoints;
  final double percentage;
  final bool passed;
  final double passingScore;
  final DateTime startedAt;
  final DateTime completedAt;
  final int timeSpentSeconds;
  final List<EvaluatedAnswerModel> evaluatedAnswers;

  QuizSubmissionResultModel({
    required this.attemptId,
    required this.quizId,
    required this.userId,
    required this.score,
    required this.totalPoints,
    required this.percentage,
    required this.passed,
    required this.passingScore,
    required this.startedAt,
    required this.completedAt,
    required this.timeSpentSeconds,
    required this.evaluatedAnswers,
  });

  factory QuizSubmissionResultModel.fromJson(Map<String, dynamic> json) {
    final rawEvaluated = json['evaluated_answers'];
    List<EvaluatedAnswerModel> parsedAnswers = [];
    if (rawEvaluated is List) {
      parsedAnswers = rawEvaluated
          .whereType<Map<String, dynamic>>()
          .map((e) => EvaluatedAnswerModel.fromJson(e))
          .toList();
    }

    return QuizSubmissionResultModel(
      attemptId: (json['attempt_id'] ?? '').toString(),
      quizId: (json['quiz_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      totalPoints: (json['total_points'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      passed: json['passed'] == true,
      passingScore: (json['passing_score'] as num?)?.toDouble() ?? 50.0,
      startedAt:
          DateTime.tryParse(json['started_at']?.toString() ?? '') ??
          DateTime.now(),
      completedAt:
          DateTime.tryParse(json['completed_at']?.toString() ?? '') ??
          DateTime.now(),
      timeSpentSeconds: (json['time_spent_seconds'] as num?)?.toInt() ?? 0,
      evaluatedAnswers: parsedAnswers,
    );
  }
}
