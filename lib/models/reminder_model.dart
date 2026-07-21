class ReminderModel {
  final String id;
  final String title;
  final DateTime deadline;
  final String courseName;
  final bool isCompleted;

  ReminderModel({
    required this.id,
    required this.title,
    required this.deadline,
    required this.courseName,
    this.isCompleted = false,
  });

  ReminderModel copyWith({
    String? id,
    String? title,
    DateTime? deadline,
    String? courseName,
    bool? isCompleted,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      deadline: deadline ?? this.deadline,
      courseName: courseName ?? this.courseName,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'deadline': deadline.toIso8601String(),
      'courseName': courseName,
      'isCompleted': isCompleted,
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      deadline: DateTime.parse(map['deadline'] ?? DateTime.now().toIso8601String()),
      courseName: map['courseName'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}
