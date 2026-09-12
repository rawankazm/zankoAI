// ==============================================================================
// ZankoAI Academic Report & Seminar Models — Supabase Backend Models
// ==============================================================================

class AcademicSectionModel {
  final String? id;
  final int sectionOrder;
  final String title;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AcademicSectionModel({
    this.id,
    required this.sectionOrder,
    required this.title,
    required this.content,
    this.createdAt,
    this.updatedAt,
  });

  factory AcademicSectionModel.fromJson(Map<String, dynamic> json) {
    return AcademicSectionModel(
      id: json['id'] as String?,
      sectionOrder: (json['section_order'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'section_order': sectionOrder,
        'title': title,
        'content': content,
      };
}

class AcademicReportRecord {
  final String id;
  final String userId;
  final String title;
  final String? subject;
  final String language;
  final String? topic;
  final String? description;
  final String? content;
  final String status;
  final List<AcademicSectionModel> sections;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AcademicReportRecord({
    required this.id,
    required this.userId,
    required this.title,
    this.subject,
    required this.language,
    this.topic,
    this.description,
    this.content,
    required this.status,
    this.sections = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcademicReportRecord.fromJson(Map<String, dynamic> json) {
    final rawSections = json['report_sections'] as List<dynamic>? ??
        json['sections'] as List<dynamic>? ??
        [];
    final sections = rawSections
        .whereType<Map<String, dynamic>>()
        .map((s) => AcademicSectionModel.fromJson(s))
        .toList();

    return AcademicReportRecord(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String?,
      language: json['language'] as String? ?? 'ku',
      topic: json['topic'] as String?,
      description: json['description'] as String?,
      content: json['content'] as String?,
      status: json['status'] as String? ?? 'completed',
      sections: sections,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'subject': subject,
        'language': language,
        'topic': topic,
        'description': description,
        'content': content,
        'status': status,
        'sections': sections.map((s) => s.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class AcademicSeminarRecord {
  final String id;
  final String userId;
  final String title;
  final String? subject;
  final String language;
  final String? topic;
  final String? description;
  final String? content;
  final String status;
  final List<AcademicSectionModel> sections;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AcademicSeminarRecord({
    required this.id,
    required this.userId,
    required this.title,
    this.subject,
    required this.language,
    this.topic,
    this.description,
    this.content,
    required this.status,
    this.sections = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcademicSeminarRecord.fromJson(Map<String, dynamic> json) {
    final rawSections = json['seminar_sections'] as List<dynamic>? ??
        json['sections'] as List<dynamic>? ??
        [];
    final sections = rawSections
        .whereType<Map<String, dynamic>>()
        .map((s) => AcademicSectionModel.fromJson(s))
        .toList();

    return AcademicSeminarRecord(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String?,
      language: json['language'] as String? ?? 'ku',
      topic: json['topic'] as String?,
      description: json['description'] as String?,
      content: json['content'] as String?,
      status: json['status'] as String? ?? 'completed',
      sections: sections,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'subject': subject,
        'language': language,
        'topic': topic,
        'description': description,
        'content': content,
        'status': status,
        'sections': sections.map((s) => s.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
