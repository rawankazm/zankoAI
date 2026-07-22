import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String time;
  final String category; // AI Tutor, Course, Quiz, Reminder
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
  // Use stable internal keys for filter selection
  String _selectedCategory = 'all';

  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      title: 'notif_ai_summary',
      body: 'ZankoAI generated a 3-page summary for Calculus Chapter 4: Derivatives.',
      time: '10m ago',
      category: 'AI Tutor',
      icon: CupertinoIcons.sparkles,
      color: const Color(0xFF6C5CE7),
      isRead: false,
    ),
    NotificationItem(
      id: '2',
      title: 'notif_quiz_high',
      body: 'You scored 95% in Operating Systems Quiz 3. Keep up the high streak!',
      time: '1h ago',
      category: 'Quiz',
      icon: CupertinoIcons.checkmark_seal_fill,
      color: const Color(0xFF34C759),
      isRead: false,
    ),
    NotificationItem(
      id: '3',
      title: 'notif_assignment',
      body: 'Database Systems Homework 2 is due tomorrow at 11:59 PM.',
      time: '3h ago',
      category: 'Reminder',
      icon: CupertinoIcons.clock_fill,
      color: const Color(0xFFFF9F0A),
      isRead: false,
    ),
    NotificationItem(
      id: '4',
      title: 'notif_new_material',
      body: 'Prof. Sarah uploaded Lecture 5 slides in Machine Learning Fundamentals.',
      time: 'yesterday',
      category: 'Course',
      icon: CupertinoIcons.book_fill,
      color: const Color(0xFF007AFF),
      isRead: true,
    ),
    NotificationItem(
      id: '5',
      title: 'notif_gpa_update',
      body: 'Your estimated Semester GPA updated to 3.65 / 4.00 (Excellent).',
      time: '2d ago',
      category: 'AI Tutor',
      icon: CupertinoIcons.graph_square_fill,
      color: const Color(0xFFAF52DE),
      isRead: true,
    ),
  ];

  // Internal stable keys for filter categories
  static const _filterKeys = ['all', 'unread', 'AI Tutor', 'Course', 'Quiz', 'Reminder'];
  static const _filterTranslationKeys = ['filter_all', 'filter_unread', 'filter_ai_tutor', 'filter_course', 'filter_quiz', 'filter_reminder'];

    void _markAllAsRead() {
    setState(() {
      for (var item in _notifications) {
        item.isRead = true;
      }
    });
  }

  void _clearAll() {
    setState(() {
      _notifications.clear();
    });
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
                      child: Text(
                        t('mark_read'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ZankoColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _clearAll,
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ZankoColors.error,
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
                  final label = t(_filterTranslationKeys[index]);
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
                            t('no_notifications'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t('all_caught_up'),
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
                              setState(() {
                                item.isRead = true;
                              });
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
                                              Provider.of<LanguageProvider>(context).translate(item.title),
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
                                            t(item.time),
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
