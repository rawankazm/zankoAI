import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_backend_service.dart';

/// Cleanly repairs UTF-8 mojibake (e.g. "ðŸŽ‰ Ù¾ÛŒØ±Û†Ø²Û•!" -> "🎉 پیرۆزە!")
String fixNotificationEncoding(dynamic raw) {
  if (raw == null) return '';
  final input = raw.toString();
  if (input.isEmpty) return input;

  if (input.contains('Ù') || input.contains('Ø') || input.contains('Û') || input.contains('ð') || input.contains('Ã')) {
    const cp1252Map = <int, int>{
      0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84,
      0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88,
      0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C,
      0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93,
      0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
      0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B,
      0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
    };

    try {
      final bytes = <int>[];
      for (final codeUnit in input.codeUnits) {
        if (codeUnit <= 0xFF) {
          bytes.add(codeUnit);
        } else if (cp1252Map.containsKey(codeUnit)) {
          bytes.add(cp1252Map[codeUnit]!);
        } else {
          return input;
        }
      }
      final decoded = utf8.decode(bytes, allowMalformed: false);
      if (decoded.isNotEmpty) return decoded;
    } catch (_) {}
  }
  return input;
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  RealtimeChannel? _notificationChannel;
  Timer? _firestorePollTimer;

  static const String _prefShownNotifIdsKey = 'zanko_shown_notif_ids_v2';
  static const String _prefReadNotificationsKey = 'zanko_read_notifications_v1';
  static const String _prefDeletedNotificationsKey = 'zanko_deleted_notifications_v1';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  final StreamController<void> _notificationsUpdatedController = StreamController<void>.broadcast();
  Stream<void> get onNotificationsUpdated => _notificationsUpdatedController.stream;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification clicked with payload: ${details.payload}');
      },
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        'zanko_admin_channel',
        'Admin Notifications',
        description: 'ZankoAI Admin Announcements & Messages',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidPlugin.createNotificationChannel(channel);
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    // Native Background FCM Setup
    if (!kIsWeb) {
      try {
        await Firebase.initializeApp();
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        // Subscribe to global topic for all student announcements
        await messaging.subscribeToTopic('all_students');
        debugPrint('[NotificationService] Subscribed to FCM topic: all_students');

        // Handle foreground notifications seamlessly
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notif = message.notification;
          final title = fixNotificationEncoding(notif?.title ?? message.data['title'] ?? 'ZankoAI 🔔');
          final body = fixNotificationEncoding(notif?.body ?? message.data['body'] ?? '');
          debugPrint('[NotificationService] Foreground FCM message received: $title');
          showInstantNotification(
            id: message.messageId.hashCode,
            title: title,
            body: body,
          );
          _notificationsUpdatedController.add(null);
        });

        final token = await messaging.getToken();
        if (token != null) {
          debugPrint('[NotificationService] Acquired FCM device token: $token');
        }
      } catch (e) {
        debugPrint('[NotificationService] Notice initializing Firebase Messaging: $e');
      }
    }

    _initialized = true;
  }

  Future<void> syncUserToken(String userId, {bool isVip = false}) async {
    await init();
    if (!kIsWeb) {
      try {
        final messaging = FirebaseMessaging.instance;
        if (isVip) {
          await messaging.subscribeToTopic('vip_students');
        } else {
          await messaging.unsubscribeFromTopic('vip_students');
        }

        final token = await messaging.getToken();
        if (token != null && userId.isNotEmpty) {
          await NotificationBackendService().registerDevice(
            fcmToken: token,
            platform: defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios',
          );
        }
      } catch (e) {
        debugPrint('[NotificationService] Notice syncing FCM token: $e');
      }
    }
  }

  /// Start listening to notifications from both Supabase Realtime AND Admin Firestore
  Future<void> listenToAdminNotifications(String userId, bool isVip, {String? email}) async {
    try {
      await init();

      // 1. Supabase Realtime Channel
      _notificationChannel?.unsubscribe();
      final channelKey = userId.isNotEmpty ? userId : 'broadcast_all';
      _notificationChannel = Supabase.instance.client
          .channel('public_notifications_stream_$channelKey')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final targetUserId = newRecord['user_id']?.toString();
              if (targetUserId == null || targetUserId.isEmpty || targetUserId == userId) {
                final title = fixNotificationEncoding(newRecord['title'] ?? 'ZankoAI 🔔');
                final body = fixNotificationEncoding(newRecord['body'] ?? '');
                debugPrint('[NotificationService] Incoming realtime push received: "$title" - "$body"');
                showInstantNotification(
                  id: newRecord['id'].hashCode,
                  title: title,
                  body: body,
                );
                _notificationsUpdatedController.add(null);
              }
            },
          );

      _notificationChannel?.subscribe((status, [error]) {
        debugPrint('[NotificationService] Realtime channel status: $status');
        if (error != null) {
          debugPrint('[NotificationService] Realtime channel error: $error');
        }
      });

      // 2. Poll Firestore admin panel notifications
      _firestorePollTimer?.cancel();
      unawaited(checkFirestoreNotifications(userId, isVip));
      _firestorePollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
        checkFirestoreNotifications(userId, isVip);
      });
    } catch (e) {
      debugPrint('Notice on notifications listener: $e');
    }
  }

  /// Fetch Firestore notifications via REST for direct admin web panel sync
  Future<List<Map<String, dynamic>>> fetchFirestoreNotifications({
    required String userId,
    bool isVip = false,
  }) async {
    final List<Map<String, dynamic>> items = [];

    // A. Broadcast Notifications
    try {
      final res = await _dio.get(
        'https://firestore.googleapis.com/v1/projects/tomartv-67cda/databases/(default)/documents/notifications?pageSize=30',
      );
      final docs = (res.data['documents'] as List?) ?? [];
      for (final doc in docs) {
        final fields = doc['fields'] as Map<String, dynamic>? ?? {};
        final name = (doc['name'] ?? '').toString();
        final id = name.split('/').last;
        final target = fields['target']?['stringValue'] ?? 'all';
        final docUserId = fields['userId']?['stringValue'];

        final isMatch = (target == 'all' || target == 'all_students' || target == 'students') ||
            (target == 'vip' && isVip) ||
            (userId.isNotEmpty && (docUserId == userId || target == userId));

        if (!isMatch) continue;

        final title = fixNotificationEncoding(fields['title']?['stringValue'] ?? fields['header']?['stringValue'] ?? '🔔 ئاگاداری فەرمی');
        final body = fixNotificationEncoding(fields['body']?['stringValue'] ?? fields['message']?['stringValue'] ?? '');
        final timeStr = fields['createdAt']?['timestampValue'] ?? doc['createTime'] ?? DateTime.now().toIso8601String();
        final rawCat = (fields['category']?['stringValue'] ?? fields['type']?['stringValue'] ?? 'Announcement').toString();

        items.add({
          'id': id,
          'title': title,
          'body': body,
          'type': rawCat,
          'created_at': timeStr,
          'source': 'firestore_broadcast',
        });
      }
    } catch (e) {
      debugPrint('[NotificationService] Notice fetching Firestore notifications: $e');
    }

    // B. Direct Messages (if userId provided)
    if (userId.isNotEmpty) {
      try {
        final res = await _dio.get(
          'https://firestore.googleapis.com/v1/projects/tomartv-67cda/databases/(default)/documents/direct_messages?pageSize=30',
        );
        final docs = (res.data['documents'] as List?) ?? [];
        for (final doc in docs) {
          final fields = doc['fields'] as Map<String, dynamic>? ?? {};
          final name = (doc['name'] ?? '').toString();
          final id = name.split('/').last;
          final docUserId = fields['userId']?['stringValue'] ?? '';

          if (docUserId != userId) continue;

          final title = fixNotificationEncoding(fields['title']?['stringValue'] ?? '✉️ پەیامی تایبەت لە ئەدمینەوە');
          final body = fixNotificationEncoding(fields['message']?['stringValue'] ?? fields['body']?['stringValue'] ?? '');
          final timeStr = fields['createdAt']?['timestampValue'] ?? doc['createTime'] ?? DateTime.now().toIso8601String();

          items.add({
            'id': id,
            'title': title,
            'body': body,
            'type': 'Admin Direct',
            'created_at': timeStr,
            'source': 'firestore_dm',
          });
        }
      } catch (e) {
        debugPrint('[NotificationService] Notice fetching Firestore direct messages: $e');
      }
    }

    return items;
  }

  /// Periodic checker for new notifications sent from admin web panel
  Future<void> checkFirestoreNotifications(String userId, bool isVip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shownIds = (prefs.getStringList(_prefShownNotifIdsKey) ?? []).toSet();
      final readIds = (prefs.getStringList(_prefReadNotificationsKey) ?? []).toSet();
      final deletedIds = (prefs.getStringList(_prefDeletedNotificationsKey) ?? []).toSet();

      final items = await fetchFirestoreNotifications(userId: userId, isVip: isVip);
      if (items.isEmpty) return;

      int unreadCount = 0;
      bool hasNewIncoming = false;
      final now = DateTime.now();

      for (final item in items) {
        final id = item['id'].toString();
        if (deletedIds.contains(id)) continue;

        if (!readIds.contains(id)) {
          unreadCount++;
        }

        if (!shownIds.contains(id)) {
          shownIds.add(id);
          hasNewIncoming = true;

          DateTime itemTime = now;
          try {
            itemTime = DateTime.parse(item['created_at'].toString());
          } catch (_) {}

          // If the notification was sent in the last 4 hours or is fresh, trigger instant notification
          if (now.difference(itemTime).inHours <= 4) {
            debugPrint('[NotificationService] Popping up instant admin alert: "${item['title']}"');
            showInstantNotification(
              id: id.hashCode,
              title: item['title'] ?? 'ZankoAI 🔔',
              body: item['body'] ?? '',
            );
          }
        }
      }

      await prefs.setStringList(_prefShownNotifIdsKey, shownIds.toList());
      unreadCountNotifier.value = unreadCount;

      if (hasNewIncoming) {
        _notificationsUpdatedController.add(null);
      }
    } catch (e) {
      debugPrint('[NotificationService] Notice checking Firestore notifications: $e');
    }
  }

  String? _lastShownTitle;
  String? _lastShownBody;
  DateTime? _lastShownTime;

  /// Show an instant notification immediately on device screen
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final cleanTitle = fixNotificationEncoding(title);
    final cleanBody = fixNotificationEncoding(body);

    final now = DateTime.now();
    if (_lastShownTitle == cleanTitle &&
        _lastShownBody == cleanBody &&
        _lastShownTime != null &&
        now.difference(_lastShownTime!).inSeconds < 4) {
      return;
    }
    _lastShownTitle = cleanTitle;
    _lastShownBody = cleanBody;
    _lastShownTime = now;

    await init();

    const androidDetails = AndroidNotificationDetails(
      'zanko_admin_channel',
      'Admin Notifications',
      channelDescription: 'ZankoAI Admin Announcements & Messages',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      tag: 'zanko_admin_broadcast',
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF10B981),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id,
      cleanTitle,
      cleanBody,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Schedule a notification at [scheduledTime] with given [title] and [body].
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await init();

    final notifyAt = scheduledTime.subtract(const Duration(minutes: 10));
    if (notifyAt.isBefore(DateTime.now())) return;

    final tzTime = tz.TZDateTime.from(notifyAt, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'zanko_reminders',
      'Reminders',
      channelDescription: 'ZankoAI deadline reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF007AFF),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
