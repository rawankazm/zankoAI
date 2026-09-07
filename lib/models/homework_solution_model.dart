// ==============================================================================
// ZankoAI AI Homework Solution Models
// ==============================================================================

class HomeworkStep {
  final int stepNumber;
  final String title;
  final String content;

  const HomeworkStep({
    required this.stepNumber,
    required this.title,
    required this.content,
  });

  factory HomeworkStep.fromJson(Map<String, dynamic> json) {
    return HomeworkStep(
      stepNumber: (json['stepNumber'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'stepNumber': stepNumber,
        'title': title,
        'content': content,
      };
}

class HomeworkSolutionModel {
  final String id;
  final String subject;
  final String? course;
  final String difficulty;
  final String answer;
  final String explanation;
  final List<HomeworkStep> stepByStepReasoning;
  final List<String> mistakesIdentified;
  final List<String> hints;
  final List<String> relatedConcepts;
  final String language;
  final bool hasImage;
  final DateTime createdAt;

  const HomeworkSolutionModel({
    required this.id,
    required this.subject,
    this.course,
    required this.difficulty,
    required this.answer,
    required this.explanation,
    required this.stepByStepReasoning,
    required this.mistakesIdentified,
    required this.hints,
    required this.relatedConcepts,
    required this.language,
    required this.hasImage,
    required this.createdAt,
  });

  factory HomeworkSolutionModel.fromJson(Map<String, dynamic> json) {
    return HomeworkSolutionModel(
      id: json['id'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      course: json['course'] as String?,
      difficulty: json['difficulty'] as String? ?? 'medium',
      answer: json['answer'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      stepByStepReasoning: (json['stepByStepReasoning'] as List<dynamic>?)
              ?.map((e) => HomeworkStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      mistakesIdentified: (json['mistakesIdentified'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      hints: (json['hints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      relatedConcepts: (json['relatedConcepts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      language: json['language'] as String? ?? 'ku',
      hasImage: json['hasImage'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'course': course,
        'difficulty': difficulty,
        'answer': answer,
        'explanation': explanation,
        'stepByStepReasoning':
            stepByStepReasoning.map((s) => s.toJson()).toList(),
        'mistakesIdentified': mistakesIdentified,
        'hints': hints,
        'relatedConcepts': relatedConcepts,
        'language': language,
        'hasImage': hasImage,
        'createdAt': createdAt.toIso8601String(),
      };

  String get difficultyLabelKu {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'ئاسان';
      case 'medium':
        return 'مامناوەند';
      case 'hard':
        return 'سەخت';
      case 'advanced':
        return 'پێشکەوتوو';
      default:
        return 'مامناوەند';
    }
  }

  int get stepsCount => stepByStepReasoning.length;
}
