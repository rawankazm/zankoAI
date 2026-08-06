enum QuestionType {
  multipleChoice,
  trueFalse,
  fillInBlank,
  essay,
}

class QuestionModel {
  final String id;
  final String questionText;
  final QuestionType type;
  final List<String>? options; // Null for fillInBlank or essay
  final String correctAnswer; // For auto-grading (MCQ, True/False)
  final String? explanation; // AI detailed explanation for feedback

  QuestionModel({
    required this.id,
    required this.questionText,
    required this.type,
    this.options,
    required this.correctAnswer,
    this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionText': questionText,
      'type': type.toString().split('.').last,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
    };
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      id: map['id'] ?? '',
      questionText: map['questionText'] ?? '',
      type: QuestionType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => QuestionType.multipleChoice,
      ),
      options: map['options'] != null ? List<String>.from(map['options']) : null,
      correctAnswer: map['correctAnswer'] ?? '',
      explanation: map['explanation'],
    );
  }
}

class QuizModel {
  final String id;
  final String title;
  final String courseName;
  final List<QuestionModel> questions;
  final int durationMinutes;
  final bool isExam;
  final double passingScorePercentage;

  QuizModel({
    required this.id,
    required this.title,
    required this.courseName,
    required this.questions,
    this.durationMinutes = 10,
    this.isExam = false,
    this.passingScorePercentage = 60.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'courseName': courseName,
      'questions': questions.map((q) => q.toMap()).toList(),
      'durationMinutes': durationMinutes,
      'isExam': isExam,
      'passingScorePercentage': passingScorePercentage,
    };
  }

  factory QuizModel.fromMap(Map<String, dynamic> map) {
    return QuizModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      courseName: map['courseName'] ?? '',
      questions: map['questions'] != null
          ? (map['questions'] as List)
              .map((q) => QuestionModel.fromMap(q))
              .toList()
          : [],
      durationMinutes: map['durationMinutes'] ?? 10,
      isExam: map['isExam'] ?? false,
      passingScorePercentage: (map['passingScorePercentage'] as num?)?.toDouble() ?? 60.0,
    );
  }
}
