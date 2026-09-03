import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cleanly repairs UTF-8 mojibake (e.g. "ðŸŽ‰ Ù¾ÛŒØ±Û†Ø²Û•!" -> "🎉 پیرۆزە!")
String fixNotificationEncoding(dynamic raw) {
  if (raw == null) return '';
  final input = raw.toString();
  if (input.isEmpty) return input;

  // Check if string contains typical UTF-8 bytes misread as Latin-1 / Windows-1252
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

/// Top-level background handler for FCM messages when app is killed or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background FCM message: ${message.messageId}');
  // If the message already contains a notification payload, Android system FCM handles displaying it automatically.
  // Only display manually if it was a data-only payload.
  if (message.notification == null) {
    final title = fixNotificationEncoding(message.data['title'] ?? 'ZankoAI');
    final body = fixNotificationEncoding(message.data['body'] ?? message.data['message'] ?? '');

    if (title.isNotEmpty || body.isNotEmpty) {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'zanko_admin_channel',
        'Admin Notifications',
        channelDescription: 'ZankoAI Admin Announcements & Messages',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF10B981),
      );
      const notificationDetails = NotificationDetails(android: androidDetails);
      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        title,
        body,
        notificationDetails,
      );
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  StreamSubscription? _adminDirectSub;
  StreamSubscription? _adminBroadcastSub;

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

    // Request Android 13+ & Exact Alarm permissions & create channel
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

    // ─── Setup Google Firebase Cloud Messaging (FCM) ────────────────────────
    try {
      // 1. Request notification permissions (iOS & Android 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('FCM Authorization Status: ${settings.authorizationStatus}');

      // 2. Set Foreground presentation options for iOS
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Get Device FCM Token
      _fcmToken = await _fcm.getToken();
      debugPrint('Device FCM Token: $_fcmToken');

      // 4. (Token refresh handled by listener below — see step 9)

      // 5. Subscribe to default broadcast topics
      await _fcm.subscribeToTopic('all_students');
      await _fcm.subscribeToTopic('announcements');

      // 6. Handle Foreground FCM Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground FCM message: ${message.notification?.title}');
        final notification = message.notification;
        if (notification != null) {
          showInstantNotification(
            id: message.hashCode,
            title: fixNotificationEncoding(notification.title ?? 'ZankoAI'),
            body: fixNotificationEncoding(notification.body ?? ''),
          );
        }
      });

      // 7. Handle Background Notification Tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from background FCM message: ${message.data}');
      });

      // 8. Check if App was opened from a terminated state notification
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from terminated state FCM message: ${initialMessage.data}');
      }

      // 9. Handle Token Refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        if (_lastSyncedUserId != null && _lastSyncedUserId!.isNotEmpty) {
          FirebaseFirestore.instance.collection('users').doc(_lastSyncedUserId!).set({
            'fcmToken': newToken,
            'fcmTokens': FieldValue.arrayUnion([newToken]),
          }, SetOptions(merge: true)).catchError((_) {});
        }
      });
    } catch (e) {
      debugPrint('FCM initialization notice: $e');
    }

    _initialized = true;
  }

  /// Sync device FCM token with user profile in Firestore
  String? _lastSyncedUserId;
  String? _lastSyncedToken;
  bool? _lastSyncedVip;

  /// Sync device FCM token with user profile in Firestore
  Future<void> syncUserToken(String userId, {bool isVip = false}) async {
    await init();
    if (_fcmToken == null) {
      try {
        _fcmToken = await _fcm.getToken();
      } catch (e) {
        debugPrint('Could not fetch FCM token: $e');
      }
    }

    if (_fcmToken != null && userId.isNotEmpty) {
      if (_lastSyncedUserId == userId && _lastSyncedToken == _fcmToken && _lastSyncedVip == isVip) {
        return; // already synced
      }
      _lastSyncedUserId = userId;
      _lastSyncedToken = _fcmToken;
      _lastSyncedVip = isVip;

      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': _fcmToken,
          'fcmTokens': FieldValue.arrayUnion([_fcmToken]),
          'devicePlatform': defaultTargetPlatform.name,
        }, SetOptions(merge: true));

        // Manage VIP Topic Subscription
        if (isVip) {
          await _fcm.subscribeToTopic('vip_students');
        } else {
          await _fcm.unsubscribeFromTopic('vip_students');
        }
      } catch (e) {
        debugPrint('Error syncing FCM token to Firestore: $e');
      }
    }
  }

  static const String _seenDocsKey = 'zanko_seen_notified_docs_v2';
  final Set<String> _seenDocIds = {};

  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return DateTime.now();
  }

  /// Start listening to admin notifications from Firestore (direct_messages, notifications & announcements)
  Future<void> listenToAdminNotifications(String userId, bool isVip, {String? email}) async {
    if (userId.isEmpty) return;

    _adminDirectSub?.cancel();
    _adminBroadcastSub?.cancel();

    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList(_seenDocsKey) ?? [];
    _seenDocIds.addAll(savedList);

    final normalizedEmail = email?.trim().toLowerCase();

    // 1. Direct Messages Listener (Messages sent specifically to this user)
    _adminDirectSub = FirebaseFirestore.instance
        .collection('direct_messages')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snap) async {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final data = doc.data();
          if (data == null) continue;
          final docId = doc.id;
          final docUserId = (data['userId'] ?? data['user_id'] ?? data['recipientId'] ?? data['studentId'] ?? '').toString().trim();
          final docEmail = (data['email'] ?? data['userEmail'] ?? data['recipientEmail'] ?? '').toString().trim().toLowerCase();

          final isMatch = (docUserId.isNotEmpty && docUserId == userId) ||
              (normalizedEmail != null && normalizedEmail.isNotEmpty && docEmail == normalizedEmail);

          if (!isMatch) continue;

          final isRead = data['isRead'] == true;
          final time = _parseTimestamp(data['createdAt'] ?? data['timestamp'] ?? data['date']);
          final isRecent = DateTime.now().difference(time).inMinutes < 60;

          if (!isRead && !_seenDocIds.contains(docId)) {
            final title = fixNotificationEncoding(data['title'] ?? data['header'] ?? data['subject'] ?? '✉️ پەیام لە ئەدمینەوە');
            final body = fixNotificationEncoding(data['message'] ?? data['body'] ?? data['content'] ?? data['text'] ?? '');

            if (isRecent && (body.trim().isNotEmpty || title.trim().isNotEmpty)) {
              await showInstantNotification(
                id: docId.hashCode,
                title: title,
                body: body,
              );
            }
            _seenDocIds.add(docId);
            await prefs.setStringList(_seenDocsKey, _seenDocIds.toList());
          }
        }
      }
    });

    // 2. Broadcast & Announcements Notifications Listener (Limited to 10 most recent to prevent N+1 read costs)
    _adminBroadcastSub = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen((snap) async {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final data = doc.data();
          if (data == null) continue;
          final docId = doc.id;
          final target = (data['target'] ?? data['to'] ?? data['audience'] ?? '').toString().trim().toLowerCase();
          final docUserId = (data['userId'] ?? data['user_id'] ?? data['recipientId'] ?? '').toString().trim();
          final docEmail = (data['email'] ?? data['userEmail'] ?? '').toString().trim().toLowerCase();

          // If addressed to a specific user, ONLY deliver to that user
          bool isTargetUser = false;
          if (docUserId.isNotEmpty) {
            isTargetUser = (docUserId == userId);
          } else if (docEmail.isNotEmpty) {
            isTargetUser = (normalizedEmail != null && normalizedEmail.isNotEmpty && docEmail == normalizedEmail);
          } else if (target == 'user' || target == 'direct' || target == 'single' || target == 'personal') {
            isTargetUser = false; // missing recipient id/email, do not broadcast
          } else if (target == 'vip') {
            isTargetUser = isVip;
          } else if (target == '' || target == 'all' || target == 'all_students' || target == 'students' || target == 'everyone') {
            isTargetUser = true;
          }

          if (!isTargetUser) continue;

          final time = _parseTimestamp(data['createdAt'] ?? data['timestamp'] ?? data['date']);
          final isRecent = DateTime.now().difference(time).inMinutes < 60;

          if (!_seenDocIds.contains(docId)) {
            final title = fixNotificationEncoding(data['title'] ?? data['header'] ?? data['subject'] ?? '🔔 ئاگاداری لە ZankoAI');
            final body = fixNotificationEncoding(data['body'] ?? data['message'] ?? data['content'] ?? data['text'] ?? '');

            if (isRecent && (body.trim().isNotEmpty || title.trim().isNotEmpty)) {
              await showInstantNotification(
                id: docId.hashCode,
                title: title,
                body: body,
              );
            }
            _seenDocIds.add(docId);
            await prefs.setStringList(_seenDocsKey, _seenDocIds.toList());
          }
        }
      }
    });
  }

  String? _lastShownTitle;
  String? _lastShownBody;
  DateTime? _lastShownTime;

  /// Show an instant notification immediately on device screen (with duplicate debounce).
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
      debugPrint('Debounced duplicate notification: $cleanTitle');
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
  /// [id] should be unique per reminder.
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await init();

    // Notify 10 minutes before deadline
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

  /// Cancel a specific notification by [id].
  Future<void> cancelReminder(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
