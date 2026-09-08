// ==============================================================================
// ZankoAI App Notification & Notification Preferences Models
// ==============================================================================

enum AppNotificationType {
  assignmentReminder,
  examReminder,
  announcement,
  teacherAnnouncement,
  aiJobCompletion,
  subscriptionActivated,
  subscriptionExpiring,
  paymentResult,
  systemNotification,
  subscriptionNotification,
  system,
  broadcast,
  vip,
  academic,
  reminder,
  security;

  static AppNotificationType fromString(String? val) {
    if (val == null) return AppNotificationType.systemNotification;
    final clean = val
        .toLowerCase()
        .trim()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    switch (clean) {
      case 'assignment_reminder':
      case 'assignmentreminder':
        return AppNotificationType.assignmentReminder;
      case 'exam_reminder':
      case 'examreminder':
        return AppNotificationType.examReminder;
      case 'announcement':
        return AppNotificationType.announcement;
      case 'teacher_announcement':
      case 'teacherannouncement':
        return AppNotificationType.teacherAnnouncement;
      case 'ai_job_completion':
      case 'aijobcompletion':
        return AppNotificationType.aiJobCompletion;
      case 'subscription_activated':
      case 'subscriptionactivated':
        return AppNotificationType.subscriptionActivated;
      case 'subscription_expiring':
      case 'subscriptionexpiring':
        return AppNotificationType.subscriptionExpiring;
      case 'payment_result':
      case 'paymentresult':
        return AppNotificationType.paymentResult;
      case 'subscription_notification':
      case 'subscriptionnotification':
        return AppNotificationType.subscriptionNotification;
      case 'system_notification':
      case 'systemnotification':
        return AppNotificationType.systemNotification;
      case 'broadcast':
        return AppNotificationType.broadcast;
      case 'vip':
        return AppNotificationType.vip;
      case 'academic':
        return AppNotificationType.academic;
      case 'reminder':
        return AppNotificationType.reminder;
      case 'security':
        return AppNotificationType.security;
      default:
        return AppNotificationType.system;
    }
  }

  String toSnakeCase() {
    switch (this) {
      case AppNotificationType.assignmentReminder:
        return 'assignment_reminder';
      case AppNotificationType.examReminder:
        return 'exam_reminder';
      case AppNotificationType.announcement:
        return 'announcement';
      case AppNotificationType.teacherAnnouncement:
        return 'teacher_announcement';
      case AppNotificationType.aiJobCompletion:
        return 'ai_job_completion';
      case AppNotificationType.subscriptionActivated:
        return 'subscription_activated';
      case AppNotificationType.subscriptionExpiring:
        return 'subscription_expiring';
      case AppNotificationType.paymentResult:
        return 'payment_result';
      case AppNotificationType.subscriptionNotification:
        return 'subscription_notification';
      case AppNotificationType.systemNotification:
        return 'system_notification';
      case AppNotificationType.system:
        return 'system';
      case AppNotificationType.broadcast:
        return 'broadcast';
      case AppNotificationType.vip:
        return 'vip';
      case AppNotificationType.academic:
        return 'academic';
      case AppNotificationType.reminder:
        return 'reminder';
      case AppNotificationType.security:
        return 'security';
    }
  }

  String get displayNameKu {
    switch (this) {
      case AppNotificationType.assignmentReminder:
        return 'بیرهێنانەوەی ئەرک';
      case AppNotificationType.examReminder:
        return 'بیرهێنانەوەی تاقیکردنەوە';
      case AppNotificationType.announcement:
      case AppNotificationType.teacherAnnouncement:
        return 'ئاگاداری گشتی و مامۆستا';
      case AppNotificationType.aiJobCompletion:
        return 'تەواوبوونی کاری ژیری دەستکرد 🤖';
      case AppNotificationType.subscriptionActivated:
        return 'چالاکبوونی بەشداری VIP ✨';
      case AppNotificationType.subscriptionExpiring:
        return 'بەسەرچوونی نزیکی بەشداری VIP ⏳';
      case AppNotificationType.paymentResult:
        return 'ئەنجامی پرۆسەی پارەدان 💳';
      case AppNotificationType.subscriptionNotification:
        return 'ئاگاداری بەشداری VIP';
      case AppNotificationType.systemNotification:
      case AppNotificationType.system:
        return 'ئاگاداری سیستەم';
      case AppNotificationType.broadcast:
        return 'پەیامی گشتی';
      case AppNotificationType.vip:
        return 'تایبەتمەندی VIP';
      case AppNotificationType.academic:
        return 'ئاگاداری ئەکادیمی';
      case AppNotificationType.reminder:
        return 'بیرهێنانەوە';
      case AppNotificationType.security:
        return 'ئاسایش';
    }
  }
}

class AppNotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final AppNotificationType type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final String? idempotencyKey;
  final String? referenceId;
  final DateTime? scheduledFor;
  final DateTime createdAt;

  AppNotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.isRead = false,
    this.readAt,
    this.idempotencyKey,
    this.referenceId,
    this.scheduledFor,
    required this.createdAt,
  });

  DateTime get localCreatedAt => createdAt.toLocal();

  AppNotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    AppNotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? readAt,
    String? idempotencyKey,
    String? referenceId,
    DateTime? scheduledFor,
    DateTime? createdAt,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      referenceId: referenceId ?? this.referenceId,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type.toSnakeCase(),
      'data': data,
      'is_read': isRead,
      'read_at': readAt?.toUtc().toIso8601String(),
      'idempotency_key': idempotencyKey,
      'reference_id': referenceId,
      'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory AppNotificationModel.fromMap(Map<String, dynamic> map) {
    return AppNotificationModel(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? map['userId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      type: AppNotificationType.fromString(map['type']?.toString()),
      data: map['data'] is Map<String, dynamic>
          ? map['data'] as Map<String, dynamic>
          : null,
      isRead: map['is_read'] == true || map['isRead'] == true,
      readAt: map['read_at'] != null
          ? DateTime.tryParse(map['read_at'].toString())
          : null,
      idempotencyKey: map['idempotency_key']?.toString(),
      referenceId: map['reference_id']?.toString(),
      scheduledFor: map['scheduled_for'] != null
          ? DateTime.tryParse(map['scheduled_for'].toString())
          : null,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) =>
      AppNotificationModel.fromMap(json);
}

class NotificationPreferencesModel {
  final String userId;
  final bool assignmentReminders;
  final bool examReminders;
  final bool teacherAnnouncements;
  final bool announcements;
  final bool aiJobCompletion;
  final bool subscriptionNotifications;
  final bool paymentUpdates;
  final bool systemNotifications;
  final bool pushEnabled;
  final bool emailEnabled;
  final int leadTimeMinutes;
  final String timezone;

  NotificationPreferencesModel({
    required this.userId,
    this.assignmentReminders = true,
    this.examReminders = true,
    this.teacherAnnouncements = true,
    this.announcements = true,
    this.aiJobCompletion = true,
    this.subscriptionNotifications = true,
    this.paymentUpdates = true,
    this.systemNotifications = true,
    this.pushEnabled = true,
    this.emailEnabled = false,
    this.leadTimeMinutes = 60,
    this.timezone = 'Asia/Baghdad',
  });

  NotificationPreferencesModel copyWith({
    String? userId,
    bool? assignmentReminders,
    bool? examReminders,
    bool? teacherAnnouncements,
    bool? announcements,
    bool? aiJobCompletion,
    bool? subscriptionNotifications,
    bool? paymentUpdates,
    bool? systemNotifications,
    bool? pushEnabled,
    bool? emailEnabled,
    int? leadTimeMinutes,
    String? timezone,
  }) {
    return NotificationPreferencesModel(
      userId: userId ?? this.userId,
      assignmentReminders: assignmentReminders ?? this.assignmentReminders,
      examReminders: examReminders ?? this.examReminders,
      teacherAnnouncements: teacherAnnouncements ?? this.teacherAnnouncements,
      announcements: announcements ?? this.announcements,
      aiJobCompletion: aiJobCompletion ?? this.aiJobCompletion,
      subscriptionNotifications:
          subscriptionNotifications ?? this.subscriptionNotifications,
      paymentUpdates: paymentUpdates ?? this.paymentUpdates,
      systemNotifications: systemNotifications ?? this.systemNotifications,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      leadTimeMinutes: leadTimeMinutes ?? this.leadTimeMinutes,
      timezone: timezone ?? this.timezone,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'assignment_reminders': assignmentReminders,
      'exam_reminders': examReminders,
      'teacher_announcements': teacherAnnouncements,
      'announcements': announcements,
      'ai_job_completion': aiJobCompletion,
      'subscription_notifications': subscriptionNotifications,
      'payment_updates': paymentUpdates,
      'system_notifications': systemNotifications,
      'push_enabled': pushEnabled,
      'email_enabled': emailEnabled,
      'lead_time_minutes': leadTimeMinutes,
      'timezone': timezone,
    };
  }

  factory NotificationPreferencesModel.fromMap(Map<String, dynamic> map) {
    return NotificationPreferencesModel(
      userId: (map['user_id'] ?? map['userId'] ?? '').toString(),
      assignmentReminders:
          map['assignment_reminders'] ?? map['assignmentReminders'] ?? true,
      examReminders: map['exam_reminders'] ?? map['examReminders'] ?? true,
      teacherAnnouncements:
          map['teacher_announcements'] ?? map['teacherAnnouncements'] ?? true,
      announcements: map['announcements'] ?? true,
      aiJobCompletion:
          map['ai_job_completion'] ?? map['aiJobCompletion'] ?? true,
      subscriptionNotifications:
          map['subscription_notifications'] ??
          map['subscriptionNotifications'] ??
          true,
      paymentUpdates: map['payment_updates'] ?? map['paymentUpdates'] ?? true,
      systemNotifications:
          map['system_notifications'] ?? map['systemNotifications'] ?? true,
      pushEnabled: map['push_enabled'] ?? map['pushEnabled'] ?? true,
      emailEnabled: map['email_enabled'] ?? map['emailEnabled'] ?? false,
      leadTimeMinutes:
          (map['lead_time_minutes'] ?? map['leadTimeMinutes'] as num?)
              ?.toInt() ??
          60,
      timezone: (map['timezone'] ?? 'Asia/Baghdad').toString(),
    );
  }

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) =>
      NotificationPreferencesModel.fromMap(json);
}
