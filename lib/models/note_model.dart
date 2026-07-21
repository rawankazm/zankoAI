class NoteModel {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final bool isAiFormatted;
  final String? courseName;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.isAiFormatted = false,
    this.courseName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'isAiFormatted': isAiFormatted,
      'courseName': courseName,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      isAiFormatted: map['isAiFormatted'] ?? false,
      courseName: map['courseName'],
    );
  }

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    bool? isAiFormatted,
    String? courseName,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isAiFormatted: isAiFormatted ?? this.isAiFormatted,
      courseName: courseName ?? this.courseName,
    );
  }
}
