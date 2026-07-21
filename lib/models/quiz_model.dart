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

  QuestionModel({
    required this.id,
    required this.questionText,
    required this.type,
    this.options,
    required this.correctAnswer,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionText': questionText,
      'type': type.toString().split('.').last,
      'options': options,
      'correctAnswer': correctAnswer,
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
    );
  }
}

class QuizModel {
  final String id;
  final String title;
  final String courseName;
  final List<QuestionModel> questions;
  final int durationMinutes;

  QuizModel({
    required this.id,
    required this.title,
    required this.courseName,
    required this.questions,
    this.durationMinutes = 10,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'courseName': courseName,
      'questions': questions.map((q) => q.toMap()).toList(),
      'durationMinutes': durationMinutes,
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
    );
  }
}
