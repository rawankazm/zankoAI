enum AnnouncementPriority { normal, important, urgent }

class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final String courseName;
  final String teacherName;
  final DateTime createdAt;
  final AnnouncementPriority priority;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.courseName,
    required this.teacherName,
    required this.createdAt,
    this.priority = AnnouncementPriority.normal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'courseName': courseName,
      'teacherName': teacherName,
      'createdAt': createdAt.toIso8601String(),
      'priority': priority.name,
    };
  }

  factory AnnouncementModel.fromMap(Map<String, dynamic> map) {
    return AnnouncementModel(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      courseName: map['courseName'] as String,
      teacherName: map['teacherName'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      priority: AnnouncementPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => AnnouncementPriority.normal,
      ),
    );
  }
}
