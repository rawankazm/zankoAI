// ==============================================================================
// ZankoAI Calendar Event Model — Timezone-Aware with Local Display Support
// ==============================================================================

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum CalendarEventType {
  classEvent,
  exam,
  assignmentDeadline,
  reminder,
  universityEvent,
  personalStudyEvent,
  lecture,
  assignment,
  personal;

  static CalendarEventType fromString(String? val) {
    if (val == null) return CalendarEventType.personalStudyEvent;
    final clean = val
        .toLowerCase()
        .trim()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    switch (clean) {
      case 'class':
      case 'classevent':
        return CalendarEventType.classEvent;
      case 'exam':
        return CalendarEventType.exam;
      case 'assignment_deadline':
      case 'assignmentdeadline':
        return CalendarEventType.assignmentDeadline;
      case 'reminder':
        return CalendarEventType.reminder;
      case 'university_event':
      case 'universityevent':
        return CalendarEventType.universityEvent;
      case 'personal_study_event':
      case 'personalstudyevent':
        return CalendarEventType.personalStudyEvent;
      case 'lecture':
        return CalendarEventType.lecture;
      case 'assignment':
        return CalendarEventType.assignment;
      case 'personal':
        return CalendarEventType.personal;
      default:
        return CalendarEventType.personalStudyEvent;
    }
  }

  String toSnakeCase() {
    switch (this) {
      case CalendarEventType.classEvent:
        return 'class';
      case CalendarEventType.exam:
        return 'exam';
      case CalendarEventType.assignmentDeadline:
        return 'assignment_deadline';
      case CalendarEventType.reminder:
        return 'reminder';
      case CalendarEventType.universityEvent:
        return 'university_event';
      case CalendarEventType.personalStudyEvent:
        return 'personal_study_event';
      case CalendarEventType.lecture:
        return 'lecture';
      case CalendarEventType.assignment:
        return 'assignment';
      case CalendarEventType.personal:
        return 'personal';
    }
  }

  String get displayNameKu {
    switch (this) {
      case CalendarEventType.classEvent:
      case CalendarEventType.lecture:
        return 'وانە / پۆل';
      case CalendarEventType.exam:
        return 'تاقیکردنەوە';
      case CalendarEventType.assignmentDeadline:
      case CalendarEventType.assignment:
        return 'وادەی ڕادەستکردنی ئەرک';
      case CalendarEventType.reminder:
        return 'بیرهێنانەوە';
      case CalendarEventType.universityEvent:
        return 'چالاکی زانکۆیی';
      case CalendarEventType.personalStudyEvent:
      case CalendarEventType.personal:
        return 'خوێندنی تایبەتی';
    }
  }

  IconData get icon {
    switch (this) {
      case CalendarEventType.classEvent:
      case CalendarEventType.lecture:
        return Icons.class_outlined;
      case CalendarEventType.exam:
        return Icons.quiz_outlined;
      case CalendarEventType.assignmentDeadline:
      case CalendarEventType.assignment:
        return Icons.assignment_late_outlined;
      case CalendarEventType.reminder:
        return CupertinoIcons.bell;
      case CalendarEventType.universityEvent:
        return Icons.account_balance_outlined;
      case CalendarEventType.personalStudyEvent:
      case CalendarEventType.personal:
        return Icons.menu_book_outlined;
    }
  }

  Color get color {
    switch (this) {
      case CalendarEventType.classEvent:
      case CalendarEventType.lecture:
        return const Color(0xFF2563EB); // Blue
      case CalendarEventType.exam:
        return const Color(0xFFDC2626); // Red
      case CalendarEventType.assignmentDeadline:
      case CalendarEventType.assignment:
        return const Color(0xFFEA580C); // Orange
      case CalendarEventType.reminder:
        return const Color(0xFFF59E0B); // Amber
      case CalendarEventType.universityEvent:
        return const Color(0xFF7C3AED); // Purple
      case CalendarEventType.personalStudyEvent:
      case CalendarEventType.personal:
        return const Color(0xFF059669); // Green
    }
  }
}

class CalendarEventModel {
  final String id;
  final String userId;
  final String? courseId;
  final String title;
  final String? description;
  final CalendarEventType eventType;
  final DateTime startTime; // UTC
  final DateTime endTime; // UTC
  final bool isAllDay;
  final String? location;
  final String timezone;
  final int notificationLeadMinutes;
  final String? recurrenceRule;
  final bool isCompleted;

  CalendarEventModel({
    required this.id,
    required this.userId,
    this.courseId,
    required this.title,
    this.description,
    required this.eventType,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.location,
    this.timezone = 'Asia/Baghdad',
    this.notificationLeadMinutes = 30,
    this.recurrenceRule,
    this.isCompleted = false,
  });

  /// User device's local timezone representations
  DateTime get localStartTime => startTime.toLocal();
  DateTime get localEndTime => endTime.toLocal();

  bool get isUpcoming => DateTime.now().isBefore(localStartTime);
  bool get isOngoing =>
      DateTime.now().isAfter(localStartTime) &&
      DateTime.now().isBefore(localEndTime);
  bool get isPast => DateTime.now().isAfter(localEndTime);

  CalendarEventModel copyWith({
    String? id,
    String? userId,
    String? courseId,
    String? title,
    String? description,
    CalendarEventType? eventType,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? location,
    String? timezone,
    int? notificationLeadMinutes,
    String? recurrenceRule,
    bool? isCompleted,
  }) {
    return CalendarEventModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      timezone: timezone ?? this.timezone,
      notificationLeadMinutes:
          notificationLeadMinutes ?? this.notificationLeadMinutes,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'course_id': courseId,
      'title': title,
      'description': description,
      'event_type': eventType.toSnakeCase(),
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'is_all_day': isAllDay,
      'location': location,
      'timezone': timezone,
      'notification_lead_minutes': notificationLeadMinutes,
      'recurrence_rule': recurrenceRule,
      'is_completed': isCompleted,
    };
  }

  factory CalendarEventModel.fromMap(Map<String, dynamic> map) {
    final rawStart = map['start_time'] ?? map['startTime'];
    final rawEnd = map['end_time'] ?? map['endTime'];
    final parsedStart =
        DateTime.tryParse(rawStart?.toString() ?? '')?.toUtc() ??
        DateTime.now().toUtc();
    final parsedEnd =
        DateTime.tryParse(rawEnd?.toString() ?? '')?.toUtc() ??
        parsedStart.add(const Duration(hours: 1));

    return CalendarEventModel(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? map['userId'] ?? '').toString(),
      courseId: map['course_id']?.toString() ?? map['courseId']?.toString(),
      title: (map['title'] ?? '').toString(),
      description: map['description']?.toString(),
      eventType: CalendarEventType.fromString(
        map['event_type']?.toString() ?? map['eventType']?.toString(),
      ),
      startTime: parsedStart,
      endTime: parsedEnd,
      isAllDay: map['is_all_day'] == true || map['isAllDay'] == true,
      location: map['location']?.toString(),
      timezone: (map['timezone'] ?? 'Asia/Baghdad').toString(),
      notificationLeadMinutes:
          (map['notification_lead_minutes'] as num?)?.toInt() ?? 30,
      recurrenceRule: map['recurrence_rule']?.toString(),
      isCompleted: map['is_completed'] == true || map['isCompleted'] == true,
    );
  }

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) =>
      CalendarEventModel.fromMap(json);
}
