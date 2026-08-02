enum LectureType { pdf, ppt, video }

class LectureModel {
  final String id;
  final String title;
  final String courseName;
  final LectureType type;
  final String fileUrl;
  final String description;
  final DateTime uploadedAt;
  final String fileSize;

  LectureModel({
    required this.id,
    required this.title,
    required this.courseName,
    required this.type,
    required this.fileUrl,
    required this.description,
    required this.uploadedAt,
    required this.fileSize,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'courseName': courseName,
      'type': type.name,
      'fileUrl': fileUrl,
      'description': description,
      'uploadedAt': uploadedAt.toIso8601String(),
      'fileSize': fileSize,
    };
  }

  factory LectureModel.fromMap(Map<String, dynamic> map) {
    return LectureModel(
      id: map['id'] as String,
      title: map['title'] as String,
      courseName: map['courseName'] as String,
      type: LectureType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => LectureType.pdf,
      ),
      fileUrl: map['fileUrl'] as String,
      description: map['description'] as String,
      uploadedAt: DateTime.parse(map['uploadedAt'] as String),
      fileSize: map['fileSize'] as String,
    );
  }
}
