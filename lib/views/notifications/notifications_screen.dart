import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/language_provider.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final String category; // AI Tutor, Course, Quiz, Reminder, Admin Direct
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

  static const _filterKeys = ['all', 'unread', 'Admin Direct', 'AI Tutor', 'Course', 'Quiz', 'Reminder'];
  static const _filterLabels = ['هەموو', 'نەخوێنراو', '✉️ پەیامی ئەدمین', '🤖 مامۆستا AI', '📚 وانە', '✏️ کویز', '⏰ بیرخستنەوە'];

  @override
  void initState() {
    super.initState();
    _listenToDirectMessages();
  }

  void _listenToDirectMessages() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null || user.isGuest) return;

    _directMsgSub = FirebaseFirestore.instance
        .collection('direct_messages')
        .where('userId', isEqualTo: user.id)
        .snapshots()
        .listen((snap) {
      final items = snap.docs.map((doc) {
        final data = doc.data();
        final ts = data['createdAt'] as Timestamp?;
        return NotificationItem(
          id: doc.id,
          title: data['title'] ?? 'پەیام لە ئەدمینەوە',
          body: data['message'] ?? '',
          time: ts?.toDate() ?? DateTime.now(),
          category: 'Admin Direct',
          icon: CupertinoIcons.mail_solid,
          color: const Color(0xFF7C3AED),
          isRead: data['isRead'] == true,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _notifications.clear();
          _notifications.addAll(items);
        });
      }
    });
  }

  @override
  void dispose() {
    _directMsgSub?.cancel();
    super.dispose();
  }

  void _markAllAsRead() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null || user.isGuest) return;

    for (var item in _notifications) {
      if (!item.isRead) {
        FirebaseFirestore.instance.collection('direct_messages').doc(item.id).update({'isRead': true});
      }
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'ئێستا';
    if (diff.inMinutes < 60) return '${diff.inMinutes} خولەک پێشتر';
    if (diff.inHours < 24) return '${diff.inHours} کاتژمێر پێشتر';
    return '${diff.inDays} ڕۆژ پێشتر';
  }

  @override
  Widget build(BuildContext context) {
    final __lang = Provider.of<LanguageProvider>(context);
    String t(String key) => __lang.translate(key);
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
                      child: const Text(
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
                                : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFEFEFF5)),
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
              child: filtered.isEmpty
                  ? Center(
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
                              color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'پەیامەکانی ئەدمین لێرەدا ڕاستەوخۆ دەردەکەون',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[600] : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            padding: const EdgeInsets.all(16),
                            onTap: () {
                              if (!item.isRead) {
                                FirebaseFirestore.instance
                                    .collection('direct_messages')
                                    .doc(item.id)
                                    .update({'isRead': true});
                              }
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category Icon Avatar
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: item.color.withOpacity(0.12),
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
                                                fontSize: 14,
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
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.35,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : ZankoColors.textSecondary,
                                        ),
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
                                    decoration: const BoxDecoration(
                                      color: ZankoColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
