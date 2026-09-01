import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/language_provider.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final String category; // Admin Direct, Announcement, AI Tutor, Course, Quiz, Reminder
  final IconData icon;
  final Color color;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.category,
    required this.icon,
    required this.color,
    this.isRead = false,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedCategory = 'all';
  final List<NotificationItem> _notifications = [];
  StreamSubscription? _directMsgSub;
  StreamSubscription? _broadcastMsgSub;
  final List<NotificationItem> _directItems = [];
  final List<NotificationItem> _broadcastItems = [];
  final Set<String> _readDocIds = {};
  final Set<String> _deletedDocIds = {};

  static const String _prefReadNotificationsKey = 'zanko_read_notifications_v1';
  static const String _prefDeletedNotificationsKey = 'zanko_deleted_notifications_v1';

  static const _filterKeys = ['all', 'unread', 'Admin Direct', 'Announcement', 'AI Tutor', 'Course', 'Quiz', 'Reminder'];
  static const _filterLabels = ['هەموو', 'نەخوێنراو', '✉️ پەیامی ئەدمین', '🔔 ئاگاداری گشتی', '🤖 مامۆستا AI', '📚 وانە', '✏️ کویز', '⏰ بیرخستنەوە'];

  @override
  void initState() {
    super.initState();
    _loadLocalPrefs().then((_) {
      _listenToNotifications();
    });
  }

  Future<void> _loadLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _readDocIds.addAll(prefs.getStringList(_prefReadNotificationsKey) ?? []);
      _deletedDocIds.addAll(prefs.getStringList(_prefDeletedNotificationsKey) ?? []);
    } catch (_) {}
  }

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

  void _listenToNotifications() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null || user.isGuest) return;

    final userEmail = user.email.trim().toLowerCase();

    // 1. Direct Messages
    _directMsgSub?.cancel();
    _directMsgSub = FirebaseFirestore.instance
        .collection('direct_messages')
        .snapshots()
        .listen((snap) {
      _directItems.clear();
      for (var doc in snap.docs) {
        if (_deletedDocIds.contains(doc.id)) continue;
        final data = doc.data();
        final docUserId = (data['userId'] ?? data['user_id'] ?? data['recipientId'] ?? data['studentId'] ?? '').toString().trim();
        final docEmail = (data['email'] ?? data['userEmail'] ?? data['recipientEmail'] ?? '').toString().trim().toLowerCase();

        final isMatch = (docUserId.isNotEmpty && docUserId == user.id) ||
            (userEmail.isNotEmpty && docEmail == userEmail);

        if (!isMatch) continue;

        final title = data['title'] ?? data['header'] ?? data['subject'] ?? '✉️ پەیام لە ئەدمینەوە';
        final body = data['message'] ?? data['body'] ?? data['content'] ?? data['text'] ?? '';
        final time = _parseTimestamp(data['createdAt'] ?? data['timestamp'] ?? data['date']);
        final isRead = data['isRead'] == true || _readDocIds.contains(doc.id);

        _directItems.add(NotificationItem(
          id: doc.id,
          title: title.toString(),
          body: body.toString(),
          time: time,
          category: 'Admin Direct',
          icon: CupertinoIcons.mail_solid,
          color: ZankoColors.primary,
          isRead: isRead,
        ));
      }
      _combineAndSetNotifications();
    });

    // 2. Broadcast / Announcements
    _broadcastMsgSub?.cancel();
    _broadcastMsgSub = FirebaseFirestore.instance
        .collection('notifications')
        .snapshots()
        .listen((snap) {
      _broadcastItems.clear();
      for (var doc in snap.docs) {
        if (_deletedDocIds.contains(doc.id)) continue;
        final data = doc.data();
        final target = (data['target'] ?? data['to'] ?? data['audience'] ?? '').toString().trim().toLowerCase();
        final docUserId = (data['userId'] ?? data['user_id'] ?? data['recipientId'] ?? '').toString().trim();
        final docEmail = (data['email'] ?? data['userEmail'] ?? '').toString().trim().toLowerCase();

        // If addressed to a specific user, ONLY deliver to that user
        bool isMatch = false;
        if (docUserId.isNotEmpty) {
          isMatch = (docUserId == user.id);
        } else if (docEmail.isNotEmpty) {
          isMatch = (userEmail.isNotEmpty && docEmail == userEmail);
        } else if (target == 'user' || target == 'direct' || target == 'single' || target == 'personal') {
          isMatch = false; // missing recipient id/email, do not broadcast to all
        } else if (target == 'vip') {
          isMatch = user.isVip;
        } else if (target == '' || target == 'all' || target == 'all_students' || target == 'students' || target == 'everyone') {
          isMatch = true;
        }

        if (!isMatch) continue;

        final title = data['title'] ?? data['header'] ?? data['subject'] ?? '🔔 ئاگادارکردنەوە';
        final body = data['body'] ?? data['message'] ?? data['content'] ?? data['text'] ?? '';
        final time = _parseTimestamp(data['createdAt'] ?? data['timestamp'] ?? data['date']);
        final rawCat = (data['category'] ?? data['type'] ?? 'Announcement').toString().toLowerCase();

        String category = 'Announcement';
        IconData icon = CupertinoIcons.bell_fill;
        Color color = const Color(0xFFFF9F0A);

        if (rawCat.contains('tutor') || rawCat.contains('ai')) {
          category = 'AI Tutor';
          icon = CupertinoIcons.sparkles;
          color = ZankoColors.accent;
        } else if (rawCat.contains('course') || rawCat.contains('lesson')) {
          category = 'Course';
          icon = CupertinoIcons.book_fill;
          color = const Color(0xFF10B981);
        } else if (rawCat.contains('quiz') || rawCat.contains('exam')) {
          category = 'Quiz';
          icon = CupertinoIcons.pencil_ellipsis_rectangle;
          color = const Color(0xFF6366F1);
        } else if (rawCat.contains('remind') || rawCat.contains('schedule')) {
          category = 'Reminder';
          icon = CupertinoIcons.alarm_fill;
          color = const Color(0xFFEC4899);
        }

        final isRead = data['isRead'] == true || _readDocIds.contains(doc.id);

        _broadcastItems.add(NotificationItem(
          id: doc.id,
          title: title.toString(),
          body: body.toString(),
          time: time,
          category: category,
          icon: icon,
          color: color,
          isRead: isRead,
        ));
      }
      _combineAndSetNotifications();
    });
  }

  void _combineAndSetNotifications() {
    if (!mounted) return;
    setState(() {
      _notifications.clear();
      _notifications.addAll([..._directItems, ..._broadcastItems]);
      _notifications.sort((a, b) => b.time.compareTo(a.time));
    });
  }

  @override
  void dispose() {
    _directMsgSub?.cancel();
    _broadcastMsgSub?.cancel();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    for (var item in _notifications) {
      item.isRead = true;
      _readDocIds.add(item.id);
      FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(item.id)
          .update({'isRead': true})
          .catchError((_) {});
    }
    setState(() {});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefReadNotificationsKey, _readDocIds.toList());
    } catch (_) {}
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'ئێستا';
    if (diff.inMinutes < 60) return '${diff.inMinutes} خولەک پێشتر';
    if (diff.inHours < 24) return '${diff.inHours} کاتژمێر پێشتر';
    return '${diff.inDays} ڕۆژ پێشتر';
  }

  String _formatDetailDate(DateTime time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')} • $hour:$minute $period';
  }

  Future<void> _deleteNotification(NotificationItem item) async {
    setState(() {
      _notifications.removeWhere((n) => n.id == item.id);
      _directItems.removeWhere((n) => n.id == item.id);
      _broadcastItems.removeWhere((n) => n.id == item.id);
    });
    _deletedDocIds.add(item.id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefDeletedNotificationsKey, _deletedDocIds.toList());
    } catch (_) {}

    FirebaseFirestore.instance
        .collection('direct_messages')
        .doc(item.id)
        .delete()
        .catchError((_) {});
  }

  Future<void> _showNotificationDetail(NotificationItem item) async {
    if (!item.isRead) {
      setState(() {
        item.isRead = true;
      });
      _readDocIds.add(item.id);
      FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(item.id)
          .update({'isRead': true})
          .catchError((_) {});
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_prefReadNotificationsKey, _readDocIds.toList());
      } catch (_) {}
    }

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1F26) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pull Handle
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header with Category Badge and Close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: item.color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(item.icon, size: 16, color: item.color),
                            const SizedBox(width: 6),
                            Text(
                              item.category == 'Admin Direct' ? 'پەیامی فەرمی ئەدمین' : item.category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: item.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Formatted Time & Date
                      Text(
                        _formatDetailDate(item.time),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, thickness: 0.8),

                // Scrollable Notification Content
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        SelectableText(
                          item.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.4,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Body Message
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14171D) : const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: SelectableText(
                            item.body.isNotEmpty ? item.body : 'هیچ دەقێکی زیادە نییە.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.grey[200] : const Color(0xFF222831),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1, thickness: 0.8),

                // Action Toolbar (Copy, Delete)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      // 1. Copy
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: "${item.title}\n\n${item.body}"));
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('دەقی ئاگادارییەکە کۆپی کرا! 📋'),
                                backgroundColor: Colors.blueGrey,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(CupertinoIcons.doc_on_doc, size: 17),
                          label: const Text(
                            'کۆپیکردنی دەق',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ZankoColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 2. Delete
                      IconButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _deleteNotification(item);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ئاگادارییەکە سڕایەوە 🗑️'),
                                backgroundColor: Colors.redAccent,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 20),
                        tooltip: 'سڕینەوە',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _notifications.where((item) {
      if (_selectedCategory == 'unread') return !item.isRead;
      if (_selectedCategory == 'all') return true;
      return item.category == _selectedCategory;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GlassButton(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      CupertinoIcons.back,
                      size: 20,
                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    t('notifications'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_notifications.isNotEmpty) ...[
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _markAllAsRead,
                      child: Text(
                        'خوێنراوەکان',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ZankoColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: List.generate(_filterKeys.length, (index) {
                  final key = _filterKeys[index];
                  final label = _filterLabels[index];
                  final isSelected = _selectedCategory == key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ZankoColors.primary
                              : (isDark ? ZankoColors.darkCard : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isSelected ? ZankoShadows.card : null,
                          border: Border.all(
                            color: isSelected
                                ? ZankoColors.primary
                                : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEFEFF5)),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.grey[300] : ZankoColors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 12),

            // Notification List
            Expanded(
              child: RefreshIndicator(
                color: ZankoColors.primary,
                onRefresh: () async {
                  _listenToNotifications();
                  await Future.delayed(const Duration(milliseconds: 600));
                },
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.bell_slash,
                                  size: 54,
                                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'هیچ ئاگادارییەکی تازە نییە',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.grey[400] : ZankoColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'پەیامە فەرمییەکان و ئاگادارییەکان لێرەدا ڕاستەوخۆ دەردەکەون',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[600] : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Dismissible(
                            key: Key(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: ZankoColors.error.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(CupertinoIcons.delete, color: Colors.white, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'سڕینەوە',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            onDismissed: (_) {
                              _deleteNotification(item);
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                padding: const EdgeInsets.all(16),
                                onTap: () => _showNotificationDetail(item),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Category Icon Avatar
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: item.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      color: item.color,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: item.isRead
                                                      ? FontWeight.w600
                                                      : FontWeight.w800,
                                                  color: isDark
                                                      ? Colors.white
                                                      : ZankoColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _formatTime(item.time),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: ZankoColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.body,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            height: 1.38,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : ZankoColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              'بۆ خوێندنەوەی تەواو لێبدە',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: ZankoColors.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              CupertinoIcons.chevron_left,
                                              size: 11,
                                              color: ZankoColors.primary,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Unread Dot Indicator
                                  if (!item.isRead) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(top: 4),
                                      decoration: BoxDecoration(
                                        color: ZankoColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
