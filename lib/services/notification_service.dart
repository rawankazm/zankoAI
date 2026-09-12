import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  // If the message has no notification payload (data-only push), trigger local notification
  final title = fixNotificationEncoding(
    message.notification?.title ?? message.data['title'] ?? 'ZankoAI 🔔',
  );
  final body = fixNotificationEncoding(
    message.notification?.body ?? message.data['body'] ?? '',
  );

  if (body.isNotEmpty && message.notification == null) {
    await NotificationService().showInstantNotification(
      id: message.messageId.hashCode,
      title: title,
      body: body,
    );
  }
}

/// Cleanly repairs UTF-8 mojibake (e.g. "ðŸŽ‰ Ù¾ÛŒØ±Û†Ø²Û•!" -> "🎉 پیرۆزە!")
String fixNotificationEncoding(dynamic raw) {
  if (raw == null) return '';
  final input = raw.toString();
  if (input.isEmpty) return input;

  if (input.contains('Ù') ||
      input.contains('Ø') ||
      input.contains('Û') ||
      input.contains('ð') ||
      input.contains('Ã')) {
    const cp1252Map = <int, int>{
      0x20AC: 0x80,
      0x201A: 0x82,
      0x0192: 0x83,
      0x201E: 0x84,
      0x2026: 0x85,
      0x2020: 0x86,
      0x2021: 0x87,
      0x02C6: 0x88,
      0x2030: 0x89,
      0x0160: 0x8A,
      0x2039: 0x8B,
      0x0152: 0x8C,
      0x017D: 0x8E,
      0x2018: 0x91,
      0x2019: 0x92,
      0x201C: 0x93,
      0x201D: 0x94,
      0x2022: 0x95,
      0x2013: 0x96,
      0x2014: 0x97,
      0x02DC: 0x98,
      0x2122: 0x99,
      0x0161: 0x9A,
      0x203A: 0x9B,
      0x0153: 0x9C,
      0x017E: 0x9E,
      0x0178: 0x9F,
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

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  RealtimeChannel? _notificationChannel;

  static const String _prefReadNotificationsKey = 'zanko_read_notifications_v1';
  static const String _prefDeletedNotificationsKey =
      'zanko_deleted_notifications_v1';

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  final StreamController<void> _notificationsUpdatedController =
      StreamController<void>.broadcast();
  Stream<void> get onNotificationsUpdated =>
      _notificationsUpdatedController.stream;

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

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
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

    if (!kIsWeb) {
      try {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        await messaging.subscribeToTopic('all_students');
        await messaging.subscribeToTopic('broadcast_all');

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final title = fixNotificationEncoding(
            message.notification?.title ?? message.data['title'] ?? 'ZankoAI 🔔',
          );
          final body = fixNotificationEncoding(
            message.notification?.body ?? message.data['body'] ?? '',
          );
          if (body.isNotEmpty) {
            showInstantNotification(
              id: message.messageId.hashCode,
              title: title,
              body: body,
            );
            _notificationsUpdatedController.add(null);
          }
        });
      } catch (e) {
        debugPrint('FirebaseMessaging setup notice: $e');
      }
    }

    _initialized = true;
  }

  Future<void> syncUserToken(
    String userId, {
    bool isVip = false,
    String? email,
  }) async {
    await init();

    if (!kIsWeb && userId.isNotEmpty) {
      try {
        final messaging = FirebaseMessaging.instance;
        await messaging.subscribeToTopic('user_$userId');

        if (isVip) {
          await messaging.subscribeToTopic('vip_students');
        } else {
          await messaging.unsubscribeFromTopic('vip_students');
        }

        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          try {
            await Supabase.instance.client
                .from('profiles')
                .update({'push_token': token})
                .eq('id', userId);
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('syncUserToken FCM notice: $e');
      }
    }
  }

  /// Start listening to notifications from Supabase Realtime
  Future<void> listenToAdminNotifications(
    String userId,
    bool isVip, {
    String? email,
  }) async {
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

              // Strictly ignore internal user feedback and security appeals!
              // They are administrative submissions from user to admin, NEVER notifications to the user!
              final recordData = newRecord['data'];
              if (recordData is Map) {
                if (recordData['is_feedback'] == true ||
                    recordData['action'] == 'USER_FEEDBACK') {
                  return;
                }
                if (recordData['is_appeal'] == true ||
                    recordData['action'] == 'IP_LIMIT_APPEAL') {
                  return;
                }
                if (recordData['is_ad'] == true) return;
              }
              final rawTitle = (newRecord['title'] ?? '').toString();
              if (rawTitle.contains('ڕا و پێشنیار') ||
                  rawTitle.contains('داواکاری نوێکردنەوەی IP')) {
                return;
              }

              final targetUserId = newRecord['user_id']?.toString();
              if (targetUserId == null ||
                  targetUserId.isEmpty ||
                  targetUserId == userId) {
                final title = fixNotificationEncoding(
                  newRecord['title'] ?? 'ZankoAI 🔔',
                );
                final body = fixNotificationEncoding(newRecord['body'] ?? '');
                // Display instant local notification for student immediately
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

      // 2. Silently sync unread count once on connect
      unawaited(checkNotifications(userId, isVip));
    } catch (e) {
      debugPrint('Notice on notifications listener: $e');
    }
  }

  /// All notifications stream directly via Supabase PostgreSQL
  Future<List<Map<String, dynamic>>> fetchFirestoreNotifications({
    required String userId,
    bool isVip = false,
  }) async {
    return const <Map<String, dynamic>>[];
  }

  /// Deprecated alias for checkNotifications
  @Deprecated('Use checkNotifications instead')
  Future<void> checkFirestoreNotifications(String userId, bool isVip) =>
      checkNotifications(userId, isVip);

  /// Sync unread notifications count directly from modern Supabase PostgreSQL table
  Future<void> checkNotifications(String userId, bool isVip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = (prefs.getStringList(_prefReadNotificationsKey) ?? [])
          .toSet();
      final deletedIds =
          (prefs.getStringList(_prefDeletedNotificationsKey) ?? []).toSet();

      final res = await Supabase.instance.client
          .from('notifications')
          .select('id, user_id, is_read, data, title')
          .limit(50);

      int unread = 0;
      for (final row in res) {
        final id = (row['id'] ?? '').toString();
        if (id.isEmpty || deletedIds.contains(id)) continue;

        // Skip internal feedback, appeals, and ads
        final rowData = row['data'];
        if (rowData is Map) {
          if (rowData['is_feedback'] == true ||
              rowData['action'] == 'USER_FEEDBACK') {
            continue;
          }
          if (rowData['is_appeal'] == true ||
              rowData['action'] == 'IP_LIMIT_APPEAL') {
            continue;
          }
          if (rowData['is_ad'] == true) continue;
        }
        final rawTitle = (row['title'] ?? '').toString();
        if (rawTitle.contains('ڕا و پێشنیار') ||
            rawTitle.contains('داواکاری نوێکردنەوەی IP')) {
          continue;
        }

        final targetUserId = (row['user_id'] ?? '').toString();
        if (targetUserId.isNotEmpty && targetUserId != userId) continue;
        final isRead = row['is_read'] == true || readIds.contains(id);
        if (!isRead) unread++;
      }
      unreadCountNotifier.value = unread;
    } catch (e) {
      debugPrint('[NotificationService] Notice syncing unread count: $e');
    }
  }

  static final Map<String, DateTime> _recentlyShownMap = {};

  /// Show an instant notification immediately on device screen
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final cleanTitle = fixNotificationEncoding(title).trim();
    final cleanBody = fixNotificationEncoding(body).trim();

    // Strict validation: NEVER show empty or blank notifications!
    if (cleanTitle.isEmpty || cleanBody.isEmpty) {
      return;
    }
    if (cleanTitle == 'ZankoAI 🔔' && cleanBody.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final dedupeKey = '$cleanTitle|||$cleanBody';

    // Purge expired entries older than 60 seconds
    _recentlyShownMap.removeWhere(
      (_, time) => now.difference(time).inSeconds > 60,
    );

    if (_recentlyShownMap.containsKey(dedupeKey)) {
      final lastShown = _recentlyShownMap[dedupeKey]!;
      if (now.difference(lastShown).inSeconds < 25) {
        debugPrint(
          '[NotificationService] Blocked duplicate notification: $cleanTitle',
        );
        return;
      }
    }
    _recentlyShownMap[dedupeKey] = now;

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
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF10B981),
      autoCancel: true,
      ongoing: false,
      onlyAlertOnce: false,
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
